use regex::Regex;
use std::sync::LazyLock;

/// Testo di un VOX pronto da leggere in fumetto, menu e banner. Le fonti restano nel
/// VOX completo su Chronocol: qui sarebbero solo link lunghi e illeggibili.
pub struct VoxText;

static SOURCES: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?im)^\s*fonti?\s*:").unwrap());
static MARKDOWN_LINK: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\[([^\]]*)\]\([^)]*\)?").unwrap());
static BARE_URL: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\]?\(?https?://\S+").unwrap());
static TRAILING_SPACES: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"[ \t]+\n").unwrap());
static EXTRA_NEWLINES: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\n{3,}").unwrap());

impl VoxText {
    pub fn readable(text: &str) -> String {
        // Tutto da «Fonti:» (o «Fonte:») a inizio riga in poi.
        let body = match SOURCES.find(text) {
            Some(found) => &text[..found.start()],
            None => text,
        };
        // [etichetta](url) → etichetta; poi i resti di link spezzati e gli URL nudi.
        let body = MARKDOWN_LINK.replace_all(body, "${1}");
        let body = BARE_URL.replace_all(&body, "");
        let body = TRAILING_SPACES.replace_all(&body, "\n");
        let body = EXTRA_NEWLINES.replace_all(&body, "\n\n");
        let trimmed = body.trim();
        if trimmed.is_empty() { text.trim().to_string() } else { trimmed.to_string() }
    }
}
