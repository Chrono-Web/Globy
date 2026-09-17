use quick_xml::events::Event;
use quick_xml::Reader;

use crate::client::{ChronocolConfiguration, ClientError};
use crate::dates;
use crate::models::RemoteVox;

#[derive(Default)]
struct Item {
    title: Option<String>,
    link: Option<String>,
    guid: Option<String>,
    pub_date: Option<String>,
    description: Option<String>,
}

impl Item {
    /// Ultimo segmento del permalink (`guid`, altrimenti `link`).
    fn document_id(&self) -> Option<String> {
        let raw = self.guid.as_ref().or(self.link.as_ref())?;
        let url = url::Url::parse(raw).ok()?;
        url.path_segments()?.filter(|s| !s.is_empty()).last().map(str::to_string)
    }
}

pub(crate) fn parse(data: &[u8], configuration: &ChronocolConfiguration) -> Result<Vec<RemoteVox>, ClientError> {
    let incompatible = || ClientError::IncompatiblePayload("RSS non analizzabile".into());
    let mut reader = Reader::from_reader(data);
    let mut buf = Vec::new();
    let mut items = Vec::new();
    let mut current: Option<Item> = None;
    let mut text = String::new();

    loop {
        match reader.read_event_into(&mut buf).map_err(|_| incompatible())? {
            Event::Start(e) => {
                if e.name().as_ref() == b"item" {
                    current = Some(Item::default());
                }
                text.clear();
            }
            Event::Text(t) => {
                if current.is_some() {
                    text.push_str(&t.unescape().map_err(|_| incompatible())?);
                }
            }
            Event::CData(c) => {
                if current.is_some() {
                    text.push_str(&String::from_utf8_lossy(&c.into_inner()));
                }
            }
            Event::End(e) => {
                let value = text.trim().to_string();
                text.clear();
                let name = e.name();
                if name.as_ref() == b"item" {
                    if let Some(item) = current.take() {
                        items.push(item);
                    }
                } else if let Some(item) = current.as_mut() {
                    match name.as_ref() {
                        b"title" => item.title = Some(value),
                        b"link" => item.link = Some(value),
                        b"guid" => item.guid = Some(value),
                        b"pubDate" => item.pub_date = Some(value),
                        b"description" => item.description = Some(value),
                        _ => {}
                    }
                }
            }
            Event::Eof => break,
            _ => {}
        }
        buf.clear();
    }

    items
        .into_iter()
        .map(|item| {
            let id = item
                .document_id()
                .ok_or_else(|| ClientError::IncompatiblePayload("item RSS senza documentId".into()))?;
            let created_at = item
                .pub_date
                .as_deref()
                .and_then(dates::parse_rss)
                .ok_or_else(|| ClientError::IncompatiblePayload("item RSS senza pubDate".into()))?;
            let text = item.description.or(item.title).unwrap_or_default();
            Ok(RemoteVox::new(id.clone(), configuration.permalink(&id), text, created_at, created_at))
        })
        .collect()
}
