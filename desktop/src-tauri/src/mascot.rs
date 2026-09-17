//! Finestra di Globy: trasparente, sempre in primo piano, senza rubare il fuoco.
//! Disegno, fumetto, coda e tempi stanno nella pagina (`src/mascot`); qui ci sono le
//! cose che una pagina non può fare: posizione sullo schermo, forma della finestra,
//! clic che passano attraverso e posizione del puntatore fuori dalla finestra.

use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use tauri::menu::{Menu, MenuItem};
use tauri::{AppHandle, Emitter, LogicalPosition, LogicalSize, Manager, WebviewUrl, WebviewWindow, WebviewWindowBuilder};
use tokio::sync::Notify;

use crate::session::{MascotRequest, Platform};

pub const LABEL: &str = "mascot";

/// Rettangolo logico. Per la finestra è in coordinate schermo, per le forme è locale.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
}

impl Rect {
    fn contains(&self, x: f64, y: f64) -> bool {
        x >= self.x && x <= self.x + self.w && y >= self.y && y <= self.y + self.h
    }
}

/// Parti cliccabili della finestra: disco del globo e rettangoli arrotondati (fumetto e
/// pulsanti d'angolo). Tutto il resto lascia passare i clic.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Shapes {
    pub window: Rect,
    pub globe_center: (f64, f64),
    pub globe_radius: f64,
    pub rounded: Vec<RoundedRect>,
}

#[derive(Debug, Clone, Copy, Deserialize)]
pub struct RoundedRect {
    pub rect: Rect,
    /// Serve alla forma della finestra, che esiste solo su Windows.
    #[cfg_attr(not(windows), allow(dead_code))]
    pub radius: f64,
}

impl Shapes {
    fn contains(&self, x: f64, y: f64) -> bool {
        let (cx, cy) = self.globe_center;
        let r = self.globe_radius + 4.0;
        (x - cx).powi(2) + (y - cy).powi(2) <= r * r || self.rounded.iter().any(|s| s.rect.contains(x, y))
    }
}

#[derive(Default)]
pub struct MascotBridge {
    ready: AtomicBool,
    pending: Mutex<Vec<MascotRequest>>,
    visible: AtomicBool,
    follow_pointer: AtomicBool,
    shapes: Mutex<Option<Shapes>>,
    wake: Notify,
}

pub fn window(app: &AppHandle) -> tauri::Result<WebviewWindow> {
    if let Some(window) = app.get_webview_window(LABEL) {
        return Ok(window);
    }
    let platform = Platform::current();
    let window = WebviewWindowBuilder::new(app, LABEL, WebviewUrl::App("mascot.html".into()))
        .title("Globy")
        .inner_size(120.0, 120.0)
        .decorations(false)
        .resizable(false)
        .skip_taskbar(true)
        .always_on_top(!platform.wayland)
        .visible_on_all_workspaces(true)
        .transparent(true)
        .shadow(false)
        .focused(false)
        .visible(false)
        .build()?;
    Ok(window)
}

pub fn present(app: &AppHandle, request: MascotRequest) {
    let bridge = app.state::<MascotBridge>();
    if !bridge.ready.load(Ordering::Relaxed) {
        bridge.pending.lock().unwrap().push(request);
        let _ = window(app);
        return;
    }
    let _ = app.emit_to(LABEL, "mascot-request", request);
}

/// Vetro di sistema dietro Globy: solo su Windows e solo se Acrylic è disponibile.
/// `GLOBY_SURFACE=dark` forza la superficie scura, per confrontare.
fn apply_surface(window: &WebviewWindow) -> bool {
    if std::env::var("GLOBY_SURFACE").is_ok_and(|v| v == "dark") {
        return false;
    }
    crate::platform::apply_glass(window)
}

/// Posizione del puntatore e clic che passano: un controllo ogni 33 ms mentre Globy è a
/// schermo, fermo quando è nascosto. Con Wayland il puntatore fuori dalla finestra non si
/// può leggere: non parte.
pub fn start_pointer_loop(app: AppHandle) {
    if Platform::current().wayland {
        return;
    }
    tauri::async_runtime::spawn(async move {
        let bridge = app.state::<MascotBridge>();
        let mut last_pointer: Option<(f64, f64)> = None;
        let mut ignoring: Option<bool> = None;
        loop {
            if !bridge.visible.load(Ordering::Relaxed) {
                ignoring = None;
                bridge.wake.notified().await;
                continue;
            }
            tokio::time::sleep(Duration::from_millis(33)).await;
            let (Some(window), Ok(cursor)) = (app.get_webview_window(LABEL), app.cursor_position()) else { continue };
            let scale = window.scale_factor().unwrap_or(1.0);
            let screen = (cursor.x / scale, cursor.y / scale);

            if bridge.follow_pointer.load(Ordering::Relaxed) && last_pointer != Some(screen) {
                last_pointer = Some(screen);
                let _ = app.emit_to(LABEL, "mascot-pointer", screen);
            }

            // Su Windows la forma della finestra decide già dove arrivano i clic.
            if cfg!(windows) {
                continue;
            }
            let Some(shapes) = bridge.shapes.lock().unwrap().clone() else { continue };
            let Ok(origin) = window.outer_position() else { continue };
            let local = ((cursor.x - origin.x as f64) / scale, (cursor.y - origin.y as f64) / scale);
            let ignore = !shapes.contains(local.0, local.1);
            if ignoring != Some(ignore) {
                ignoring = Some(ignore);
                let _ = window.set_ignore_cursor_events(ignore);
            }
        }
    });
}

// MARK: Comandi della pagina

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Screen {
    /// Area utile (senza barra delle applicazioni) dello schermo con il puntatore.
    pub work_area: Rect,
    pub glass: bool,
    pub platform: Platform,
}

#[tauri::command]
pub fn mascot_ready(app: AppHandle) -> Screen {
    let bridge = app.state::<MascotBridge>();
    bridge.ready.store(true, Ordering::Relaxed);
    let glass = app.get_webview_window(LABEL).is_some_and(|w| apply_surface(&w));
    let screen = Screen { work_area: work_area(&app), glass, platform: Platform::current() };
    let pending: Vec<MascotRequest> = std::mem::take(&mut *bridge.pending.lock().unwrap());
    let handle = app.clone();
    // Dopo la risposta: la pagina deve prima conoscere lo schermo.
    tauri::async_runtime::spawn(async move {
        tokio::time::sleep(Duration::from_millis(50)).await;
        for request in pending {
            let _ = handle.emit_to(LABEL, "mascot-request", request);
        }
    });
    screen
}

#[tauri::command]
pub fn mascot_screen(app: AppHandle) -> Rect {
    work_area(&app)
}

fn work_area(app: &AppHandle) -> Rect {
    let cursor = app.cursor_position().ok();
    let monitor = cursor
        .and_then(|c| app.monitor_from_point(c.x, c.y).ok().flatten())
        .or_else(|| app.primary_monitor().ok().flatten());
    let Some(monitor) = monitor else { return Rect { x: 0.0, y: 0.0, w: 1280.0, h: 800.0 } };
    let scale = monitor.scale_factor();
    let area = monitor.work_area();
    Rect {
        x: area.position.x as f64 / scale,
        y: area.position.y as f64 / scale,
        w: area.size.width as f64 / scale,
        h: area.size.height as f64 / scale,
    }
}

/// Nuova disposizione: finestra, forma e bersagli dei clic.
#[tauri::command]
pub fn mascot_layout(app: AppHandle, shapes: Shapes) {
    let Some(window) = app.get_webview_window(LABEL) else { return };
    let w = shapes.window;
    let _ = window.set_size(LogicalSize::new(w.w, w.h));
    let _ = window.set_position(LogicalPosition::new(w.x, w.y));
    #[cfg(windows)]
    crate::platform::set_region(&window, &shapes);
    *app.state::<MascotBridge>().shapes.lock().unwrap() = Some(shapes);
}

#[tauri::command]
pub fn mascot_set_visible(app: AppHandle, visible: bool, follow_pointer: bool) {
    let Some(window) = app.get_webview_window(LABEL) else { return };
    let bridge = app.state::<MascotBridge>();
    bridge.follow_pointer.store(follow_pointer, Ordering::Relaxed);
    if visible {
        crate::platform::show_without_focus(&window);
        bridge.visible.store(true, Ordering::Relaxed);
        bridge.wake.notify_one();
    } else {
        bridge.visible.store(false, Ordering::Relaxed);
        let _ = window.hide();
    }
}

#[tauri::command]
pub fn mascot_follow_pointer(app: AppHandle, on: bool) {
    app.state::<MascotBridge>().follow_pointer.store(on, Ordering::Relaxed);
}

/// Clic destro su Globy o sul fumetto: Impostazioni e Nascondi.
#[tauri::command]
pub fn mascot_context_menu(app: AppHandle) -> Result<(), String> {
    let window = app.get_webview_window(LABEL).ok_or("finestra assente")?;
    let settings = MenuItem::with_id(&app, "mascot-settings", "Impostazioni…", true, None::<&str>).map_err(|e| e.to_string())?;
    let hide = MenuItem::with_id(&app, "mascot-hide", "Nascondi Globy", true, None::<&str>).map_err(|e| e.to_string())?;
    let menu = Menu::with_items(&app, &[&settings, &hide]).map_err(|e| e.to_string())?;
    window.popup_menu(&menu).map_err(|e| e.to_string())
}

pub fn handle_menu_event(app: &AppHandle, id: &str) {
    match id {
        "mascot-settings" => crate::windows::show_settings(app),
        "mascot-hide" => {
            let _ = app.emit_to(LABEL, "mascot-hide-now", ());
        }
        _ => {}
    }
}
