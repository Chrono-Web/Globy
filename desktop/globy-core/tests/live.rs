//! Contro Chronocol pubblico: escluso di default perché usa la rete.
//! `cargo test -p globy-core --test live -- --ignored`

use globy_core::*;

#[tokio::test(flavor = "multi_thread")]
#[ignore = "usa la rete"]
async fn production_rss_and_list_decode() {
    let client = ChronocolClient::new(ChronocolConfiguration::production(), ReqwestTransport::new());
    let rss = client.fetch_rss().await.expect("RSS");
    assert!(!rss.is_empty());
    let page = client.fetch_list_page(1).await.expect("elenco JSON");
    assert!(!page.items.is_empty());
    // Con sort=createdAt:desc la pagina 1 contiene VOX recenti quanto il RSS.
    assert_eq!(page.items[0].document_id, rss[0].document_id);
    let detail = client.fetch_detail(&rss[0].document_id).await.expect("dettaglio");
    assert_eq!(detail.map(|d| d.document_id), Some(rss[0].document_id.clone()));
    println!("{} nel RSS, ultimo: {}", rss.len(), VoxText::readable(&rss[0].list_text));
}
