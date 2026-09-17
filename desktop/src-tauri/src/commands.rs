//! Comandi chiamati dalle pagine. Nessuno scrive su Chronocol: solo stato locale.

use std::sync::Arc;
use tauri::{AppHandle, State};

use crate::session::{AppState, Session};
use crate::windows;

type S<'a> = State<'a, Arc<Session>>;

#[tauri::command]
pub fn get_state(session: S) -> AppState {
    session.state()
}

#[tauri::command]
pub fn has_glass() -> bool {
    crate::platform::has_glass()
}

#[tauri::command]
pub fn open_vox(session: S, app: AppHandle, document_id: String) {
    session.open(&document_id);
    windows::hide_menu(&app);
}

#[tauri::command]
pub fn open_permalink(session: S, permalink: String) {
    session.open_permalink(&permalink);
}

#[tauri::command]
pub fn set_preferences(session: S, patch: serde_json::Value) {
    session.set_preferences(patch);
}

#[tauri::command]
pub fn finish_onboarding(session: S) {
    session.finish_onboarding();
}

#[tauri::command]
pub fn set_launch_at_login(session: S, on: bool) {
    session.set_launch_at_login(on);
}

#[tauri::command]
pub async fn reset_local_data(session: S<'_>) -> Result<(), ()> {
    session.inner().reset_local_data().await;
    Ok(())
}

#[tauri::command]
pub fn uninstall(session: S) -> Result<(), String> {
    session.uninstall()
}

#[tauri::command]
pub fn show_settings(app: AppHandle) {
    windows::show_settings(&app);
}

#[tauri::command]
pub fn hide_menu(app: AppHandle) {
    windows::hide_menu(&app);
}

#[tauri::command]
pub fn quit(app: AppHandle) {
    app.exit(0);
}

#[tauri::command]
pub fn mascot_ready(app: AppHandle) {
    windows::mascot_ready(&app);
}

#[tauri::command]
pub async fn simulate_publication(session: S<'_>, count: usize) -> Result<(), ()> {
    session.inner().simulate_publication(count).await;
    Ok(())
}
