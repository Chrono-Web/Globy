use crate::models::{NotificationDecision, SyncCause, SyncReport};
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NotificationPolicy {
    pub summary_threshold: usize,
}

impl Default for NotificationPolicy {
    fn default() -> Self {
        Self { summary_threshold: 4 }
    }
}

impl NotificationPolicy {
    pub fn decisions(&self, cause: SyncCause, new_document_ids: &[String]) -> Vec<NotificationDecision> {
        if cause == SyncCause::FirstLaunch || new_document_ids.is_empty() {
            return Vec::new();
        }
        if new_document_ids.len() >= self.summary_threshold {
            return vec![NotificationDecision::Summary(new_document_ids.to_vec())];
        }
        new_document_ids.iter().cloned().map(NotificationDecision::NewVox).collect()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct RetryPolicy {
    pub max_attempts: u32,
    pub base_delay_seconds: f64,
    pub jitter_fraction: f64,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self { max_attempts: 3, base_delay_seconds: 0.2, jitter_fraction: 0.2 }
    }
}

impl RetryPolicy {
    pub const TESTS: RetryPolicy = RetryPolicy { max_attempts: 3, base_delay_seconds: 0.05, jitter_fraction: 0.0 };

    pub(crate) fn delay_before_attempt(&self, attempt: u32) -> f64 {
        if attempt <= 1 {
            return 0.0;
        }
        let exponential = self.base_delay_seconds * 2f64.powi(attempt as i32 - 2);
        if self.jitter_fraction <= 0.0 {
            return exponential;
        }
        let jitter = exponential * self.jitter_fraction * (fastrand::f64() * 2.0 - 1.0);
        (exponential + jitter).max(0.0)
    }
}

/// Traduce le decisioni di sync in ciò che menu, Globy e banner possono mostrare.
/// Le preferenze utente non cambiano lo store: filtrano solo la presentazione.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PresentationPlan {
    pub mascot_document_ids: Vec<String>,
    pub banner_document_ids: Vec<String>,
    pub is_summary: bool,
}

pub struct PresentationPolicy;

impl PresentationPolicy {
    pub fn plan(report: &SyncReport, mascot_enabled: bool, notifications_paused: bool) -> PresentationPlan {
        let mut ids = Vec::new();
        let mut is_summary = false;
        for decision in &report.notifications {
            if matches!(decision, NotificationDecision::Summary(_)) {
                is_summary = true;
            }
            ids.extend(decision.document_ids());
        }
        if ids.is_empty() {
            return PresentationPlan::default();
        }
        PresentationPlan {
            mascot_document_ids: if mascot_enabled { ids.clone() } else { Vec::new() },
            banner_document_ids: if notifications_paused { Vec::new() } else { ids },
            is_summary,
        }
    }
}

/// Saluto di rientro: all'avvio e al risveglio Globy dice sempre com'è andata.
/// Il numero viene dalla sincronizzazione appena conclusa, mai da un segnale SSE.
pub struct WelcomePolicy;

impl WelcomePolicy {
    /// Onboarding raccontato da Globy dopo la presentazione: icona di sistema e Impostazioni.
    /// Diverso dal Mac: lì c'è la barra dei menu, qui l'area di notifica.
    pub const ONBOARDING: [&str; 2] = [
        "Quando non ci sono io, mi trovi tra le icone di sistema: è il globo. Con un clic vedi gli ultimi VOX, e in evidenza quelli nuovi che non hai ancora letto.",
        "Nello stesso menu ci sono le Impostazioni: puoi tenermi sempre a schermo, togliermi il suono, cambiare le dimensioni o passare alle notifiche di sistema al posto mio.",
    ];

    /// Quanti VOX recenti Globy propone di mostrare al primo avvio.
    pub const TOUR_SIZE: usize = 5;

    /// Primo fumetto del primo avvio: chi è Globy.
    pub const INTRODUCTION: &str = "Ciao, sono Globy! Ti porto i VOX di Chronocol: quando ne esce uno nuovo vengo un attimo qui, in basso a destra. Ti spiego in breve come funziono.";

    /// Chiusura dell'onboarding: propone i VOX recenti. `None` se non ce ne sono.
    pub fn tour_offer(latest_count: usize) -> Option<String> {
        match latest_count {
            0 => None,
            1 => Some("Tutto qui. Partiamo con l'ultimo VOX pubblicato?".into()),
            n => Some(format!("Tutto qui. Partiamo con gli ultimi {n} VOX pubblicati?")),
        }
    }

    pub fn message(new_vox_count: usize, sync_failed: bool) -> String {
        if sync_failed {
            return "Heilà! Adesso non riesco a raggiungere Chronocol, quindi non so ancora se ti sei perso qualcosa. Io resto qui.".into();
        }
        match new_vox_count {
            0 => "Heilà! Non ti sei perso nulla. Io resto attivo: se esce un nuovo VOX, arrivo.".into(),
            1 => "Heilà! Mentre eri via è uscito un nuovo VOX. Vuoi vederlo? Usa la freccia.".into(),
            n => format!("Heilà! Mentre eri via sono usciti {n} nuovi VOX. Vuoi vederli? Usa la freccia."),
        }
    }
}

/// Controllo HTTP periodico. Valori provvisori finché la frequenza non è concordata con
/// Chronocol (`docs/CONTRATTO_API.md`, domanda 8).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PollingPolicy {
    pub interval: f64,
    pub max_interval: f64,
    pub jitter_fraction: f64,
}

impl Default for PollingPolicy {
    fn default() -> Self {
        Self::new(300.0, 1800.0, 0.1)
    }
}

impl PollingPolicy {
    pub fn new(interval: f64, max_interval: f64, jitter_fraction: f64) -> Self {
        Self { interval, max_interval: interval.max(max_interval), jitter_fraction }
    }

    /// Attesa prima del prossimo controllo. Gli errori consecutivi raddoppiano l'attesa
    /// fino a `max_interval`; il jitter (`random` in -1...1) sparpaglia i client.
    pub fn delay(&self, consecutive_failures: u32, random: f64) -> f64 {
        let exponent = consecutive_failures.min(16) as i32;
        let base = (self.interval * 2f64.powi(exponent)).min(self.max_interval);
        let jitter = base * self.jitter_fraction * random.clamp(-1.0, 1.0);
        (base + jitter).max(1.0)
    }
}

/// Quanto resta il fumetto dopo che il testo è stato scritto: il tempo di leggerlo,
/// a circa 200 parole al minuto, tra 2 e 15 secondi.
pub struct ReadingPolicy;

impl ReadingPolicy {
    pub const MINIMUM_LINGER: f64 = 2.0;
    pub const MAXIMUM_LINGER: f64 = 15.0;
    pub const SECONDS_PER_WORD: f64 = 0.3;

    pub fn linger(text: &str) -> f64 {
        let words = text.split_whitespace().count() as f64;
        (words * Self::SECONDS_PER_WORD).clamp(Self::MINIMUM_LINGER, Self::MAXIMUM_LINGER)
    }
}
