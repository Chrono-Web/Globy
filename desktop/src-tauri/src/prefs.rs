use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// Stesse preferenze dell'app Mac (`Globy/PreferenceStore.swift`), salvate in JSON.
/// Campi mancanti prendono il valore standard: un file vecchio resta leggibile.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Preferences {
    /// Globy a schermo. Spento vuol dire modalità «notifiche di sistema».
    pub mascot_enabled: bool,
    pub permanence: bool,
    pub mascot_sound_enabled: bool,
    /// Gli occhi seguono il puntatore. Non disponibile con Wayland.
    pub gaze_follows_pointer: bool,
    pub did_greet: bool,
    pub did_onboard: bool,
    /// Le scale restano salvate anche quando le dimensioni personalizzate sono spente.
    pub custom_sizes_enabled: bool,
    pub text_scale: f64,
    pub button_scale: f64,
    pub globe_scale: f64,
    /// Ultimo saluto di rientro: riavvii ravvicinati non ripetono «Heilà».
    pub last_welcome_at: Option<DateTime<Utc>>,
    /// Controllo giornaliero degli aggiornamenti (Impostazioni › Aggiornamenti).
    pub update_checks_enabled: bool,
    /// Ultima versione annunciata da Globy: l'avviso compare una volta sola.
    pub announced_update: Option<String>,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            mascot_enabled: true,
            permanence: false,
            mascot_sound_enabled: true,
            gaze_follows_pointer: true,
            did_greet: false,
            did_onboard: false,
            custom_sizes_enabled: false,
            text_scale: 1.0,
            button_scale: 1.0,
            globe_scale: 1.0,
            last_welcome_at: None,
            update_checks_enabled: true,
            announced_update: None,
        }
    }
}

pub const TEXT_RANGE: (f64, f64) = (0.85, 1.5);
pub const BUTTON_RANGE: (f64, f64) = (0.8, 1.6);
pub const GLOBE_RANGE: (f64, f64) = (0.75, 2.5);

impl Preferences {
    pub fn load(path: &PathBuf) -> Self {
        std::fs::read(path).ok().and_then(|data| serde_json::from_slice(&data).ok()).unwrap_or_default()
    }

    pub fn save(&self, path: &PathBuf) {
        if let Some(folder) = path.parent() {
            let _ = std::fs::create_dir_all(folder);
        }
        if let Ok(data) = serde_json::to_vec_pretty(self) {
            let temporary = path.with_extension("json.tmp");
            if std::fs::write(&temporary, data).is_ok() {
                let _ = std::fs::rename(&temporary, path);
            }
        }
    }

    /// Applica solo i campi presenti in `patch`, con le scale entro i limiti.
    pub fn merge(&mut self, patch: serde_json::Value) {
        let Ok(mut current) = serde_json::to_value(&*self) else { return };
        if let (Some(target), Some(source)) = (current.as_object_mut(), patch.as_object()) {
            for (key, value) in source {
                if target.contains_key(key) {
                    target.insert(key.clone(), value.clone());
                }
            }
        }
        if let Ok(mut merged) = serde_json::from_value::<Preferences>(current) {
            merged.text_scale = merged.text_scale.clamp(TEXT_RANGE.0, TEXT_RANGE.1);
            merged.button_scale = merged.button_scale.clamp(BUTTON_RANGE.0, BUTTON_RANGE.1);
            merged.globe_scale = merged.globe_scale.clamp(GLOBE_RANGE.0, GLOBE_RANGE.1);
            *self = merged;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn merge_keeps_other_fields_and_clamps_scales() {
        let mut prefs = Preferences { permanence: true, ..Default::default() };
        prefs.merge(serde_json::json!({ "globeScale": 9.0, "mascotSoundEnabled": false, "sconosciuto": 1 }));
        assert!(prefs.permanence);
        assert!(!prefs.mascot_sound_enabled);
        assert_eq!(prefs.globe_scale, GLOBE_RANGE.1);
    }

    #[test]
    fn old_file_without_new_fields_loads_defaults() {
        let prefs: Preferences = serde_json::from_str(r#"{ "permanence": true }"#).unwrap();
        assert!(prefs.permanence);
        assert!(prefs.gaze_follows_pointer);
        assert!(prefs.mascot_enabled);
    }
}
