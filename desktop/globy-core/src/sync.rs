use chrono::{DateTime, Utc};
use std::collections::{BTreeMap, HashSet};
use std::sync::Mutex;
use tokio::sync::watch;

use crate::client::{ChronocolConfiguration, ChronocolReading, ClientError};
use crate::clock::Clock;
use crate::models::*;
use crate::policies::{NotificationPolicy, RetryPolicy};
use crate::store::{ContentStore, StoreSnapshot, StoreTransaction};

pub struct SyncCoordinator<C, S, K> {
    client: C,
    store: S,
    clock: K,
    configuration: ChronocolConfiguration,
    notification_policy: NotificationPolicy,
    retry_policy: RetryPolicy,
    /// Sincronizzazione in volo: chi arriva nel frattempo aspetta il suo esito.
    in_flight: Mutex<Option<watch::Receiver<Option<SyncReport>>>>,
}

impl<C: ChronocolReading, S: ContentStore, K: Clock> SyncCoordinator<C, S, K> {
    pub fn new(
        client: C,
        store: S,
        clock: K,
        configuration: ChronocolConfiguration,
        notification_policy: NotificationPolicy,
        retry_policy: RetryPolicy,
    ) -> Self {
        Self { client, store, clock, configuration, notification_policy, retry_policy, in_flight: Mutex::new(None) }
    }

    pub fn store(&self) -> &S {
        &self.store
    }

    pub fn client(&self) -> &C {
        &self.client
    }

    pub async fn synchronize(&self, cause: SyncCause, hint: SyncHint) -> SyncReport {
        let pending = {
            let mut slot = self.in_flight.lock().unwrap();
            match slot.as_ref() {
                Some(receiver) => Err(receiver.clone()),
                None => {
                    let (sender, receiver) = watch::channel(None);
                    *slot = Some(receiver);
                    Ok(sender)
                }
            }
        };
        match pending {
            Err(mut receiver) => {
                let report = receiver.wait_for(Option::is_some).await.map(|r| r.clone());
                match report {
                    Ok(Some(mut report)) => {
                        report.coalesced = true;
                        report
                    }
                    // Chi era in volo è stato annullato: si sincronizza da capo.
                    _ => Box::pin(self.synchronize(cause, hint)).await,
                }
            }
            Ok(sender) => {
                let guard = InFlightGuard(&self.in_flight);
                let report = self.perform(cause, &hint).await;
                drop(guard);
                let _ = sender.send(Some(report.clone()));
                report
            }
        }
    }

    pub async fn handle_hint(&self, event: &HintEvent) -> SyncReport {
        match event {
            HintEvent::VoxNew { document_id, .. } => {
                self.synchronize(SyncCause::Hint, SyncHint::VoxNew(document_id.clone())).await
            }
            HintEvent::VoxUpdated { document_id } => {
                self.synchronize(SyncCause::Hint, SyncHint::VoxUpdated(document_id.clone())).await
            }
            HintEvent::StreamUnavailable { .. } => {
                let mut report = self.synchronize(SyncCause::Polling, SyncHint::StreamUnavailable).await;
                report.stream_fallback = true;
                report
            }
            _ => SyncReport::new(SyncCause::Hint),
        }
    }

    async fn perform(&self, cause: SyncCause, hint: &SyncHint) -> SyncReport {
        let mut last_error = None;
        for attempt in 1..=self.retry_policy.max_attempts {
            let delay = self.retry_policy.delay_before_attempt(attempt);
            if delay > 0.0 {
                self.clock.sleep(delay).await;
            }
            match self.run_once(cause, hint).await {
                Ok(report) => return report,
                Err(error) => {
                    let failure = map_failure(&error);
                    let retry = is_retryable(&failure);
                    last_error = Some(failure);
                    if !retry {
                        break;
                    }
                }
            }
        }
        let snapshot = self.store.snapshot();
        SyncReport {
            completed_baseline: snapshot.has_completed_baseline,
            last_successful_sync_at: snapshot.last_successful_sync_at,
            failure: last_error,
            ..SyncReport::new(cause)
        }
    }

    async fn run_once(&self, cause: SyncCause, hint: &SyncHint) -> Result<SyncReport, ClientError> {
        let snapshot = self.store.snapshot();
        let is_baseline = !snapshot.has_completed_baseline;
        let effective_cause = if is_baseline { SyncCause::FirstLaunch } else { cause };
        let started_at = self.clock.now();
        let stream_fallback = *hint == SyncHint::StreamUnavailable;

        let rss = self.client.fetch_rss().await?;
        let mut used_json = false;
        let mut json_pages = 0;
        let mut remotes = if is_baseline {
            rss
        } else {
            let cursor = snapshot.last_successful_sync_at.unwrap_or(started_at);
            if rss_covers_hole(&rss, cursor, &snapshot) {
                rss
            } else {
                used_json = true;
                let (items, covered) = self.collect_json_hole(cursor, &mut json_pages).await?;
                if !covered {
                    return Ok(SyncReport {
                        used_rss: true,
                        used_json: true,
                        json_pages_fetched: json_pages,
                        failure: Some(SyncFailure {
                            kind: SyncFailureKind::IncompleteCatchUp,
                            message: "il JSON non ha coperto lastSuccessfulSyncAt".into(),
                        }),
                        stream_fallback,
                        ..SyncReport::new(effective_cause)
                    });
                }
                items
            }
        };

        let (found, withdrawn_ids) = self.read_hint(hint, &snapshot.records).await?;
        remotes = merge(remotes, found);

        let mut changes = Vec::new();
        let mut upserts: Vec<VoxRecord> = Vec::new();
        let mut new_document_ids = Vec::new();

        for remote in remotes {
            match snapshot.records.get(&remote.document_id) {
                Some(existing) => {
                    let mut record = existing.clone();
                    if record.fingerprint != remote.fingerprint {
                        changes.push(ContentChange::Updated(remote.document_id.clone()));
                    }
                    record.permalink = remote.permalink;
                    record.list_text = remote.list_text;
                    record.created_at = remote.created_at;
                    record.updated_at = remote.updated_at;
                    record.fingerprint = remote.fingerprint;
                    record.last_observed_at = started_at;
                    record.is_available = true;
                    upserts.push(record);
                }
                None => {
                    changes.push(ContentChange::Published(remote.document_id.clone()));
                    if !is_baseline {
                        new_document_ids.push(remote.document_id.clone());
                    }
                    upserts.push(VoxRecord {
                        document_id: remote.document_id,
                        permalink: remote.permalink,
                        list_text: remote.list_text,
                        created_at: remote.created_at,
                        updated_at: remote.updated_at,
                        fingerprint: remote.fingerprint,
                        first_observed_at: started_at,
                        last_observed_at: started_at,
                        read_at: None,
                        notified_at: None,
                        is_available: true,
                    });
                }
            }
        }
        changes.extend(withdrawn_ids.iter().cloned().map(ContentChange::Withdrawn));

        let notifications = self.notification_policy.decisions(effective_cause, &new_document_ids);
        let notified: HashSet<String> = notifications.iter().flat_map(NotificationDecision::document_ids).collect();
        for record in &mut upserts {
            if notified.contains(&record.document_id) {
                record.notified_at = Some(started_at);
            }
        }

        self.store.apply(StoreTransaction {
            upserts,
            withdrawn_ids,
            last_successful_sync_at: Some(started_at),
            has_completed_baseline: Some(true),
        });

        Ok(SyncReport {
            completed_baseline: true,
            used_rss: true,
            used_json,
            json_pages_fetched: json_pages,
            changes,
            notifications,
            last_successful_sync_at: Some(started_at),
            stream_fallback,
            ..SyncReport::new(effective_cause)
        })
    }

    async fn collect_json_hole(
        &self,
        cursor: DateTime<Utc>,
        json_pages: &mut u32,
    ) -> Result<(Vec<RemoteVox>, bool), ClientError> {
        let mut collected = Vec::new();
        let mut covered = false;
        let mut page = 1;
        while !covered && *json_pages < self.configuration.max_json_pages {
            if *json_pages > 0 && self.configuration.json_page_delay_seconds > 0.0 {
                self.clock.sleep(self.configuration.json_page_delay_seconds).await;
            }
            let list = self.client.fetch_list_page(page).await?;
            *json_pages += 1;
            let empty = list.items.is_empty();
            for item in list.items {
                if item.created_at > cursor {
                    collected.push(item);
                } else {
                    covered = true;
                }
            }
            if empty || page >= list.page_count {
                covered = true;
            }
            page += 1;
        }
        Ok((dedupe(collected), covered))
    }

    async fn read_hint(
        &self,
        hint: &SyncHint,
        known: &BTreeMap<String, VoxRecord>,
    ) -> Result<(Vec<RemoteVox>, Vec<String>), ClientError> {
        let document_id = match hint {
            SyncHint::VoxNew(id) | SyncHint::VoxUpdated(id) => id,
            _ => return Ok((Vec::new(), Vec::new())),
        };
        if let Some(remote) = self.client.fetch_detail(document_id).await? {
            return Ok((vec![remote], Vec::new()));
        }
        // Solo un 404 su un VOX già noto è un ritiro.
        if known.contains_key(document_id) {
            return Ok((Vec::new(), vec![document_id.clone()]));
        }
        Ok((Vec::new(), Vec::new()))
    }
}

/// Libera il posto «in volo» anche se la sincronizzazione viene annullata a metà.
struct InFlightGuard<'a>(&'a Mutex<Option<watch::Receiver<Option<SyncReport>>>>);

impl Drop for InFlightGuard<'_> {
    fn drop(&mut self) {
        *self.0.lock().unwrap() = None;
    }
}

fn rss_covers_hole(rss: &[RemoteVox], cursor: DateTime<Utc>, store: &StoreSnapshot) -> bool {
    let Some(oldest) = rss.iter().map(|r| r.created_at).min() else { return false };
    oldest <= cursor || rss.iter().any(|r| store.records.contains_key(&r.document_id))
}

fn merge(mut remotes: Vec<RemoteVox>, extras: Vec<RemoteVox>) -> Vec<RemoteVox> {
    for extra in extras {
        match remotes.iter_mut().find(|r| r.document_id == extra.document_id) {
            Some(existing) => *existing = extra,
            None => remotes.push(extra),
        }
    }
    remotes
}

fn dedupe(remotes: Vec<RemoteVox>) -> Vec<RemoteVox> {
    let mut seen = HashSet::new();
    remotes.into_iter().filter(|r| seen.insert(r.document_id.clone())).collect()
}

fn is_retryable(failure: &SyncFailure) -> bool {
    match failure.kind {
        SyncFailureKind::Offline | SyncFailureKind::Unknown => true,
        SyncFailureKind::HttpStatus(status) => status == 429 || (500..600).contains(&status),
        SyncFailureKind::IncompatiblePayload | SyncFailureKind::IncompleteCatchUp => false,
    }
}

fn map_failure(error: &ClientError) -> SyncFailure {
    let kind = match error {
        ClientError::Offline(_) => SyncFailureKind::Offline,
        ClientError::IncompatiblePayload(_) => SyncFailureKind::IncompatiblePayload,
        ClientError::HttpStatus(status) => SyncFailureKind::HttpStatus(*status),
        ClientError::Unknown(_) => SyncFailureKind::Unknown,
    };
    let message = match error {
        ClientError::IncompatiblePayload(m) => m.clone(),
        other => other.to_string(),
    };
    SyncFailure { kind, message }
}
