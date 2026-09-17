use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::PathBuf;
use std::sync::Mutex;

use crate::models::VoxRecord;

#[derive(Debug, Clone, PartialEq, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StoreSnapshot {
    pub last_successful_sync_at: Option<DateTime<Utc>>,
    pub has_completed_baseline: bool,
    pub records: BTreeMap<String, VoxRecord>,
}

#[derive(Debug, Clone, Default)]
pub struct StoreTransaction {
    pub upserts: Vec<VoxRecord>,
    pub withdrawn_ids: Vec<String>,
    pub last_successful_sync_at: Option<DateTime<Utc>>,
    pub has_completed_baseline: Option<bool>,
}

impl StoreSnapshot {
    fn apply(&mut self, transaction: StoreTransaction) {
        for record in transaction.upserts {
            self.records.insert(record.document_id.clone(), record);
        }
        for id in &transaction.withdrawn_ids {
            if let Some(record) = self.records.get_mut(id) {
                record.is_available = false;
            }
        }
        if let Some(cursor) = transaction.last_successful_sync_at {
            self.last_successful_sync_at = Some(cursor);
        }
        if let Some(baseline) = transaction.has_completed_baseline {
            self.has_completed_baseline = baseline;
        }
    }

    fn mark_read(&mut self, document_id: &str, at: DateTime<Utc>) -> bool {
        match self.records.get_mut(document_id) {
            Some(record) => {
                record.read_at = Some(at);
                true
            }
            None => false,
        }
    }
}

/// Le operazioni sono brevi e in memoria: nessun `await` mentre si tiene il lucchetto.
pub trait ContentStore: Send + Sync {
    fn snapshot(&self) -> StoreSnapshot;
    fn apply(&self, transaction: StoreTransaction);
    fn mark_read(&self, document_id: &str, at: DateTime<Utc>);
}

#[derive(Default)]
pub struct InMemoryContentStore {
    state: Mutex<StoreSnapshot>,
}

impl InMemoryContentStore {
    pub fn new() -> Self {
        Self::default()
    }
}

impl ContentStore for InMemoryContentStore {
    fn snapshot(&self) -> StoreSnapshot {
        self.state.lock().unwrap().clone()
    }

    fn apply(&self, transaction: StoreTransaction) {
        self.state.lock().unwrap().apply(transaction);
    }

    fn mark_read(&self, document_id: &str, at: DateTime<Utc>) {
        self.state.lock().unwrap().mark_read(document_id, at);
    }
}

/// Persistenza JSON dietro `ContentStore` (ADR 0004). Scrittura atomica: file temporaneo
/// accanto e poi rinomina, così un'interruzione non lascia un JSON a metà.
pub struct FileContentStore {
    path: PathBuf,
    state: Mutex<StoreSnapshot>,
}

impl FileContentStore {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        let path = path.into();
        let state = std::fs::read(&path)
            .ok()
            .and_then(|data| serde_json::from_slice(&data).ok())
            .unwrap_or_default();
        Self { path, state: Mutex::new(state) }
    }

    pub fn reset(&self) {
        *self.state.lock().unwrap() = StoreSnapshot::default();
        let _ = std::fs::remove_file(&self.path);
    }

    fn persist(&self, state: &StoreSnapshot) {
        if let Some(folder) = self.path.parent() {
            let _ = std::fs::create_dir_all(folder);
        }
        let Ok(data) = serde_json::to_vec_pretty(state) else { return };
        let temporary = self.path.with_extension("json.tmp");
        if std::fs::write(&temporary, data).is_ok() {
            let _ = std::fs::rename(&temporary, &self.path);
        }
    }
}

impl ContentStore for FileContentStore {
    fn snapshot(&self) -> StoreSnapshot {
        self.state.lock().unwrap().clone()
    }

    fn apply(&self, transaction: StoreTransaction) {
        let mut state = self.state.lock().unwrap();
        state.apply(transaction);
        self.persist(&state);
    }

    fn mark_read(&self, document_id: &str, at: DateTime<Utc>) {
        let mut state = self.state.lock().unwrap();
        if state.mark_read(document_id, at) {
            self.persist(&state);
        }
    }
}
