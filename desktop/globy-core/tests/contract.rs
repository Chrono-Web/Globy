//! `ContractDecodingTests` e `FileContentStoreTests` del pacchetto Swift.

mod support;

use chrono::DateTime;
use globy_core::*;
use std::sync::Mutex;
use support::*;

/// Il decoder legge solo il sottoinsieme utile e ignora i campi extra.
#[tokio::test]
async fn decoder_ignores_unknown_fields() {
    let client = ChronocolClient::new(test_configuration(25, 10), StubTransport(|_| ok(fixture("list-page.json"))));
    let page = client.fetch_list_page(1).await.unwrap();
    assert_eq!(page.items.len(), 1);
    assert_eq!(page.items[0].document_id, "fixture-vox-1");
    assert_eq!(page.items[0].list_text, "Testo sintetico del primo VOX di fixture.");
    assert_eq!(page.page_count, 3);
    assert_eq!(page.items[0].permalink, "https://chronocol.test/it/vox/fixture-vox-1");
}

/// L'elenco JSON chiede sempre sort=createdAt:desc.
#[tokio::test]
async fn list_request_uses_recency_sort() {
    let requested = Mutex::new(None);
    let client = ChronocolClient::new(
        test_configuration(2, 10),
        StubTransport(|url| {
            *requested.lock().unwrap() = Some(url.clone());
            ok(fixture("list-page.json"))
        }),
    );
    client.fetch_list_page(2).await.unwrap();
    let url = requested.lock().unwrap().clone().unwrap();
    let pairs: Vec<(String, String)> = url.query_pairs().map(|(k, v)| (k.into(), v.into())).collect();
    assert!(pairs.contains(&("sort".into(), "createdAt:desc".into())));
    assert!(pairs.contains(&("pagination[page]".into(), "2".into())));
    assert!(pairs.contains(&("pagination[pageSize]".into(), "2".into())));
}

/// Un RSS di fixture produce documentId dal permalink.
#[tokio::test]
async fn rss_fixture_parses_document_ids() {
    let client = ChronocolClient::new(test_configuration(2, 10), StubTransport(|_| ok(fixture("rss.xml"))));
    let items = client.fetch_rss().await.unwrap();
    let found: Vec<&str> = items.iter().map(|i| i.document_id.as_str()).collect();
    assert_eq!(found, ["fixture-new", "fixture-old"]);
    assert!(items[0].list_text.contains("recente"));
}

/// Un 404 sul dettaglio è un ritiro osservabile, non un payload incompatibile.
#[tokio::test]
async fn detail_404_is_withdrawal() {
    let client = ChronocolClient::new(
        test_configuration(2, 10),
        StubTransport(|_| HttpResponse { status: 404, body: br#"{"data":null}"#.to_vec() }),
    );
    assert_eq!(client.fetch_detail("missing").await.unwrap(), None);
}

/// Un JSON senza documentId è incompatibile.
#[tokio::test]
async fn missing_document_id_is_incompatible() {
    let body = r#"{"data":[{"NOTIZIA":"x","createdAt":"2026-09-16T10:00:00.000Z","updatedAt":"2026-09-16T10:00:00.000Z"}],"meta":{"pagination":{"page":1,"pageSize":1,"pageCount":1,"total":1}}}"#;
    let client = ChronocolClient::new(test_configuration(2, 10), StubTransport(|_| ok(body)));
    assert!(matches!(client.fetch_list_page(1).await, Err(ClientError::IncompatiblePayload(_))));
}

/// Gli eventi SSE duplicati restano hint e non VOX.
#[test]
fn sse_fixture_is_only_a_hint() {
    let text = String::from_utf8(fixture("sse-vox-new.txt")).unwrap();
    let events = SseParser::parse(&text);
    assert_eq!(events.first(), Some(&HintEvent::Connected));
    assert_eq!(events.iter().filter(|e| matches!(e, HintEvent::VoxNew { .. })).count(), 2);
    assert_eq!(SseParser::hint(&events[1]), Some(SyncHint::VoxNew("fixture-new".into())));
}

/// Lo store su file sopravvive a un nuovo avvio e reset cancella il file.
#[test]
fn file_store_round_trip_and_reset() {
    let folder = tempfile::tempdir().unwrap();
    let path = folder.path().join("store.json");
    let date = |s| DateTime::from_timestamp(s, 0).unwrap();

    let first = FileContentStore::new(&path);
    let record = VoxRecord {
        document_id: "a".into(),
        permalink: "https://chronocol.test/it/vox/a".into(),
        list_text: "ciao".into(),
        created_at: date(100),
        updated_at: date(100),
        fingerprint: "fp".into(),
        first_observed_at: date(200),
        last_observed_at: date(200),
        read_at: None,
        notified_at: Some(date(200)),
        is_available: true,
    };
    first.apply(StoreTransaction {
        upserts: vec![record],
        last_successful_sync_at: Some(date(200)),
        has_completed_baseline: Some(true),
        ..Default::default()
    });

    let second = FileContentStore::new(&path);
    let snapshot = second.snapshot();
    assert!(snapshot.has_completed_baseline);
    assert_eq!(snapshot.records["a"].list_text, "ciao");
    assert!(snapshot.records["a"].notified_at.is_some());

    second.reset();
    let empty = FileContentStore::new(&path).snapshot();
    assert!(empty.records.is_empty());
    assert!(!empty.has_completed_baseline);
}
