//! Baseline, catch-up, hint SSE e affidabilità: `BaselineTests`, `CatchUpTests`,
//! `HintTests` e `ReliabilityTests` del pacchetto Swift.

mod support;

use globy_core::*;
use std::collections::HashSet;
use support::*;

// MARK: Baseline

/// Il primo avvio salva il RSS e non notifica l'archivio.
#[tokio::test]
async fn first_launch_does_not_notify() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("c", -1.0), remote("b", -2.0), remote("a", -3.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);

    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    assert_eq!(report.cause, SyncCause::FirstLaunch);
    assert!(report.completed_baseline);
    assert!(report.used_rss);
    assert!(!report.used_json);
    assert!(report.notifications.is_empty());
    assert_eq!(published_count(&report), 3);
    assert!(client.list_pages_requested().is_empty());

    let snapshot = coordinator.store().snapshot();
    assert!(snapshot.has_completed_baseline);
    assert_eq!(snapshot.records.len(), 3);
    assert!(snapshot.records.values().all(|r| r.notified_at.is_none()));
    assert_eq!(snapshot.last_successful_sync_at, Some(t0()));
}

/// Un fallimento al primo avvio non chiude la baseline.
#[tokio::test]
async fn failed_first_launch_leaves_baseline_open() {
    let client = FakeChronocol::default();
    client.fail_rss(5, FakeChronocol::offline());
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);

    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let snapshot = coordinator.store().snapshot();

    assert_eq!(report.failure.map(|f| f.kind), Some(SyncFailureKind::Offline));
    assert!(!snapshot.has_completed_baseline);
    assert!(snapshot.records.is_empty());
}

// MARK: Catch-up

/// Un RSS che copre lastSuccessfulSyncAt non legge il JSON.
#[tokio::test]
async fn rss_that_covers_does_not_fetch_json() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("a", -3.0), remote("b", -2.0), remote("c", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(2.0));
    client.set_rss(vec![remote("d", 1.0), remote("c", -1.0)]);
    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let snapshot = coordinator.store().snapshot();

    assert!(!report.used_json);
    assert_eq!(report.json_pages_fetched, 0);
    assert_eq!(report.notifications, vec![NotificationDecision::NewVox("d".into())]);
    assert_eq!(snapshot.records["d"].notified_at, Some(hours(2.0)));
    assert!(client.list_pages_requested().is_empty());
}

/// Un RSS troppo corto pagina il JSON fino a coprire il buco.
#[tokio::test]
async fn short_rss_paginates_json_until_cursor() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("old-a", -30.0), remote("old-b", -29.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(10.0));
    client.set_rss(vec![remote("new-2", 9.0), remote("new-1", 8.0)]);
    client.set_pages(vec![
        page(1, 2, vec![remote("new-2", 9.0), remote("new-1", 8.0)], 4),
        page(2, 2, vec![remote("mid", 1.0), remote("old-b", -29.0)], 4),
    ]);

    let report = coordinator.synchronize(SyncCause::Reconnect, SyncHint::None).await;
    let snapshot = coordinator.store().snapshot();

    assert!(report.used_json);
    assert_eq!(report.json_pages_fetched, 2);
    assert_eq!(client.list_pages_requested(), vec![1, 2]);
    let notified: HashSet<String> = report.notifications.iter().flat_map(|n| n.document_ids()).collect();
    assert_eq!(notified, ids(&["new-2", "new-1", "mid"]).into_iter().collect());
    assert!(snapshot.records.contains_key("mid"));
    assert!(snapshot.records["old-a"].is_available);
}

/// Un VOX assente dal solo RSS non è un ritiro.
#[tokio::test]
async fn missing_from_rss_is_not_withdrawal() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("keep", -2.0), remote("drop-from-feed", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(1.0));
    client.set_rss(vec![remote("keep", -2.0), remote("newer", 0.5)]);
    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let snapshot = coordinator.store().snapshot();

    assert!(!report.changes.contains(&ContentChange::Withdrawn("drop-from-feed".into())));
    assert!(snapshot.records["drop-from-feed"].is_available);
    assert_eq!(report.notifications, vec![NotificationDecision::NewVox("newer".into())]);
}

/// Un aggiornamento di un VOX già letto non è una nuova pubblicazione.
#[tokio::test]
async fn update_of_read_vox_is_not_new_publication() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote_with("vox", -1.0, Some("versione 1"), None)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    coordinator.store().mark_read("vox", hours(-0.5));

    clock.set_now(hours(1.0));
    let updated = remote_with("vox", -1.0, Some("versione 2"), Some(0.5));
    client.set_rss(vec![updated.clone()]);
    client.set_detail("vox", Some(updated));
    let report = coordinator.handle_hint(&HintEvent::VoxUpdated { document_id: "vox".into() }).await;
    let snapshot = coordinator.store().snapshot();

    assert_eq!(report.changes, vec![ContentChange::Updated("vox".into())]);
    assert!(report.notifications.is_empty());
    assert_eq!(snapshot.records["vox"].read_at, Some(hours(-0.5)));
    assert_eq!(snapshot.records["vox"].list_text, "versione 2");
}

/// Se il JSON non copre il buco il cursore non avanza.
#[tokio::test]
async fn incomplete_json_does_not_advance_cursor() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("old", -40.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator_with(&client, &clock, test_configuration(2, 1));
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let cursor = coordinator.store().snapshot().last_successful_sync_at;

    clock.set_now(hours(5.0));
    client.set_rss(vec![remote("new", 4.0)]);
    client.set_pages(vec![page(1, 3, vec![remote("new", 4.0), remote("newer", 3.0)], 6)]);
    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    assert_eq!(report.failure.map(|f| f.kind), Some(SyncFailureKind::IncompleteCatchUp));
    assert_eq!(coordinator.store().snapshot().last_successful_sync_at, cursor);
}

// MARK: Hint SSE

/// Un evento SSE non è un VOX nuovo se HTTP non lo conferma.
#[tokio::test]
async fn sse_is_not_authoritative() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("known", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(1.0));
    client.set_detail("ghost", None);
    let event = HintEvent::VoxNew { document_id: "ghost".into(), created_at: Some(hours(0.5)) };
    let report = coordinator.handle_hint(&event).await;
    let snapshot = coordinator.store().snapshot();

    assert!(report.changes.is_empty());
    assert!(report.notifications.is_empty());
    assert!(!snapshot.records.contains_key("ghost"));
    assert_eq!(client.details_requested(), ids(&["ghost"]));
    assert_eq!(client.fetch_rss_count(), 2);
}

/// Due hint duplicati producono una sola notifica.
#[tokio::test]
async fn duplicate_hints_do_not_duplicate_notifications() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("known", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    let fresh = remote("fresh", 1.0);
    clock.set_now(hours(2.0));
    client.set_rss(vec![fresh.clone(), remote("known", -1.0)]);
    client.set_detail("fresh", Some(fresh));

    let event = HintEvent::VoxNew { document_id: "fresh".into(), created_at: Some(hours(1.0)) };
    let first = coordinator.handle_hint(&event).await;
    let second = coordinator.handle_hint(&event).await;

    assert_eq!(first.notifications, vec![NotificationDecision::NewVox("fresh".into())]);
    assert!(second.notifications.is_empty());
    assert!(second.changes.is_empty());
    assert_eq!(coordinator.store().snapshot().records["fresh"].notified_at, Some(hours(2.0)));
}

/// Un 503 dello stream fa fallback al catch-up HTTP senza svuotare lo store.
#[tokio::test]
async fn stream_503_falls_back_without_wiping_store() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("kept", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(1.0));
    let report = coordinator.handle_hint(&HintEvent::StreamUnavailable { status_code: 503 }).await;
    let snapshot = coordinator.store().snapshot();

    assert!(report.stream_fallback);
    assert_eq!(report.cause, SyncCause::Polling);
    assert!(report.failure.is_none());
    assert!(snapshot.records.contains_key("kept"));
    assert!(snapshot.has_completed_baseline);
}

/// Un ritiro si conferma solo con 404 sul dettaglio HTTP.
#[tokio::test]
async fn withdrawal_requires_http_404() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("gone", -1.0), remote("stay", -2.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(1.0));
    client.set_rss(vec![remote("stay", -2.0)]);
    client.set_detail("gone", None);
    let report = coordinator.handle_hint(&HintEvent::VoxUpdated { document_id: "gone".into() }).await;
    let snapshot = coordinator.store().snapshot();

    assert_eq!(report.changes, vec![ContentChange::Withdrawn("gone".into())]);
    assert!(!snapshot.records["gone"].is_available);
    assert!(snapshot.records["stay"].is_available);
    assert!(report.notifications.is_empty());
}

/// Un SSE malformato non autorizza cambiamenti.
#[tokio::test]
async fn malformed_sse_does_not_change_state() {
    let text = String::from_utf8(fixture("sse-malformed.txt")).unwrap();
    let events = SseParser::parse(&text);
    assert!(events.contains(&HintEvent::Malformed));
    assert!(events.contains(&HintEvent::Unknown { event: "mystery".into() }));

    let client = FakeChronocol::default();
    client.set_rss(vec![remote("known", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let report = coordinator.handle_hint(&HintEvent::Malformed).await;

    assert!(report.changes.is_empty());
    assert_eq!(client.fetch_rss_count(), 1);
    assert_eq!(coordinator.store().snapshot().records.len(), 1);
}

// MARK: Affidabilità

/// Offline prolungato non cancella lo store e il retry recupera.
#[tokio::test]
async fn prolonged_offline_keeps_store_then_recovers() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("kept", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(3.0));
    client.fail_rss(8, FakeChronocol::offline());
    let failed = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let snapshot = coordinator.store().snapshot();
    assert_eq!(failed.failure.map(|f| f.kind), Some(SyncFailureKind::Offline));
    assert!(snapshot.records.contains_key("kept"));
    assert_eq!(snapshot.last_successful_sync_at, Some(t0()));

    client.fail_rss(0, FakeChronocol::offline());
    client.set_rss(vec![remote("late", 2.0), remote("kept", -1.0)]);
    let ok = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    assert!(ok.failure.is_none());
    assert_eq!(ok.notifications, vec![NotificationDecision::NewVox("late".into())]);
    assert_eq!(coordinator.store().snapshot().last_successful_sync_at, Some(hours(3.0)));
}

/// Il retry usa backoff e poi riesce.
#[tokio::test]
async fn retry_backoff_then_succeeds() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("a", -1.0)]);
    client.fail_rss(2, FakeChronocol::offline());
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);

    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    assert!(report.failure.is_none());
    assert!(report.completed_baseline);
    assert_eq!(client.fetch_rss_count(), 3);
    assert_eq!(clock.sleeps(), vec![0.05, 0.1]);
}

/// Una risposta incompatibile non cancella lo store.
#[tokio::test]
async fn incompatible_payload_keeps_store() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("kept", -1.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(1.0));
    client.fail_rss(1, ClientError::IncompatiblePayload("JSON rotto".into()));
    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    let snapshot = coordinator.store().snapshot();

    assert_eq!(report.failure.map(|f| f.kind), Some(SyncFailureKind::IncompatiblePayload));
    assert!(snapshot.records.contains_key("kept"));
    assert_eq!(snapshot.last_successful_sync_at, Some(t0()));
    assert_eq!(client.fetch_rss_count(), 2);
}

/// Più risvegli ravvicinati producono una sola sincronizzazione in volo.
#[tokio::test]
async fn concurrent_wake_coalesces_to_one_fetch() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("a", -1.0)]);
    client.set_hold_first_rss(true);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);

    let (report1, report2, ()) = tokio::join!(
        coordinator.synchronize(SyncCause::Wake, SyncHint::None),
        async {
            client.wait_until_rss_started().await;
            coordinator.synchronize(SyncCause::Reconnect, SyncHint::None).await
        },
        async {
            client.wait_until_rss_started().await;
            tokio::task::yield_now().await;
            client.release_rss();
        },
    );

    assert_eq!(client.fetch_rss_count(), 1);
    assert!(!report1.coalesced);
    assert!(report2.coalesced);
    assert!(report1.completed_baseline);
    assert!(report2.completed_baseline);
}

/// Una raffica diventa un riepilogo.
#[tokio::test]
async fn burst_becomes_summary() {
    let client = FakeChronocol::default();
    client.set_rss(vec![remote("old", -5.0)]);
    let clock = ControllableClock::default();
    let coordinator = make_coordinator(&client, &clock);
    coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;

    clock.set_now(hours(1.0));
    client.set_rss(vec![
        remote("n1", 0.1),
        remote("n2", 0.2),
        remote("n3", 0.3),
        remote("n4", 0.4),
        remote("old", -5.0),
    ]);
    let report = coordinator.synchronize(SyncCause::Wake, SyncHint::None).await;
    assert_eq!(report.notifications, vec![NotificationDecision::Summary(ids(&["n1", "n2", "n3", "n4"]))]);
}
