//! Icona nell'area di notifica. Windows: clic sinistro apre l'elenco, destro il menu.
//! Linux: le icone di sistema (AppIndicator) mandano solo il menu, quindi l'elenco è la
//! prima voce del menu.

use tauri::image::Image;
use tauri::menu::{Menu, MenuItem, PredefinedMenuItem};
use tauri::tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent};
use tauri::AppHandle;

use crate::windows;

const TRAY_ID: &str = "globy";
const ICON_SIZE: u32 = 32;

pub fn install(app: &AppHandle) -> tauri::Result<()> {
    let list = MenuItem::with_id(app, "list", "Ultimi VOX", true, None::<&str>)?;
    let settings = MenuItem::with_id(app, "settings", "Impostazioni…", true, None::<&str>)?;
    let quit = MenuItem::with_id(app, "quit", "Esci", true, None::<&str>)?;
    let separator = PredefinedMenuItem::separator(app)?;
    let menu = Menu::with_items(app, &[&list, &settings, &separator, &quit])?;

    TrayIconBuilder::with_id(TRAY_ID)
        .icon(Image::new_owned(crate::tray_icon::rgba(ICON_SIZE), ICON_SIZE, ICON_SIZE))
        .tooltip("Globy")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "list" => windows::show_menu(app, None),
            "settings" => windows::show_settings(app),
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
    let Some(tray) = app.tray_by_id(TRAY_ID) else { return };
    let text = match unread {
        0 => "Globy".to_string(),
        1 => "Globy, 1 VOX non letto".to_string(),
        n => format!("Globy, {n} VOX non letti"),
    };
    let _ = tray.set_tooltip(Some(text));
}
