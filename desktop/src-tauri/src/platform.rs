//! Differenze tra sistemi: vetro, forma della finestra e comparsa senza fuoco.

use tauri::WebviewWindow;

/// Acrylic sotto la pagina, che lascia lo sfondo trasparente. Vero se il vetro è attivo.
#[cfg(windows)]
pub fn apply_glass(window: &WebviewWindow) -> bool {
    window_vibrancy::apply_acrylic(window, Some((24, 24, 28, 110))).is_ok()
}

#[cfg(not(windows))]
pub fn apply_glass(_window: &WebviewWindow) -> bool {
    false
}

/// Vero se il sistema offre il vetro: la pagina usa uno sfondo quasi trasparente.
pub fn has_glass() -> bool {
    cfg!(windows)
}

/// Compare senza togliere il fuoco a chi sta scrivendo.
#[cfg(windows)]
pub fn show_without_focus(window: &WebviewWindow) {
    use windows_sys::Win32::UI::WindowsAndMessaging::{SW_SHOWNOACTIVATE, ShowWindow};
    match window.hwnd() {
        Ok(hwnd) => unsafe {
            ShowWindow(hwnd.0 as _, SW_SHOWNOACTIVATE);
        },
        Err(_) => {
            let _ = window.show();
        }
    }
}

#[cfg(not(windows))]
pub fn show_without_focus(window: &WebviewWindow) {
    let _ = window.show();
}

/// Forma della finestra = disco del globo più fumetto e pulsanti. Fuori dalla forma la
/// finestra non esiste per Windows: niente vetro e i clic arrivano a ciò che sta sotto.
#[cfg(windows)]
pub fn set_region(window: &WebviewWindow, shapes: &crate::mascot::Shapes) {
    use windows_sys::Win32::Graphics::Gdi::{
        CombineRgn, CreateEllipticRgn, CreateRectRgn, CreateRoundRectRgn, DeleteObject, RGN_OR, SetWindowRgn,
    };
    let (Ok(hwnd), Ok(scale)) = (window.hwnd(), window.scale_factor()) else { return };
    let px = |v: f64| (v * scale).round() as i32;
    unsafe {
        let region = CreateRectRgn(0, 0, 0, 0);
        let (cx, cy) = shapes.globe_center;
        let r = shapes.globe_radius + 1.0;
        let disk = CreateEllipticRgn(px(cx - r), px(cy - r), px(cx + r) + 1, px(cy + r) + 1);
        CombineRgn(region, region, disk, RGN_OR);
        DeleteObject(disk);
        for shape in &shapes.rounded {
            let s = shape.rect;
            let d = px(shape.radius * 2.0);
            let part = CreateRoundRectRgn(px(s.x), px(s.y), px(s.x + s.w) + 1, px(s.y + s.h) + 1, d, d);
            CombineRgn(region, region, part, RGN_OR);
            DeleteObject(part);
        }
        // Da qui la regione appartiene al sistema: non va cancellata.
        SetWindowRgn(hwnd.0 as _, region, 1);
    }
}
