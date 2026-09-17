# 0005 — Globy su Windows e Linux è un'app Tauri accanto all'app Mac

- Stato: accettato
- Data: 2026-09-17
- Accettato: 2026-09-17
- Proprietario: progetto Globy
- Vincolante per: `desktop/`, distribuzione, README
- Nasce da: persone reali su Windows e Linux che vogliono usare Globy
- Sostituisce: nulla. Estende l'ADR 0001, che per il Mac resta valido

## Contesto

Globy esiste solo per macOS (ADR 0001): SwiftUI e AppKit non girano altrove. Ci sono
persone su Windows e Linux che vogliono i VOX sul proprio computer. Il Mac non deve
perdere nulla di quanto costruito: Liquid Glass, consumi bassi, integrazione nativa.

Fatti verificati il 2026-09-17:

- `GlobyCore` è quasi tutto Foundation e si riscrive in Rust in poco tempo; i suoi 39
  test descrivono le regole con precisione;
- su Linux con Wayland un'app non può mettersi sempre in primo piano, scegliere la
  propria posizione né leggere il puntatore fuori dalla propria finestra;
- su Linux le icone di sistema (AppIndicator) mandano solo il menu, non i clic.

## Decisione

L'app Mac resta in Swift. Windows e Linux hanno una seconda app in `desktop/`, nello
stesso repository:

- **Tauri 2**: nucleo in Rust, interfaccia e globo in TypeScript e Canvas 2D;
- **`desktop/globy-core`**: porting di `GlobyCore` senza dipendenze grafiche; i suoi
  test leggono le fixture del pacchetto Swift, così i due nuclei restano allineati;
- **globo ridotto con Wayland**: finestra posizionata dal sistema, occhi che non
  seguono il puntatore;
- **vetro Acrylic su Windows** dove disponibile, superficie scura altrove;
- **binari non firmati**: l'avviso di SmartScreen si supera come «Apri comunque» sul Mac;
- **una sola versione** per i tre sistemi e una sola Release GitHub.

Escluse: un'unica app per tutti (Mac peggiore, Electron più pesante), Swift su Windows
e Linux (nessuna interfaccia matura), repository separato (documenti e Release doppi).

## Come si verifica

- `cargo test -p globy-core` passa con le fixture Swift, come `swift test`;
- la CI crea installer Windows (NSIS) e Linux (AppImage e `.deb`);
- il collaudo di `docs/COLLAUDO_DESKTOP.md` passa su Windows 11 e su Linux con X11 e
  con Wayland.

## Conseguenze

- due interfacce da tenere allineate: una modifica di comportamento tocca Swift e
  TypeScript, e una regola di sincronizzazione `GlobyCore` e `globy-core`;
- chi sviluppa non vede Windows e Linux dal Mac: servono persone che collaudano;
- la release pubblica anche gli installer della CI accanto al DMG manuale.

## Quando riesaminare

1. Mantenere due interfacce diventa più costoso di un'app unica.
2. Wayland offre un protocollo standard per finestre sempre in primo piano.
3. Serve la firma su Windows (per esempio perché SmartScreen blocca del tutto).
