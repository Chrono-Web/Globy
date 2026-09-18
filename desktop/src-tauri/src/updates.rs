//! Aggiornamenti con il plugin updater di Tauri. Stessa esperienza del Mac
//! (`Globy/UpdateController.swift`, ADR 0006): pallino sull'icona, riga nell'elenco,
//! avviso di Globy una volta per versione e sezione nelle Impostazioni.
//! Il feed è `latest.json` nell'ultima Release; ogni file è firmato (docs/DISTRIBUZIONE.md).

use serde::Serialize;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tauri::{AppHandle, Manager};
use tauri_plugin_notification::NotificationExt as _;
use tauri_plugin_updater::{Update, UpdaterExt as _};

use crate::session::{MascotRequest, Session};

/// Un controllo al giorno, come sul Mac; il ciclo guarda ogni ora se è ora.
const CHECK_INTERVAL: Duration = Duration::from_secs(24 * 60 * 60);
const LOOP_TICK: Duration = Duration::from_secs(60 * 60);
const FIRST_CHECK_DELAY: Duration = Duration::from_secs(15);

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Phase {
    Idle,
    Checking,
    /// Trovata: aspetta «Scarica e installa».
    Available,
    Downloading,
    /// Scaricata e verificata: l'installer lavora, poi Globy si riapre.
    Installing,
}

/// Quello che elenco, Impostazioni e icona mostrano. Viaggia dentro `AppState`.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateState {
    pub current_version: String,
    pub phase: Phase,
    pub version: Option<String>,
    pub notes_url: Option<String>,
    /// 0…1 durante lo scaricamento, se il server dice quanto è grande.
    pub progress: Option<f64>,
    /// Esito dell'ultimo controllo chiesto a mano: «aggiornato» o un errore.
    pub message: Option<String>,
    /// Il pacchetto `.deb` si installa con la password di amministratore.
    pub needs_password: bool,
}

impl UpdateState {
    pub fn has_update(&self) -> bool {
        matches!(self.phase, Phase::Available | Phase::Downloading | Phase::Installing)
    }
}

pub struct Updates {
    app: AppHandle,
    state: Mutex<UpdateState>,
    pending: Mutex<Option<Update>>,
    last_check: Mutex<Option<Instant>>,
}

impl Updates {
    pub fn new(app: AppHandle) -> Arc<Self> {
        let current_version = app.package_info().version.to_string();
        Arc::new(Self {
            app,
            state: Mutex::new(UpdateState {
                current_version,
                phase: Phase::Idle,
                version: None,
                notes_url: None,
                progress: None,
                message: None,
                needs_password: cfg!(target_os = "linux") && is_deb_install(),
            }),
            pending: Mutex::new(None),
            last_check: Mutex::new(None),
        })
    }

    pub fn state(&self) -> UpdateState {
        self.state.lock().unwrap().clone()
    }

    pub fn start(self: &Arc<Self>) {
        let updates = Arc::clone(self);
        tauri::async_runtime::spawn(async move {
            tokio::time::sleep(FIRST_CHECK_DELAY).await;
            loop {
                let due = updates.last_check.lock().unwrap().is_none_or(|at| at.elapsed() >= CHECK_INTERVAL);
                if due && updates.automatic_checks() && updates.state().phase == Phase::Idle {
                    updates.check(false).await;
                }
                tokio::time::sleep(LOOP_TICK).await;
            }
        });
    }

    fn automatic_checks(&self) -> bool {
        self.session().is_none_or(|session| session.preferences().update_checks_enabled)
    }

    fn session(&self) -> Option<Arc<Session>> {
        self.app.try_state::<Arc<Session>>().map(|session| Arc::clone(&session))
    }

    fn change(&self, edit: impl FnOnce(&mut UpdateState)) {
        let state = {
            let mut state = self.state.lock().unwrap();
            edit(&mut state);
            state.clone()
        };
        crate::tray::set_update(&self.app, state.has_update().then(|| state.version.clone().unwrap_or_default()));
        if let Some(session) = self.session() {
            session.broadcast();
        }
    }

    pub async fn check(self: &Arc<Self>, user_initiated: bool) {
        if matches!(self.state().phase, Phase::Checking | Phase::Downloading | Phase::Installing) {
            return;
        }
        let previous = self.state().phase;
        if user_initiated {
            self.change(|s| {
                s.phase = Phase::Checking;
                s.message = None;
            });
        }
        *self.last_check.lock().unwrap() = Some(Instant::now());
        let result = match self.updater() {
            Ok(updater) => updater.check().await,
            Err(error) => Err(error),
        };
        match result {
            Ok(Some(update)) => {
                let version = update.version.clone();
                *self.pending.lock().unwrap() = Some(update);
                self.change(|s| {
                    s.phase = Phase::Available;
                    s.notes_url = Some(format!("https://github.com/Chrono-Web/GLOBY/releases/tag/v{version}"));
                    s.version = Some(version.clone());
                    s.message = None;
                });
                if !user_initiated {
                    self.announce_once(&version);
                }
            }
            Ok(None) => {
                *self.pending.lock().unwrap() = None;
                self.change(|s| {
                    s.phase = Phase::Idle;
                    s.version = None;
                    s.message = user_initiated.then(|| "Hai già l’ultima versione.".to_string());
                });
            }
            Err(error) => self.change(|s| {
                s.phase = if previous == Phase::Available { Phase::Available } else { Phase::Idle };
                if user_initiated {
                    s.message = Some(format!("Controllo non riuscito: {error}"));
                }
            }),
        }
    }

    /// Scarica, verifica la firma e installa. Su Windows l'installer chiude Globy e lo
    /// riapre; su Linux Globy si riavvia da solo quando il file è al suo posto.
    pub async fn install(self: &Arc<Self>) {
        if self.state().phase != Phase::Available {
            return;
        }
        let Some(update) = self.pending.lock().unwrap().clone() else { return };
        self.change(|s| {
            s.phase = Phase::Downloading;
            s.progress = None;
            s.message = None;
        });
        let mut received: u64 = 0;
        let mut last_shown = 0.0;
        let result = update
            .download_and_install(
                |chunk, total| {
                    received += chunk as u64;
                    let Some(total) = total.filter(|&t| t > 0) else { return };
                    let progress = (received as f64 / total as f64).min(1.0);
                    // Un ridisegno ogni 2%: lo stato completo va a tre finestre.
                    if progress - last_shown >= 0.02 || progress >= 1.0 {
                        last_shown = progress;
                        self.change(|s| s.progress = Some(progress));
                    }
                },
                || self.change(|s| s.phase = Phase::Installing),
            )
            .await;
        match result {
            Ok(()) => self.app.restart(),
            Err(error) => self.change(|s| {
                s.phase = Phase::Available;
                s.progress = None;
                s.message = Some(format!("Aggiornamento non riuscito: {error}"));
            }),
        }
    }

    /// Globy lo dice nel fumetto; in modalità notifiche di sistema arriva una notifica.
    /// Se Globy sta già parlando, la sua finestra riprova più tardi.
    fn announce_once(&self, version: &str) {
        let Some(session) = self.session() else { return };
        let preferences = session.preferences();
        if preferences.announced_update.as_deref() == Some(version) {
            return;
        }
        session.set_preferences(serde_json::json!({ "announcedUpdate": version }));
        if preferences.mascot_enabled {
            let text = format!(
                "È uscita una nuova versione di me, la {version}! Vuoi che mi aggiorni? Ci metto un attimo e poi torno qui."
            );
            crate::mascot::present(&self.app, MascotRequest::Update { text });
        } else {
            let _ = self
                .app
                .notification()
                .builder()
                .title(format!("È disponibile Globy {version}"))
                .body("Apri le Impostazioni per scaricarlo e installarlo.")
                .show();
        }
    }

    fn updater(&self) -> Result<tauri_plugin_updater::Updater, tauri_plugin_updater::Error> {
        let mut builder = self.app.updater_builder();
        // Solo sviluppo: `GLOBY_UPDATE_FEED=http://localhost:8765/latest.json`.
        if cfg!(debug_assertions) {
            if let Some(url) = std::env::var("GLOBY_UPDATE_FEED").ok().and_then(|v| v.parse().ok()) {
                builder = builder.endpoints(vec![url])?;
            }
        }
        builder.build()
    }
}

/// Installato dal pacchetto Debian: l'eseguibile sta sotto /usr, non in un AppImage.
fn is_deb_install() -> bool {
    std::env::var_os("APPIMAGE").is_none()
        && std::env::current_exe().is_ok_and(|path| path.starts_with("/usr"))
}
