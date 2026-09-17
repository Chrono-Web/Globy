//! Icona per l'area di notifica, disegnata dal codice come il globo: sfera scura con
//! bordo chiaro, un parallelo, un meridiano e due occhi. Leggibile su barre chiare e scure.

pub fn rgba(size: u32) -> Vec<u8> {
    let s = size as f64;
    let c = s / 2.0;
    let r = s * 0.44;
    let line = (s / 16.0).max(1.0);
    let mut pixels = vec![0u8; (size * size * 4) as usize];

    // Supercampionamento 4×4 per bordi morbidi.
    const SAMPLES: u32 = 4;
    for y in 0..size {
        for x in 0..size {
            let (mut fill, mut white) = (0.0, 0.0);
            for sy in 0..SAMPLES {
                for sx in 0..SAMPLES {
                    let px = x as f64 + (sx as f64 + 0.5) / SAMPLES as f64 - c;
                    let py = y as f64 + (sy as f64 + 0.5) / SAMPLES as f64 - c;
                    let d = (px * px + py * py).sqrt();
                    if d > r {
                        continue;
                    }
                    fill += 1.0;
                    let rim = d > r - line;
                    let equator = (py - r * 0.18).abs() < line * 0.5;
                    // Meridiano: ellisse larga metà del raggio.
                    let e = (px / (r * 0.5)).powi(2) + (py / r).powi(2);
                    let meridian = (e.sqrt() - 1.0).abs() * r * 0.5 < line * 0.5;
                    let eye = |ex: f64| {
                        let dx = (px - ex) / (r * 0.11);
                        let dy = (py + r * 0.28) / (r * 0.2);
                        dx * dx + dy * dy <= 1.0
                    };
                    if rim || equator || meridian || eye(-r * 0.3) || eye(r * 0.3) {
                        white += 1.0;
                    }
                }
            }
            let total = (SAMPLES * SAMPLES) as f64;
            let alpha = fill / total;
            if alpha == 0.0 {
                continue;
            }
            let lightness = white / fill;
            let value = 30.0 + (245.0 - 30.0) * lightness;
            let i = ((y * size + x) * 4) as usize;
            pixels[i] = value as u8;
            pixels[i + 1] = value as u8;
            pixels[i + 2] = value as u8;
            pixels[i + 3] = (alpha * 255.0).round() as u8;
        }
    }
    pixels
}
