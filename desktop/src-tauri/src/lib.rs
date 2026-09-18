//! Globy per Windows e Linux. La logica sta in `globy-core`; qui icona di sistema,
//! finestre, preferenze, avvio al login e notifiche.

mod commands;
mod mascot;
mod platform;
mod prefs;
mod session;
mod tray;
mod tray_icon;
mod updates;
mod windows;

use std::sync::Arc;
use tauri::{Manager, RunEvent};
use tauri_plugin_autostart::MacosLauncher;

pub fn run() {
    let app = tauri::Builder::default()
        // Una sola copia di Globy: due globi e due sincronizzazioni si pesterebbero i piedi.
        // Riaprirlo mostra l'elenco dei VOX.
        .plugin(tauri_plugin_single_instance::init(|app, args, _cwd| {
            // Solo sviluppo, sulla copia già aperta: `globy --simulate-vox N` pubblica N VOX,
            // `globy --open-settings` apre le Impostazioni, `globy --install-update` fa come
            // «Aggiornati» nel fumetto.
            if cfg!(debug_assertions) {
                if args.iter().any(|a| a == "--open-settings") {
                    windows::show_settings(app);
                    return;
                }
                if args.iter().any(|a| a == "--install-update") {
                    if let Some(updates) = app.try_state::<Arc<updates::Updates>>() {
                        let updates = Arc::clone(&updates);
                        windows::show_settings(app);
                        tauri::async_runtime::spawn(async move { updates.install().await });
                    }
                    return;
                }
                if let Some(count) = args.iter().position(|a| a == "--simulate-vox").and_then(|i| args.get(i + 1)) {
                    if let (Ok(count), Some(session)) = (count.parse(), app.try_state::<Arc<session::Session>>()) {
                        let session = Arc::clone(&session);
                        tauri::async_runtime::spawn(async move { session.simulate_publication(count).await });
                        return;
                    }
                }
            }
            windows::show_menu(app, None);
        }))
        .plugin(tauri_plugin_autostart::init(MacosLauncher::LaunchAgent, None))
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .manage(mascot::MascotBridge::default())
        .on_menu_event(|app, event| mascot::handle_menu_event(app, event.id.as_ref()))
        .invoke_handler(tauri::generate_handler![
            commands::get_state,
            commands::has_glass,
            commands::open_vox,
            commands::open_permalink,
            commands::mark_read,
            commands::set_preferences,
            commands::finish_onboarding,
            commands::set_launch_at_login,
            commands::reset_local_data,
            commands::uninstall,
            commands::show_settings,
            commands::hide_menu,
            commands::quit,
            mascot::mascot_environment,
            mascot::mascot_ready,
            mascot::mascot_screen,
            mascot::mascot_layout,
            mascot::mascot_set_visible,
            mascot::mascot_follow_pointer,
            mascot::mascot_context_menu,
            commands::check_updates,
            commands::install_update,
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
            let updates = updates::Updates::new(app.handle().clone());
            app.manage(Arc::clone(&updates));
            updates.start();
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
