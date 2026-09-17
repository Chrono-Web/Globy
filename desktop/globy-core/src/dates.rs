use chrono::{DateTime, SecondsFormat, Utc};

/// Date ISO-8601 del JSON, con o senza frazioni di secondo.
pub(crate) fn parse_iso8601(text: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(text.trim()).ok().map(|d| d.with_timezone(&Utc))
}

/// `pubDate` del RSS, per esempio `Wed, 16 Sep 2026 12:00:00 GMT`.
pub(crate) fn parse_rss(text: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc2822(text.trim()).ok().map(|d| d.with_timezone(&Utc))
}

/// Come `ISO8601DateFormatter` con i millisecondi: entra nell'impronta dei contenuti.
pub(crate) fn iso8601_string(date: DateTime<Utc>) -> String {
    date.to_rfc3339_opts(SecondsFormat::Millis, true)
}
