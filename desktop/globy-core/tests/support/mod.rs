//! Equivalente di `Packages/GlobyCore/Tests/GlobyCoreTests/Support.swift`.
#![allow(dead_code)]

use chrono::{DateTime, Duration, Utc};
use globy_core::*;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;
use tokio::sync::Notify;
use url::Url;

pub fn t0() -> DateTime<Utc> {
    DateTime::from_timestamp(1_800_000_000, 0).unwrap()
}

pub fn hours(h: f64) -> DateTime<Utc> {
    t0() + Duration::milliseconds((h * 3_600_000.0) as i64)
}

pub fn remote(id: &str, h: f64) -> RemoteVox {
    remote_with(id, h, None, None)
}

pub fn remote_with(id: &str, h: f64, text: Option<&str>, updated_hours: Option<f64>) -> RemoteVox {
    RemoteVox::new(
        id,
        format!("https://chronocol.test/it/vox/{id}"),
        text.map(str::to_string).unwrap_or_else(|| format!("testo {id}")),
        hours(h),
        hours(updated_hours.unwrap_or(h)),
    )
}

pub fn page(number: u32, of: u32, items: Vec<RemoteVox>, total: u32) -> VoxListPage {
    VoxListPage { items, page: number, page_size: 2, page_count: of, total }
}

pub fn ids(values: &[&str]) -> Vec<String> {
    values.iter().map(|s| s.to_string()).collect()
}

#[derive(Default)]
pub struct ControllableClock {
    now: Mutex<Option<DateTime<Utc>>>,
    pub sleeps: Mutex<Vec<f64>>,
}

impl ControllableClock {
    pub fn set_now(&self, date: DateTime<Utc>) {
        *self.now.lock().unwrap() = Some(date);
    }

    pub fn sleeps(&self) -> Vec<f64> {
        self.sleeps.lock().unwrap().clone()
    }
}

impl Clock for &ControllableClock {
    fn now(&self) -> DateTime<Utc> {
        self.now.lock().unwrap().unwrap_or_else(t0)
    }

    async fn sleep(&self, seconds: f64) {
        self.sleeps.lock().unwrap().push(seconds);
    }
}

#[derive(Default)]
struct FakeState {
    rss: Vec<RemoteVox>,
    pages: HashMap<u32, VoxListPage>,
    detail_overrides: HashMap<String, Option<RemoteVox>>,
    rss_failures_remaining: u32,
    rss_error: Option<ClientError>,
    fetch_rss_count: u32,
    list_pages_requested: Vec<u32>,
    details_requested: Vec<String>,
    hold_first_rss: bool,
}

#[derive(Default)]
pub struct FakeChronocol {
    state: Mutex<FakeState>,
    started: Notify,
    release: Notify,
}

impl FakeChronocol {
    pub fn set_rss(&self, items: Vec<RemoteVox>) {
        self.state.lock().unwrap().rss = items;
    }

    pub fn set_pages(&self, pages: Vec<VoxListPage>) {
        self.state.lock().unwrap().pages = pages.into_iter().map(|p| (p.page, p)).collect();
    }

    pub fn set_detail(&self, id: &str, value: Option<RemoteVox>) {
        self.state.lock().unwrap().detail_overrides.insert(id.into(), value);
    }

    pub fn fail_rss(&self, times: u32, error: ClientError) {
        let mut state = self.state.lock().unwrap();
        state.rss_failures_remaining = times;
        state.rss_error = Some(error);
    }

    pub fn offline() -> ClientError {
        ClientError::Offline("rete assente".into())
    }

    pub fn set_hold_first_rss(&self, value: bool) {
        self.state.lock().unwrap().hold_first_rss = value;
    }

    pub async fn wait_until_rss_started(&self) {
        if self.state.lock().unwrap().fetch_rss_count > 0 {
            return;
        }
        self.started.notified().await;
    }

    pub fn release_rss(&self) {
        self.release.notify_one();
    }

    pub fn fetch_rss_count(&self) -> u32 {
        self.state.lock().unwrap().fetch_rss_count
    }

    pub fn list_pages_requested(&self) -> Vec<u32> {
        self.state.lock().unwrap().list_pages_requested.clone()
    }

    pub fn details_requested(&self) -> Vec<String> {
        self.state.lock().unwrap().details_requested.clone()
    }
}

impl ChronocolReading for &FakeChronocol {
    async fn fetch_rss(&self) -> Result<Vec<RemoteVox>, ClientError> {
        let hold = {
            let mut state = self.state.lock().unwrap();
            state.fetch_rss_count += 1;
            state.hold_first_rss && state.fetch_rss_count == 1
        };
        self.started.notify_waiters();
        if hold {
            self.release.notified().await;
        }
        let mut state = self.state.lock().unwrap();
        if state.rss_failures_remaining > 0 {
            state.rss_failures_remaining -= 1;
            return Err(state.rss_error.clone().unwrap_or_else(FakeChronocol::offline));
        }
        Ok(state.rss.clone())
    }

    async fn fetch_list_page(&self, page: u32) -> Result<VoxListPage, ClientError> {
        let mut state = self.state.lock().unwrap();
        state.list_pages_requested.push(page);
        state.pages.get(&page).cloned().ok_or(ClientError::HttpStatus(404))
    }

    async fn fetch_detail(&self, document_id: &str) -> Result<Option<RemoteVox>, ClientError> {
        let mut state = self.state.lock().unwrap();
        state.details_requested.push(document_id.into());
        if let Some(value) = state.detail_overrides.get(document_id) {
            return Ok(value.clone());
        }
        if let Some(found) = state.rss.iter().find(|r| r.document_id == document_id) {
            return Ok(Some(found.clone()));
        }
        Ok(state.pages.values().flat_map(|p| p.items.iter()).find(|r| r.document_id == document_id).cloned())
    }
}

pub struct StubTransport<F: Fn(&Url) -> HttpResponse + Send + Sync>(pub F);

impl<F: Fn(&Url) -> HttpResponse + Send + Sync> HttpTransport for StubTransport<F> {
    async fn get(&self, url: Url) -> Result<HttpResponse, ClientError> {
        Ok((self.0)(&url))
    }
}

pub fn ok(body: impl Into<Vec<u8>>) -> HttpResponse {
    HttpResponse { status: 200, body: body.into() }
}

pub fn test_configuration(page_size: u32, max_json_pages: u32) -> ChronocolConfiguration {
    ChronocolConfiguration {
        list_page_size: page_size,
        max_json_pages,
        ..ChronocolConfiguration::new(Url::parse("https://chronocol.test").unwrap())
    }
}

pub type Coordinator<'a> = SyncCoordinator<&'a FakeChronocol, InMemoryContentStore, &'a ControllableClock>;

pub fn make_coordinator<'a>(client: &'a FakeChronocol, clock: &'a ControllableClock) -> Coordinator<'a> {
    make_coordinator_with(client, clock, test_configuration(2, 10))
}

pub fn make_coordinator_with<'a>(
    client: &'a FakeChronocol,
    clock: &'a ControllableClock,
    configuration: ChronocolConfiguration,
) -> Coordinator<'a> {
    SyncCoordinator::new(
        client,
        InMemoryContentStore::new(),
        clock,
        configuration,
        NotificationPolicy { summary_threshold: 4 },
        RetryPolicy::TESTS,
    )
}

/// Le fixture sono quelle del pacchetto Swift: un solo insieme di dati per i due nuclei.
pub fn fixture(name: &str) -> Vec<u8> {
    let path: PathBuf = [env!("CARGO_MANIFEST_DIR"), "../../Packages/GlobyCore/Tests/GlobyCoreTests/Fixtures", name]
        .iter()
        .collect();
    std::fs::read(&path).unwrap_or_else(|_| panic!("fixture mancante: {}", path.display()))
}

pub fn published_count(report: &SyncReport) -> usize {
    report.changes.iter().filter(|c| matches!(c, ContentChange::Published(_))).count()
}
