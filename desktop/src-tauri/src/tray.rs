//! Icona nell'area di notifica. Windows: clic sinistro apre l'elenco, destro il menu.
//! Linux: le icone di sistema (AppIndicator) mandano solo il menu, quindi l'elenco è la
//! prima voce del menu.

use std::sync::Mutex;
use tauri::image::Image;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::{AppHandle, Wry};

use crate::windows;

const TRAY_ID: &str = "globy";
const ICON_SIZE: u32 = 32;

/// VOX non letti e versione nuova, per icona e testo al passaggio del mouse.
static STATUS: Mutex<(usize, Option<String>)> = Mutex::new((0, None));

fn menu(app: &AppHandle, update: Option<&str>) -> tauri::Result<Menu<Wry>> {
    let list = MenuItem::with_id(app, "list", "Ultimi VOX", true, None::<&str>)?;
    let settings = MenuItem::with_id(app, "settings", "Impostazioni…", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Esci", true, None::<&str>)?;
    let separator = PredefinedMenuItem::separator(app)?;
    match update {
        Some(version) => {
            let update = MenuItem::with_id(app, "update", format!("Aggiorna a Globy {version}…"), true, None::<&str>)?;
            Menu::with_items(app, &[&list, &update, &settings, &separator, &quit])
        }
        None => Menu::with_items(app, &[&list, &settings, &separator, &quit]),
    }
}

pub fn install(app: &AppHandle) -> tauri::Result<()> {
    TrayIconBuilder::with_id(TRAY_ID)
        .icon(Image::new_owned(crate::tray_icon::rgba(ICON_SIZE, false), ICON_SIZE, ICON_SIZE))
        .tooltip("Globy")
        .menu(&menu(app, None)?)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "list" => windows::show_menu(app, None),
            "settings" | "update" => windows::show_settings(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click { button: MouseButton::Left, button_state: MouseButtonState::Up, rect, .. } =
                event
            {
                windows::toggle_menu(tray.app_handle(), Some(rect));
            }
        })
        .build(app)?;
    Ok(())
}

pub fn refresh_tooltip(app: &AppHandle, unread: usize) {
    let update = {
        let mut status = STATUS.lock().unwrap();
        status.0 = unread;
        status.1.clone()
    };
    apply_tooltip(app, unread, update.is_some());
}

/// Pallino sull'icona e voce «Aggiorna a Globy X…» nel menu, finché c'è una versione nuova.
pub fn set_update(app: &AppHandle, version: Option<String>) {
    let (unread, changed) = {
        let mut status = STATUS.lock().unwrap();
        let changed = status.1 != version;
        status.1 = version.clone();
        (status.0, changed)
    };
    if !changed {
        return;
    }
    let Some(tray) = app.tray_by_id(TRAY_ID) else { return };
    let icon = Image::new_owned(crate::tray_icon::rgba(ICON_SIZE, version.is_some()), ICON_SIZE, ICON_SIZE);
    let _ = tray.set_icon(Some(icon));
    if let Ok(menu) = menu(app, version.as_deref()) {
        let _ = tray.set_menu(Some(menu));
    }
    apply_tooltip(app, unread, version.is_some());
}

fn apply_tooltip(app: &AppHandle, unread: usize, update: bool) {
    let Some(tray) = app.tray_by_id(TRAY_ID) else { return };
    let mut text = match unread {
        0 => "Globy".to_string(),
        1 => "Globy, 1 VOX non letto".to_string(),
        n => format!("Globy, {n} VOX non letti"),
    };
    if update {
        text.push_str(", aggiornamento disponibile");
    }
    let _ = tray.set_tooltip(Some(text));
}
