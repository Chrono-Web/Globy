//! Finestre: elenco dei VOX vicino all'icona, Impostazioni, Globy.

use std::sync::Mutex;
use tauri::{
    AppHandle, Emitter, Manager, PhysicalPosition, PhysicalSize, Rect, WebviewUrl, WebviewWindow,
    WebviewWindowBuilder, WindowEvent,
};

use crate::session::MascotRequest;

const MENU: &str = "menu";
const SETTINGS: &str = "settings";
const MASCOT: &str = "mascot";
const MENU_WIDTH: f64 = 360.0;
const MENU_HEIGHT: f64 = 520.0;

// MARK: Elenco

fn menu_window(app: &AppHandle) -> tauri::Result<WebviewWindow> {
    if let Some(window) = app.get_webview_window(MENU) {
        return Ok(window);
    }
    let window = WebviewWindowBuilder::new(app, MENU, WebviewUrl::App("menu.html".into()))
        .title("Globy")
        .inner_size(MENU_WIDTH, MENU_HEIGHT)
        .decorations(false)
        .resizable(false)
        .skip_taskbar(true)
        .always_on_top(true)
        .transparent(true)
        .shadow(true)
        .visible(false)
        .build()?;
    crate::platform::apply_glass(&window);
    // Come un menu: sparisce quando si clicca altrove.
    let handle = window.clone();
    window.on_window_event(move |event| {
        if let WindowEvent::Focused(false) = event {
            let _ = handle.hide();
        }
    });
    Ok(window)
}

pub fn toggle_menu(app: &AppHandle, anchor: Option<Rect>) {
    if let Some(window) = app.get_webview_window(MENU) {
        if window.is_visible().unwrap_or(false) {
            let _ = window.hide();
            return;
        }
    }
    show_menu(app, anchor);
}

pub fn show_menu(app: &AppHandle, anchor: Option<Rect>) {
    let Ok(window) = menu_window(app) else { return };
    place_menu(&window, anchor);
    let _ = window.show();
    let _ = window.set_focus();
}

/// Sopra l'icona se la barra è in basso (Windows), sotto se è in alto; senza icona
/// (menu di Linux) in alto a destra. Sempre dentro l'area utile dello schermo.
fn place_menu(window: &WebviewWindow, anchor: Option<Rect>) {
    let Ok(Some(monitor)) = window.primary_monitor() else { return };
    let scale = monitor.scale_factor();
    let size = PhysicalSize::new((MENU_WIDTH * scale) as i32, (MENU_HEIGHT * scale) as i32);
    let area = monitor.work_area();
    let (left, top) = (area.position.x, area.position.y);
    let (right, bottom) = (left + area.size.width as i32, top + area.size.height as i32);
    let margin = (8.0 * scale) as i32;

    let (mut x, mut y) = match anchor {
        Some(rect) => {
            let position = rect.position.to_physical::<i32>(scale);
            let icon = rect.size.to_physical::<i32>(scale);
            let x = position.x + icon.width / 2 - size.width / 2;
            let below_middle = position.y > top + (bottom - top) / 2;
            let y = if below_middle { position.y - size.height - margin } else { position.y + icon.height + margin };
            (x, y)
        }
        None => (right - size.width - margin, top + margin),
    };
    x = x.clamp(left + margin, right - size.width - margin);
    y = y.clamp(top + margin, bottom - size.height - margin);
    let _ = window.set_position(PhysicalPosition::new(x, y));
}

pub fn hide_menu(app: &AppHandle) {
    if let Some(window) = app.get_webview_window(MENU) {
        let _ = window.hide();
    }
}

// MARK: Impostazioni

pub fn show_settings(app: &AppHandle) {
    hide_menu(app);
    if let Some(window) = app.get_webview_window(SETTINGS) {
        let _ = window.unminimize();
        let _ = window.show();
        let _ = window.set_focus();
        return;
    }
    let built = WebviewWindowBuilder::new(app, SETTINGS, WebviewUrl::App("settings.html".into()))
        .title("Impostazioni di Globy")
        .inner_size(480.0, 700.0)
        .min_inner_size(420.0, 480.0)
        .center()
        .build();
    if let Ok(window) = built {
        let _ = app.emit_to(MASCOT, "mascot-preview", true);
        let handle = app.clone();
        window.on_window_event(move |event| {
            if let WindowEvent::Destroyed = event {
                let _ = handle.emit_to(MASCOT, "mascot-preview", false);
            }
        });
    }
}

// MARK: Globy

/// Richieste arrivate prima che la finestra di Globy fosse pronta.
#[derive(Default)]
pub struct MascotBridge {
    ready: Mutex<bool>,
    pending: Mutex<Vec<MascotRequest>>,
}

fn mascot_window(app: &AppHandle) -> tauri::Result<WebviewWindow> {
    if let Some(window) = app.get_webview_window(MASCOT) {
        return Ok(window);
    }
    let window = WebviewWindowBuilder::new(app, MASCOT, WebviewUrl::App("mascot.html".into()))
        .title("Globy")
        .inner_size(420.0, 360.0)
        .decorations(false)
        .resizable(false)
        .skip_taskbar(true)
        .always_on_top(!crate::session::Platform::current().wayland)
        .transparent(true)
        .shadow(false)
        .focused(false)
        .visible(false)
        .build()?;
    Ok(window)
}

pub fn present_mascot(app: &AppHandle, request: MascotRequest) {
    let bridge = app.state::<MascotBridge>();
    if !*bridge.ready.lock().unwrap() {
        bridge.pending.lock().unwrap().push(request);
        let _ = mascot_window(app);
        return;
    }
    let _ = app.emit_to(MASCOT, "mascot-request", request);
}

/// La finestra di Globy ha caricato la pagina: consegna ciò che aspettava.
pub fn mascot_ready(app: &AppHandle) {
    let bridge = app.state::<MascotBridge>();
    *bridge.ready.lock().unwrap() = true;
    let pending: Vec<MascotRequest> = std::mem::take(&mut *bridge.pending.lock().unwrap());
    for request in pending {
        let _ = app.emit_to(MASCOT, "mascot-request", request);
    }
}

pub fn dismiss_mascot(app: &AppHandle) {
    let _ = app.emit_to(MASCOT, "mascot-dismiss", ());
}

/// All'avvio: la finestra di Globy esiste da subito, nascosta, così la prima richiesta
/// non aspetta il caricamento della pagina.
pub fn prepare_mascot(app: &AppHandle) {
    let _ = mascot_window(app);
}
