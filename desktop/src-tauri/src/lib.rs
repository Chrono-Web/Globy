//! Globy per Windows e Linux. La logica sta in `globy-core`; qui icona di sistema,
//! finestre, preferenze, avvio al login e notifiche.

mod commands;
mod mascot;
mod platform;
mod prefs;
mod session;
mod tray;
mod tray_icon;
mod windows;

use std::sync::Arc;
use tauri::{Manager, RunEvent};
use tauri_plugin_autostart::MacosLauncher;

pub fn run() {
    let app = tauri::Builder::default()
        // Una sola copia di Globy: due globi e due sincronizzazioni si pesterebbero i piedi.
        // Riaprirlo mostra l'elenco dei VOX.
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            windows::show_menu(app, None);
        }))
        .plugin(tauri_plugin_autostart::init(MacosLauncher::LaunchAgent, None))
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .manage(mascot::MascotBridge::default())
        .on_menu_event(|app, event| mascot::handle_menu_event(app, event.id.as_ref()))
        .invoke_handler(tauri::generate_handler![
            commands::get_state,
            commands::has_glass,
            commands::open_vox,
            commands::open_permalink,
            commands::set_preferences,
            commands::finish_onboarding,
            commands::set_launch_at_login,
            commands::reset_local_data,
            commands::uninstall,
            commands::show_settings,
            commands::hide_menu,
            commands::quit,
            mascot::mascot_ready,
            mascot::mascot_screen,
            mascot::mascot_layout,
            mascot::mascot_set_visible,
            mascot::mascot_follow_pointer,
            mascot::mascot_context_menu,
            commands::simulate_publication,
        ])
        .setup(|app| {
            // Sul Mac, dove si sviluppa, niente icona nel Dock: come l'app vera.
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);
            let session = session::Session::new(app.handle().clone());
            app.manage(Arc::clone(&session));
            tray::install(app.handle())?;
            windows::prepare_mascot(app.handle());
            mascot::start_pointer_loop(app.handle().clone());
            session.start();
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("avvio di Globy");

    app.run(|_app, event| {
        // Chiudere le finestre non chiude Globy: resta nell'area di notifica.
        if let RunEvent::ExitRequested { api, code: None, .. } = event {
            api.prevent_exit();
        }
    });
}
