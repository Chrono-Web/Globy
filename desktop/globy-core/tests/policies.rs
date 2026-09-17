//! `PollingTests`, `PresentationTests`, `NotificationPolicyTests` e `VoxTextTests`.

mod support;

use globy_core::*;
use support::ids;

/// Senza errori l'attesa è l'intervallo base.
#[test]
fn polling_base_interval() {
    assert_eq!(PollingPolicy::new(300.0, 1800.0, 0.1).delay(0, 0.0), 300.0);
}

/// Gli errori raddoppiano l'attesa fino al tetto.
#[test]
fn polling_backoff_is_capped() {
    let policy = PollingPolicy::new(300.0, 1800.0, 0.0);
    assert_eq!(policy.delay(1, 0.0), 600.0);
    assert_eq!(policy.delay(2, 0.0), 1200.0);
    assert_eq!(policy.delay(3, 0.0), 1800.0);
    assert_eq!(policy.delay(50, 0.0), 1800.0);
}

/// Il jitter resta entro la frazione dichiarata.
#[test]
fn polling_jitter_is_bounded() {
    let policy = PollingPolicy::new(300.0, 1800.0, 0.1);
    assert_eq!(policy.delay(0, -1.0), 270.0);
    assert_eq!(policy.delay(0, 1.0), 330.0);
    assert_eq!(policy.delay(0, 7.0), 330.0);
}

/// Il primo avvio non manda Globy né banner.
#[test]
fn first_launch_is_silent() {
    let report = SyncReport {
        completed_baseline: true,
        changes: vec![ContentChange::Published("a".into())],
        ..SyncReport::new(SyncCause::FirstLaunch)
    };
    assert_eq!(PresentationPolicy::plan(&report, true, false), PresentationPlan::default());
}

/// Globy spento lascia i banner; la pausa spegne i banner.
#[test]
fn preferences_filter_presentation() {
    let report = SyncReport {
        notifications: vec![NotificationDecision::NewVox("n1".into()), NotificationDecision::NewVox("n2".into())],
        ..SyncReport::new(SyncCause::Manual)
    };
    let mascot_off = PresentationPolicy::plan(&report, false, false);
    assert!(mascot_off.mascot_document_ids.is_empty());
    assert_eq!(mascot_off.banner_document_ids, ids(&["n1", "n2"]));

    let paused = PresentationPolicy::plan(&report, true, true);
    assert_eq!(paused.mascot_document_ids, ids(&["n1", "n2"]));
    assert!(paused.banner_document_ids.is_empty());
}

/// Un riepilogo tiene tutti gli id.
#[test]
fn summary_keeps_all_ids() {
    let report = SyncReport {
        notifications: vec![NotificationDecision::Summary(ids(&["a", "b", "c", "d"]))],
        ..SyncReport::new(SyncCause::Wake)
    };
    let plan = PresentationPolicy::plan(&report, true, false);
    assert!(plan.is_summary);
    assert_eq!(plan.mascot_document_ids, ids(&["a", "b", "c", "d"]));
    assert_eq!(plan.banner_document_ids, ids(&["a", "b", "c", "d"]));
}

/// Il saluto di rientro dice sempre com'è andata.
#[test]
fn welcome_message() {
    assert!(WelcomePolicy::message(0, false).contains("Non ti sei perso nulla"));
    assert!(WelcomePolicy::message(1, false).contains("è uscito un nuovo VOX"));
    assert!(WelcomePolicy::message(3, false).contains("sono usciti 3 nuovi VOX"));
}

/// Se la sincronizzazione fallisce il saluto non dice «nulla di nuovo».
#[test]
fn welcome_after_failure_is_honest() {
    let text = WelcomePolicy::message(0, true);
    assert!(!text.contains("Non ti sei perso nulla"));
    assert!(text.contains("non so ancora"));
}

/// Il primo avvio propone i VOX recenti solo se ce ne sono.
#[test]
fn introduction_offer() {
    assert_eq!(WelcomePolicy::tour_offer(0), None);
    assert!(WelcomePolicy::tour_offer(1).unwrap().ends_with("Partiamo con l'ultimo VOX pubblicato?"));
    assert!(WelcomePolicy::tour_offer(5).unwrap().ends_with("Partiamo con gli ultimi 5 VOX pubblicati?"));
}

/// Il fumetto resta quanto serve a leggerlo, entro i limiti.
#[test]
fn linger_follows_text() {
    assert_eq!(ReadingPolicy::linger("Breve."), ReadingPolicy::MINIMUM_LINGER);
    let twenty = vec!["parola"; 20].join(" ");
    assert!((ReadingPolicy::linger(&twenty) - 6.0).abs() < 0.001);
    let long = vec!["parola"; 400].join(" ");
    assert_eq!(ReadingPolicy::linger(&long), ReadingPolicy::MAXIMUM_LINGER);
}

/// Sotto soglia restano avvisi singoli.
#[test]
fn below_threshold_stays_individual() {
    let policy = NotificationPolicy { summary_threshold: 4 };
    assert_eq!(
        policy.decisions(SyncCause::Wake, &ids(&["a", "b", "c"])),
        vec![
            NotificationDecision::NewVox("a".into()),
            NotificationDecision::NewVox("b".into()),
            NotificationDecision::NewVox("c".into()),
        ]
    );
}

/// La baseline non notifica neanche sopra soglia.
#[test]
fn baseline_never_notifies() {
    let policy = NotificationPolicy { summary_threshold: 2 };
    assert!(policy.decisions(SyncCause::FirstLaunch, &ids(&["a", "b", "c"])).is_empty());
}

/// Le fonti restano fuori.
#[test]
fn vox_text_drops_sources() {
    let text = "⚡️ Notizia.\n\n🔻 Dettaglio.\n\nFonti: https://a.example/x · https://b.example/y";
    assert_eq!(VoxText::readable(text), "⚡️ Notizia.\n\n🔻 Dettaglio.");
}

/// Link markdown e URL nudi spariscono dal corpo.
#[test]
fn vox_text_cleans_links() {
    assert_eq!(VoxText::readable("Vedi [Reuters](https://reuters.com/x) oggi."), "Vedi Reuters oggi.");
    assert_eq!(VoxText::readable("Testo https://example.com/y fine."), "Testo  fine.");
    assert_eq!(VoxText::readable("A](https://x.example/z"), "A");
}

/// Un testo fatto solo di fonti non diventa vuoto.
#[test]
fn vox_text_never_empty() {
    assert!(!VoxText::readable("Fonti: https://x.example").is_empty());
}
