use serde::Deserialize;

use crate::dates;
use crate::models::{HintEvent, SyncHint};

pub struct SseParser;

impl SseParser {
    pub fn parse(text: &str) -> Vec<HintEvent> {
        text.replace("\r\n", "\n")
            .split("\n\n")
            .map(|block| block.trim_matches(|c| c == '\n' || c == '\r'))
            .filter(|block| !block.is_empty())
            .filter_map(parse_block)
            .collect()
    }

    pub fn hint(event: &HintEvent) -> Option<SyncHint> {
        match event {
            HintEvent::VoxNew { document_id, .. } => Some(SyncHint::VoxNew(document_id.clone())),
            HintEvent::VoxUpdated { document_id } => Some(SyncHint::VoxUpdated(document_id.clone())),
            HintEvent::StreamUnavailable { .. } => Some(SyncHint::StreamUnavailable),
            _ => None,
        }
    }
}

fn parse_block(block: &str) -> Option<HintEvent> {
    let mut event_name: Option<String> = None;
    let mut data_lines: Vec<&str> = Vec::new();
    let mut saw_comment = false;

    for line in block.split('\n') {
        if line.starts_with(':') {
            saw_comment = true;
        } else if let Some(rest) = line.strip_prefix("event:") {
            event_name = Some(rest.trim().to_string());
        } else if let Some(rest) = line.strip_prefix("data:") {
            data_lines.push(rest.trim());
        }
    }

    let data = data_lines.join("\n");
    let Some(event_name) = event_name else {
        if !saw_comment {
            return None;
        }
        return Some(if block.contains("connected") { HintEvent::Connected } else { HintEvent::Heartbeat });
    };
    Some(match event_name.as_str() {
        "vox-new" => decode_new(&data),
        "vox-updated" => decode_updated(&data),
        _ => HintEvent::Unknown { event: event_name },
    })
}

fn decode_new(data: &str) -> HintEvent {
    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Payload {
        document_id: String,
        created_at: Option<String>,
    }
    match serde_json::from_str::<Payload>(data) {
        Ok(p) => HintEvent::VoxNew {
            document_id: p.document_id,
            created_at: p.created_at.as_deref().and_then(dates::parse_iso8601),
        },
        Err(_) => HintEvent::Malformed,
    }
}

fn decode_updated(data: &str) -> HintEvent {
    #[derive(Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct Payload {
        document_id: String,
    }
    match serde_json::from_str::<Payload>(data) {
        Ok(p) => HintEvent::VoxUpdated { document_id: p.document_id },
        Err(_) => HintEvent::Malformed,
    }
}
