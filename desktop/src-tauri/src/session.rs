//! Proprietario unico della sessione: sync, store, preferenze, elenco, Globy e banner.
//! Porting di `Globy/AppSession.swift` e `Globy/PollingScheduler.swift`.

use chrono::{DateTime, Utc};
use globy_core::*;
use serde::Serialize;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use tauri::{AppHandle, Emitter, Manager};
use tauri_plugin_autostart::ManagerExt as _;
use tauri_plugin_notification::NotificationExt as _;
use tauri_plugin_opener::OpenerExt as _;
use tokio::sync::Notify;

use crate::prefs::Preferences;
use crate::windows;

/// Chronocol vero in release; in debug la fixture in processo, salvo `GLOBY_LIVE=1`.
pub enum Client {
    Live(ChronocolClient<ReqwestTransport>),
    Fixture(FixtureChronocol),
}

impl ChronocolReading for Client {
    async fn fetch_rss(&self) -> Result<Vec<RemoteVox>, ClientError> {
        match self {
            Self::Live(c) => c.fetch_rss().await,
            Self::Fixture(f) => f.fetch_rss().await,
        }
    }

    async fn fetch_list_page(&self, page: u32) -> Result<VoxListPage, ClientError> {
        match self {
            Self::Live(c) => c.fetch_list_page(page).await,
            Self::Fixture(f) => f.fetch_list_page(page).await,
        }
    }

    async fn fetch_detail(&self, document_id: &str) -> Result<Option<RemoteVox>, ClientError> {
        match self {
            Self::Live(c) => c.fetch_detail(document_id).await,
            Self::Fixture(f) => f.fetch_detail(document_id).await,
        }
    }
}

type Coordinator = SyncCoordinator<Client, FileContentStore, SystemClock>;

/// VOX pronto per l'elenco e per Globy.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct VoxView {
    pub document_id: String,
    pub text: String,
    pub permalink: String,
    pub created_at: DateTime<Utc>,
    pub is_unread: bool,
    pub is_read: bool,
    pub is_notified: bool,
}

/// Tutto ciò che elenco e Impostazioni mostrano, inviato a ogni cambiamento.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppState {
    pub recent: Vec<VoxView>,
    pub unread_count: usize,
    pub is_syncing: bool,
    pub last_failure: Option<String>,
    pub preferences: Preferences,
    pub launch_at_login: bool,
    pub uses_fixture: bool,
    pub platform: Platform,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Platform {
    pub windows: bool,
    pub linux: bool,
    /// Con Wayland le app non scelgono la propria posizione né leggono il puntatore.
    pub wayland: bool,
}

impl Platform {
    pub fn current() -> Self {
        let wayland = cfg!(target_os = "linux")
            && (std::env::var("XDG_SESSION_TYPE").is_ok_and(|v| v.eq_ignore_ascii_case("wayland"))
                || std::env::var_os("WAYLAND_DISPLAY").is_some());
        Self { windows: cfg!(windows), linux: cfg!(target_os = "linux"), wayland }
    }
}

/// Richiesta a Globy. La sequenza (fumetti, frecce, scelte) la gestisce la sua finestra.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum MascotRequest {
    /// Nuovi VOX, dal più vecchio al più recente.
    Burst { voxes: Vec<VoxView> },
    /// Saluto di rientro, poi i VOX usciti nel frattempo.
    Welcome { text: String, voxes: Vec<VoxView> },
    /// Primo avvio: presentazione, due passi e proposta dei VOX recenti.
    Onboarding { introduction: String, steps: Vec<String>, offer: Option<String>, latest: Vec<VoxView> },
}

pub struct Session {
    app: AppHandle,
    coordinator: Coordinator,
    uses_fixture: bool,
    preferences: Mutex<Preferences>,
    preferences_path: PathBuf,
    data_dir: PathBuf,
    is_syncing: AtomicBool,
    last_failure: Mutex<Option<String>>,
    poll_failures: AtomicU32,
    reschedule: Notify,
}

/// Senza novità, un saluto ogni 10 minuti al massimo.
const QUIET_WELCOME_SECONDS: i64 = 600;
const RECENT_LIMIT: usize = 15;

impl Session {
    pub fn new(app: AppHandle) -> Arc<Self> {
        let data_dir = app.path().app_data_dir().unwrap_or_else(|_| std::env::temp_dir().join("globy"));
        let live = !cfg!(debug_assertions) || std::env::var("GLOBY_LIVE").is_ok_and(|v| v == "1");
        let configuration = ChronocolConfiguration::production();
        let client = if live {
            Client::Live(ChronocolClient::new(configuration.clone(), ReqwestTransport::new()))
        } else {
            Client::Fixture(FixtureChronocol::default())
        };
        // In debug i dati veri stanno in un file a parte, per non mescolarli alla fixture.
        let content = data_dir.join(if live || !cfg!(debug_assertions) { "content.json" } else { "content-fixture.json" });
        let coordinator = SyncCoordinator::new(
            client,
            FileContentStore::new(content),
            SystemClock,
            configuration,
            NotificationPolicy::default(),
            RetryPolicy { max_attempts: 3, base_delay_seconds: 0.4, jitter_fraction: 0.2 },
        );
        let preferences_path = data_dir.join("preferences.json");
        Arc::new(Self {
            app,
            coordinator,
            uses_fixture: !live,
            preferences: Mutex::new(Preferences::load(&preferences_path)),
            preferences_path,
            data_dir,
            is_syncing: AtomicBool::new(false),
            last_failure: Mutex::new(None),
            poll_failures: AtomicU32::new(0),
            reschedule: Notify::new(),
        })
    }

    pub fn preferences(&self) -> Preferences {
        self.preferences.lock().unwrap().clone()
    }

    fn update_preferences(&self, change: impl FnOnce(&mut Preferences)) {
        let mut preferences = self.preferences.lock().unwrap();
        change(&mut preferences);
        preferences.save(&self.preferences_path);
    }

    pub fn start(self: &Arc<Self>) {
        let session = Arc::clone(self);
        tauri::async_runtime::spawn(async move { session.polling_loop().await });
        let session = Arc::clone(self);
        tauri::async_runtime::spawn(async move { session.wake_watch().await });

        // Solo sviluppo: `GLOBY_SIMULATE_VOX=N` pubblica N VOX sulla fixture dopo l'avvio.
        if cfg!(debug_assertions) {
            if let Some(count) = std::env::var("GLOBY_SIMULATE_VOX").ok().and_then(|v| v.parse::<usize>().ok()) {
                let session = Arc::clone(self);
                tauri::async_runtime::spawn(async move {
                    tokio::time::sleep(Duration::from_secs(4)).await;
                    session.simulate_publication(count).await;
                });
            }
        }

        let session = Arc::clone(self);
        tauri::async_runtime::spawn(async move {
            if session.preferences().did_greet {
                session.synchronize(SyncCause::Wake, true).await;
            } else {
                // La presentazione aspetta la baseline: serve sapere quali VOX proporre.
                session.synchronize(SyncCause::Wake, false).await;
                session.present_greeting_if_needed().await;
            }
        });
    }

    // MARK: Stato per l'interfaccia

    pub fn state(&self) -> AppState {
        let snapshot = self.coordinator.store().snapshot();
        let baseline_at = snapshot.records.values().map(|r| r.first_observed_at).min();
        let is_unread = |r: &VoxRecord| r.read_at.is_none() && baseline_at.is_some_and(|b| r.first_observed_at > b);
        let unread_count = snapshot.records.values().filter(|r| r.is_available && is_unread(r)).count();
        let mut available: Vec<&VoxRecord> = snapshot.records.values().filter(|r| r.is_available).collect();
        available.sort_by(|a, b| b.created_at.cmp(&a.created_at));
        let recent = available.into_iter().take(RECENT_LIMIT).map(|r| view(r, is_unread(r))).collect();
        AppState {
            recent,
            unread_count,
            is_syncing: self.is_syncing.load(Ordering::Relaxed),
            last_failure: self.last_failure.lock().unwrap().clone(),
            preferences: self.preferences(),
            launch_at_login: self.app.autolaunch().is_enabled().unwrap_or(false),
            uses_fixture: self.uses_fixture,
            platform: Platform::current(),
        }
    }

    pub fn broadcast(&self) {
        let _ = self.app.emit("state", self.state());
        crate::tray::refresh_tooltip(&self.app, self.state().unread_count);
    }

    // MARK: Sincronizzazione

    pub async fn synchronize(self: &Arc<Self>, cause: SyncCause, welcome: bool) {
        self.is_syncing.store(true, Ordering::Relaxed);
        self.broadcast();
        let report = self.coordinator.synchronize(cause, SyncHint::None).await;
        self.is_syncing.store(false, Ordering::Relaxed);
        // Una sync accorpata a quella in volo ne riporta lo stesso esito: già presentato.
        if report.coalesced {
            self.broadcast();
            return;
        }
        let failures = if report.failure.is_none() { 0 } else { self.poll_failures.load(Ordering::Relaxed) + 1 };
        self.poll_failures.store(failures, Ordering::Relaxed);
        self.reschedule.notify_one();
        *self.last_failure.lock().unwrap() = report.failure.as_ref().map(|f| f.message.clone());
        self.broadcast();
        self.present(&report, welcome);
    }

    /// Un solo timer alla volta, ripianificato dopo ogni sincronizzazione.
    async fn polling_loop(self: Arc<Self>) {
        let policy = polling_policy();
        loop {
            let failures = self.poll_failures.load(Ordering::Relaxed);
            let delay = policy.delay(failures, fastrand::f64() * 2.0 - 1.0);
            tokio::select! {
                _ = tokio::time::sleep(Duration::from_secs_f64(delay)) => {
                    self.synchronize(SyncCause::Polling, false).await;
                }
                _ = self.reschedule.notified() => {}
            }
        }
    }

    /// Risveglio dallo stop: l'orologio di sistema salta in avanti rispetto al battito.
    /// Qualche secondo per lasciar tornare la rete, poi sincronizza e saluta.
    async fn wake_watch(self: Arc<Self>) {
        const BEAT: Duration = Duration::from_secs(20);
        let mut last = SystemTime::now();
        loop {
            tokio::time::sleep(BEAT).await;
            let now = SystemTime::now();
            let gap = now.duration_since(last).unwrap_or_default();
            last = now;
            if gap > BEAT * 3 {
                tokio::time::sleep(Duration::from_secs(3)).await;
                self.synchronize(SyncCause::Wake, true).await;
                last = SystemTime::now();
            }
        }
    }

    // MARK: Presentazione

    fn record_views(&self, ids: &[String]) -> Vec<VoxView> {
        let snapshot = self.coordinator.store().snapshot();
        let mut records: Vec<&VoxRecord> = ids.iter().filter_map(|id| snapshot.records.get(id)).collect();
        // Dal più vecchio al più recente, come ogni sequenza di Globy.
        records.sort_by(|a, b| a.created_at.cmp(&b.created_at));
        records.into_iter().map(|r| view(r, r.read_at.is_none())).collect()
    }

    fn present(&self, report: &SyncReport, welcome: bool) {
        let preferences = self.preferences();
        // Globy o notifiche di sistema, mai entrambi.
        let plan = PresentationPolicy::plan(report, preferences.mascot_enabled, preferences.mascot_enabled);
        let voxes = self.record_views(&plan.mascot_document_ids);

        if welcome && report.cause != SyncCause::FirstLaunch && preferences.mascot_enabled {
            self.present_welcome(report, voxes);
        } else if !voxes.is_empty() {
            windows::present_mascot(&self.app, MascotRequest::Burst { voxes });
        }

        if plan.banner_document_ids.is_empty() {
            return;
        }
        let notify = |title: &str, body: &str| {
            let _ = self.app.notification().builder().title(title).body(body).show();
        };
        if plan.is_summary {
            notify("Nuovi VOX su Chronocol", &format!("Ci sono {} nuovi VOX.", plan.banner_document_ids.len()));
        } else {
            for vox in self.record_views(&plan.banner_document_ids) {
                notify("Nuovo VOX", &vox.text);
            }
        }
    }

    fn present_welcome(&self, report: &SyncReport, voxes: Vec<VoxView>) {
        let now = Utc::now();
        let quiet = self
            .preferences()
            .last_welcome_at
            .is_some_and(|last| (now - last).num_seconds() < QUIET_WELCOME_SECONDS);
        if quiet && voxes.is_empty() && report.failure.is_none() {
            return;
        }
        self.update_preferences(|p| p.last_welcome_at = Some(now));
        let text = WelcomePolicy::message(voxes.len(), report.failure.is_some());
        windows::present_mascot(&self.app, MascotRequest::Welcome { text, voxes });
    }

    /// Primo avvio, una volta: presentazione, icona di sistema, Impostazioni e proposta dei
    /// VOX recenti. Gli ultimi VOX già usciti sono «recenti», mai notificati.
    async fn present_greeting_if_needed(&self) {
        let preferences = self.preferences();
        if !preferences.mascot_enabled || preferences.did_greet {
            return;
        }
        self.update_preferences(|p| p.did_greet = true);
        let mut latest: Vec<VoxView> = self.state().recent.into_iter().take(WelcomePolicy::TOUR_SIZE).collect();
        latest.reverse();
        for vox in &mut latest {
            vox.is_unread = false;
        }
        tokio::time::sleep(Duration::from_millis(800)).await;
        windows::present_mascot(
            &self.app,
            MascotRequest::Onboarding {
                introduction: WelcomePolicy::INTRODUCTION.into(),
                steps: WelcomePolicy::ONBOARDING.iter().map(|s| s.to_string()).collect(),
                offer: WelcomePolicy::tour_offer(latest.len()),
                latest,
            },
        );
    }

    // MARK: Azioni

    pub fn open(&self, document_id: &str) {
        let snapshot = self.coordinator.store().snapshot();
        let Some(record) = snapshot.records.get(document_id) else { return };
        self.coordinator.store().mark_read(document_id, Utc::now());
        if let Err(error) = self.app.opener().open_url(&record.permalink, None::<&str>) {
            *self.last_failure.lock().unwrap() = Some(error.to_string());
        }
        self.broadcast();
    }

    pub fn open_permalink(&self, permalink: &str) {
        if let Some(record) =
            self.coordinator.store().snapshot().records.values().find(|r| r.permalink == permalink)
        {
            self.coordinator.store().mark_read(&record.document_id, Utc::now());
        }
        let _ = self.app.opener().open_url(permalink, None::<&str>);
        self.broadcast();
    }

    pub fn set_preferences(&self, patch: serde_json::Value) {
        self.update_preferences(|p| p.merge(patch));
        self.broadcast();
        let _ = self.app.emit("preferences", self.preferences());
    }

    pub fn finish_onboarding(&self) {
        self.update_preferences(|p| p.did_onboard = true);
        self.broadcast();
    }

    pub fn set_launch_at_login(&self, on: bool) {
        let manager = self.app.autolaunch();
        let result = if on { manager.enable() } else { manager.disable() };
        if let Err(error) = result {
            *self.last_failure.lock().unwrap() = Some(error.to_string());
        }
        self.broadcast();
    }

    pub async fn reset_local_data(self: &Arc<Self>) {
        windows::dismiss_mascot(&self.app);
        self.coordinator.store().reset();
        self.update_preferences(|p| *p = Preferences::default());
        self.broadcast();
        let _ = self.app.emit("preferences", self.preferences());
        self.synchronize(SyncCause::Wake, false).await;
        self.present_greeting_if_needed().await;
    }

    /// Toglie avvio al login, VOX salvati e impostazioni. Su Windows avvia poi il
    /// disinstallatore; su Linux l'eseguibile va tolto a mano (AppImage o pacchetto).
    pub fn uninstall(&self) -> Result<(), String> {
        let _ = self.app.autolaunch().disable();
        let _ = std::fs::remove_dir_all(&self.data_dir);
        #[cfg(windows)]
        {
            let exe = std::env::current_exe().map_err(|e| e.to_string())?;
            let uninstaller = exe.with_file_name("uninstall.exe");
            if uninstaller.exists() {
                std::process::Command::new(uninstaller).spawn().map_err(|e| e.to_string())?;
            }
        }
        self.app.exit(0);
        Ok(())
    }

    pub async fn simulate_publication(self: &Arc<Self>, count: usize) {
        let Client::Fixture(fixture) = self.coordinator.client() else { return };
        let now = Utc::now();
        for index in 0..count {
            let at = now + chrono::Duration::seconds(index as i64);
            let mut vox = FixtureChronocol::make_publication(at);
            vox.document_id = format!("{}-{}", vox.document_id, fastrand::u32(..));
            if count > 1 {
                vox = RemoteVox::new(
                    vox.document_id,
                    vox.permalink,
                    format!("VOX di raffica {} (fixture locale).", index + 1),
                    at,
                    at,
                );
            }
            fixture.publish(vox);
        }
        self.synchronize(SyncCause::Manual, false).await;
    }
}

fn view(record: &VoxRecord, is_unread: bool) -> VoxView {
    VoxView {
        document_id: record.document_id.clone(),
        text: VoxText::readable(&record.list_text),
        permalink: record.permalink.clone(),
        created_at: record.created_at,
        is_unread,
        is_read: record.read_at.is_some(),
        is_notified: record.notified_at.is_some(),
    }
}

/// In debug `GLOBY_POLL_SECONDS` accorcia l'intervallo per provare il controllo periodico.
fn polling_policy() -> PollingPolicy {
    if cfg!(debug_assertions) {
        if let Some(seconds) = std::env::var("GLOBY_POLL_SECONDS").ok().and_then(|s| s.parse::<f64>().ok()) {
            return PollingPolicy::new(seconds, seconds * 6.0, 0.1);
        }
    }
    PollingPolicy::default()
}
