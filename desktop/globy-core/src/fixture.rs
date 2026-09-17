use chrono::{DateTime, Utc};
use std::sync::Mutex;

use crate::client::{ChronocolReading, ClientError};
use crate::models::{RemoteVox, VoxListPage};

/// Chronocol in processo per lo sviluppo: nessuna rete. `publish` simula un nuovo VOX.
pub struct FixtureChronocol {
    rss: Mutex<Vec<RemoteVox>>,
}

impl Default for FixtureChronocol {
    fn default() -> Self {
        Self { rss: Mutex::new(Self::seed()) }
    }
}

impl FixtureChronocol {
    pub fn publish(&self, vox: RemoteVox) {
        self.rss.lock().unwrap().insert(0, vox);
    }

    pub fn seed() -> Vec<RemoteVox> {
        let items = [
            ("fixture-baseline-1", "VOX di baseline (fixture). Al primo avvio non genera notifica.", 1_800_000_000),
            ("fixture-baseline-2", "Secondo VOX già presente all'avvio. Resta visibile nel menu.", 1_799_996_400),
            (
                "fixture-baseline-3",
                "Terzo VOX della fixture, più lungo: serve a vedere un fumetto su più righe quando il globo presenta i VOX recenti al primo avvio, senza toccare la rete.",
                1_799_992_800,
            ),
            ("fixture-baseline-4", "Quarto VOX (fixture). Breve.", 1_799_989_200),
            ("fixture-baseline-5", "Quinto VOX della fixture: l'ultimo che il primo avvio propone di mostrare.", 1_799_985_600),
            ("fixture-baseline-6", "Sesto VOX (fixture). Sta nel menu ma resta fuori dalla presentazione dei cinque.", 1_799_982_000),
        ];
        items
            .into_iter()
            .map(|(id, text, seconds)| {
                let date = DateTime::from_timestamp(seconds, 0).unwrap();
                RemoteVox::new(id, "https://chronocol.com/it", text, date, date)
            })
            .collect()
    }

    pub fn make_publication(at: DateTime<Utc>) -> RemoteVox {
        RemoteVox::new(
            format!("fixture-new-{}", at.timestamp()),
            "https://chronocol.com/it",
            "Nuovo VOX simulato. Globy compare solo dopo questa conferma locale.",
            at,
            at,
        )
    }
}

impl ChronocolReading for FixtureChronocol {
    async fn fetch_rss(&self) -> Result<Vec<RemoteVox>, ClientError> {
        Ok(self.rss.lock().unwrap().clone())
    }

    async fn fetch_list_page(&self, page: u32) -> Result<VoxListPage, ClientError> {
        let items = self.rss.lock().unwrap().clone();
        let total = items.len() as u32;
        Ok(VoxListPage { items, page, page_size: 25, page_count: 1, total })
    }

    async fn fetch_detail(&self, document_id: &str) -> Result<Option<RemoteVox>, ClientError> {
        Ok(self.rss.lock().unwrap().iter().find(|r| r.document_id == document_id).cloned())
    }
}
