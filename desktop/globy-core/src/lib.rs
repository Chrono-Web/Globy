//! Nucleo di Globy per Windows e Linux: porting di `Packages/GlobyCore` (Swift).
//!
//! Stesse regole del Mac: HTTP è autorevole e gli eventi SSE sono solo segnali
//! (ADR 0002), il primo avvio non notifica l'archivio, lo store è un file JSON
//! (ADR 0004). I test leggono le fixture del pacchetto Swift per restare allineati.

mod client;
mod clock;
mod dates;
mod fixture;
mod models;
mod policies;
mod rss;
mod sse;
mod store;
mod sync;
mod vox_text;

pub use client::{
    ChronocolClient, ChronocolConfiguration, ChronocolReading, ClientError, HttpResponse, HttpTransport,
    ReqwestTransport,
};
pub use clock::{Clock, SystemClock};
pub use fixture::FixtureChronocol;
pub use models::*;
pub use policies::*;
pub use sse::SseParser;
pub use store::{ContentStore, FileContentStore, InMemoryContentStore, StoreSnapshot, StoreTransaction};
pub use sync::SyncCoordinator;
pub use vox_text::VoxText;
