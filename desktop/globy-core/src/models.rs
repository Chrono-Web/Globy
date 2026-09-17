use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::dates;

/// VOX osservato localmente. `read_at` e `notified_at` sono fatti distinti.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VoxRecord {
    pub document_id: String,
    pub permalink: String,
    pub list_text: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub fingerprint: String,
    pub first_observed_at: DateTime<Utc>,
    pub last_observed_at: DateTime<Utc>,
    pub read_at: Option<DateTime<Utc>>,
    pub notified_at: Option<DateTime<Utc>>,
    pub is_available: bool,
}

/// Payload minimo letto da RSS o JSON. Non è uno stato locale.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoteVox {
    pub document_id: String,
    pub permalink: String,
    pub list_text: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub fingerprint: String,
}

impl RemoteVox {
    pub fn new(
        document_id: impl Into<String>,
        permalink: impl Into<String>,
        list_text: impl Into<String>,
        created_at: DateTime<Utc>,
        updated_at: DateTime<Utc>,
    ) -> Self {
        let list_text = list_text.into();
        let fingerprint = content_fingerprint(updated_at, &list_text);
        Self {
            document_id: document_id.into(),
            permalink: permalink.into(),
            list_text,
            created_at,
            updated_at,
            fingerprint,
        }
    }
}

/// `updatedAt` e SHA-256 del testo: cambia solo se il VOX cambia davvero.
pub fn content_fingerprint(updated_at: DateTime<Utc>, list_text: &str) -> String {
    let digest = Sha256::digest(list_text.as_bytes());
    let hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    format!("{}|{hex}", dates::iso8601_string(updated_at))
}

#[derive(Debug, Clone, PartialEq)]
pub struct VoxListPage {
    pub items: Vec<RemoteVox>,
    pub page: u32,
    pub page_size: u32,
    pub page_count: u32,
    pub total: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SyncCause {
    FirstLaunch,
    Hint,
    Reconnect,
    Wake,
    Polling,
    Manual,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", content = "documentId", rename_all = "camelCase")]
pub enum ContentChange {
    Published(String),
    Updated(String),
    Withdrawn(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", content = "documentIds", rename_all = "camelCase")]
pub enum NotificationDecision {
    NewVox(String),
    Summary(Vec<String>),
}

impl NotificationDecision {
    pub fn document_ids(&self) -> Vec<String> {
        match self {
            Self::NewVox(id) => vec![id.clone()],
            Self::Summary(ids) => ids.clone(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "type", content = "status", rename_all = "camelCase")]
pub enum SyncFailureKind {
    Offline,
    IncompatiblePayload,
    HttpStatus(u16),
    IncompleteCatchUp,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SyncFailure {
    pub kind: SyncFailureKind,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SyncReport {
    pub cause: SyncCause,
    pub completed_baseline: bool,
    pub used_rss: bool,
    pub used_json: bool,
    pub json_pages_fetched: u32,
    pub changes: Vec<ContentChange>,
    pub notifications: Vec<NotificationDecision>,
    pub last_successful_sync_at: Option<DateTime<Utc>>,
    pub failure: Option<SyncFailure>,
    pub coalesced: bool,
    pub stream_fallback: bool,
}

impl SyncReport {
    pub fn new(cause: SyncCause) -> Self {
        Self {
            cause,
            completed_baseline: false,
            used_rss: false,
            used_json: false,
            json_pages_fetched: 0,
            changes: Vec::new(),
            notifications: Vec::new(),
            last_successful_sync_at: None,
            failure: None,
            coalesced: false,
            stream_fallback: false,
        }
    }
}

/// Segnale non autorevole. Non implica che un VOX sia nuovo.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HintEvent {
    Connected,
    Heartbeat,
    VoxNew { document_id: String, created_at: Option<DateTime<Utc>> },
    VoxUpdated { document_id: String },
    Malformed,
    Unknown { event: String },
    StreamUnavailable { status_code: u16 },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SyncHint {
    None,
    VoxNew(String),
    VoxUpdated(String),
    StreamUnavailable,
    Wake,
}
