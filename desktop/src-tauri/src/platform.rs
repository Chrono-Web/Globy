//! Differenze tra sistemi: vetro di Windows, niente vetro altrove.

use tauri::WebviewWindow;

/// Acrylic sotto la pagina: la pagina lascia lo sfondo trasparente e disegna sopra.
#[cfg(windows)]
pub fn apply_glass(window: &WebviewWindow) {
    let _ = window_vibrancy::apply_acrylic(window, Some((24, 24, 28, 110)));
}

#[cfg(not(windows))]
pub fn apply_glass(_window: &WebviewWindow) {}

/// Vero se il vetro di sistema è attivo: la pagina usa uno sfondo quasi trasparente.
pub fn has_glass() -> bool {
    cfg!(windows)
}
