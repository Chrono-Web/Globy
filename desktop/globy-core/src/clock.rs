use chrono::{DateTime, Utc};
use std::time::Duration;

/// Tempo iniettabile: backoff e cursori non devono dipendere dall'orologio di sistema nei test.
pub trait Clock: Send + Sync {
    fn now(&self) -> DateTime<Utc>;
    fn sleep(&self, seconds: f64) -> impl Future<Output = ()> + Send;
}

#[derive(Debug, Default, Clone, Copy)]
pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> DateTime<Utc> {
        Utc::now()
    }

    fn sleep(&self, seconds: f64) -> impl Future<Output = ()> + Send {
        tokio::time::sleep(Duration::from_secs_f64(seconds.max(0.0)))
    }
}
