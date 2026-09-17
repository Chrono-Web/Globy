use chrono::{DateTime, Utc};
use serde::Deserialize;
use std::time::Duration;
use url::Url;

use crate::dates;
use crate::models::{RemoteVox, VoxListPage};
use crate::rss;

#[derive(Debug, Clone, PartialEq)]
pub struct ChronocolConfiguration {
    pub base_url: Url,
    pub locale_path: String,
    pub list_page_size: u32,
    pub max_json_pages: u32,
    pub json_page_delay_seconds: f64,
}

impl ChronocolConfiguration {
    pub fn new(base_url: Url) -> Self {
        Self { base_url, locale_path: "it".into(), list_page_size: 25, max_json_pages: 200, json_page_delay_seconds: 0.0 }
    }

    /// Chronocol pubblico in produzione.
    pub fn production() -> Self {
        Self::new(Url::parse("https://chronocol.com").unwrap())
    }

    fn join(&self, path: &str) -> Url {
        let mut url = self.base_url.clone();
        let base = url.path().trim_end_matches('/').to_string();
        url.set_path(&format!("{base}/{path}"));
        url
    }

    pub fn permalink(&self, document_id: &str) -> String {
        self.join(&format!("{}/vox/{document_id}", self.locale_path)).to_string()
    }

    pub fn rss_url(&self) -> Url {
        self.join("api/voxes/rss")
    }

    /// Sempre `sort=createdAt:desc`: senza, la pagina 1 parte dall'inizio dell'archivio
    /// (`docs/CONTRATTO_API.md`).
    pub fn list_url(&self, page: u32) -> Url {
        let mut url = self.join("api/voxes");
        url.query_pairs_mut()
            .append_pair("pagination[page]", &page.to_string())
            .append_pair("pagination[pageSize]", &self.list_page_size.to_string())
            .append_pair("sort", "createdAt:desc");
        url
    }

    pub fn detail_url(&self, document_id: &str) -> Url {
        self.join(&format!("api/voxes/{document_id}"))
    }

    pub fn stream_url(&self) -> Url {
        self.join("api/voxes/stream")
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClientError {
    IncompatiblePayload(String),
    HttpStatus(u16),
    /// Rete assente, connessione persa o tempo scaduto: si riprova.
    Offline(String),
    Unknown(String),
}

impl std::fmt::Display for ClientError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::IncompatiblePayload(m) => write!(f, "payload incompatibile: {m}"),
            Self::HttpStatus(s) => write!(f, "HTTP {s}"),
            Self::Offline(m) | Self::Unknown(m) => f.write_str(m),
        }
    }
}

impl std::error::Error for ClientError {}

pub struct HttpResponse {
    pub status: u16,
    pub body: Vec<u8>,
}

/// Solo GET: Globy non modifica mai Chronocol.
pub trait HttpTransport: Send + Sync {
    fn get(&self, url: Url) -> impl Future<Output = Result<HttpResponse, ClientError>> + Send;
}

#[derive(Clone)]
pub struct ReqwestTransport {
    client: reqwest::Client,
}

impl ReqwestTransport {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .user_agent(concat!("Globy/", env!("CARGO_PKG_VERSION")))
            .timeout(Duration::from_secs(30))
            .build()
            .expect("client HTTP");
        Self { client }
    }
}

impl Default for ReqwestTransport {
    fn default() -> Self {
        Self::new()
    }
}

impl HttpTransport for ReqwestTransport {
    async fn get(&self, url: Url) -> Result<HttpResponse, ClientError> {
        let map = |e: reqwest::Error| {
            if e.is_connect() || e.is_timeout() || e.is_request() {
                ClientError::Offline(e.to_string())
            } else {
                ClientError::Unknown(e.to_string())
            }
        };
        let response = self.client.get(url).send().await.map_err(map)?;
        let status = response.status().as_u16();
        let body = response.bytes().await.map_err(map)?.to_vec();
        Ok(HttpResponse { status, body })
    }
}

pub trait ChronocolReading: Send + Sync {
    fn fetch_rss(&self) -> impl Future<Output = Result<Vec<RemoteVox>, ClientError>> + Send;
    fn fetch_list_page(&self, page: u32) -> impl Future<Output = Result<VoxListPage, ClientError>> + Send;
    fn fetch_detail(&self, document_id: &str) -> impl Future<Output = Result<Option<RemoteVox>, ClientError>> + Send;
}

pub struct ChronocolClient<T: HttpTransport> {
    pub configuration: ChronocolConfiguration,
    pub transport: T,
}

impl<T: HttpTransport> ChronocolClient<T> {
    pub fn new(configuration: ChronocolConfiguration, transport: T) -> Self {
        Self { configuration, transport }
    }

    async fn get_success(&self, url: Url) -> Result<Vec<u8>, ClientError> {
        let response = self.transport.get(url).await?;
        expect_success(response.status)?;
        Ok(response.body)
    }
}

fn expect_success(status: u16) -> Result<(), ClientError> {
    if (200..300).contains(&status) { Ok(()) } else { Err(ClientError::HttpStatus(status)) }
}

impl<T: HttpTransport> ChronocolReading for ChronocolClient<T> {
    async fn fetch_rss(&self) -> Result<Vec<RemoteVox>, ClientError> {
        let data = self.get_success(self.configuration.rss_url()).await?;
        rss::parse(&data, &self.configuration)
    }

    async fn fetch_list_page(&self, page: u32) -> Result<VoxListPage, ClientError> {
        let data = self.get_success(self.configuration.list_url(page)).await?;
        decode_list(&data, &self.configuration)
    }

    async fn fetch_detail(&self, document_id: &str) -> Result<Option<RemoteVox>, ClientError> {
        let response = self.transport.get(self.configuration.detail_url(document_id)).await?;
        if response.status == 404 {
            return Ok(None);
        }
        expect_success(response.status)?;
        decode_detail(&response.body, &self.configuration).map(Some)
    }
}

/// Sottoinsieme minimo del JSON pubblico. Gli altri campi sono ignorati di proposito.
#[derive(Deserialize)]
struct ListEnvelope {
    data: Vec<ItemDto>,
    meta: MetaDto,
}

#[derive(Deserialize)]
struct DetailEnvelope {
    data: ItemDto,
}

#[derive(Deserialize)]
struct MetaDto {
    pagination: PaginationDto,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PaginationDto {
    page: u32,
    page_size: u32,
    page_count: u32,
    total: u32,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ItemDto {
    document_id: String,
    created_at: String,
    updated_at: String,
    #[serde(rename = "NOTIZIA")]
    list_text: String,
}

impl ItemDto {
    fn remote(self, configuration: &ChronocolConfiguration) -> Result<RemoteVox, ClientError> {
        let created_at = parse_date(&self.created_at)?;
        let updated_at = parse_date(&self.updated_at)?;
        let permalink = configuration.permalink(&self.document_id);
        Ok(RemoteVox::new(self.document_id, permalink, self.list_text, created_at, updated_at))
    }
}

fn parse_date(raw: &str) -> Result<DateTime<Utc>, ClientError> {
    dates::parse_iso8601(raw).ok_or_else(|| ClientError::IncompatiblePayload(format!("data non ISO-8601: {raw}")))
}

fn decode_list(data: &[u8], configuration: &ChronocolConfiguration) -> Result<VoxListPage, ClientError> {
    let envelope: ListEnvelope =
        serde_json::from_slice(data).map_err(|e| ClientError::IncompatiblePayload(e.to_string()))?;
    let p = envelope.meta.pagination;
    Ok(VoxListPage {
        items: envelope.data.into_iter().map(|i| i.remote(configuration)).collect::<Result<_, _>>()?,
        page: p.page,
        page_size: p.page_size,
        page_count: p.page_count,
        total: p.total,
    })
}

fn decode_detail(data: &[u8], configuration: &ChronocolConfiguration) -> Result<RemoteVox, ClientError> {
    let envelope: DetailEnvelope =
        serde_json::from_slice(data).map_err(|e| ClientError::IncompatiblePayload(e.to_string()))?;
    envelope.data.remote(configuration)
}
