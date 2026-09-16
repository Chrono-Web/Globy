# Spike di sincronizzazione (GlobyCore)

- Aggiornato: 2026-09-17
- Stato: core Swift verificabile senza UI; l'app lo usa in Debug tramite fixture
- Risponde a: baseline, catch-up HTTP e hint SSE si comportano come richiesto dall'ADR 0002?

Non contiene mascotte né barra dei menu. Le fixture sono sintetiche: non copiano
contenuti reali di Chronocol.

## Uso

```bash
cd Packages/GlobyCore
swift test
```

Dalla radice del repository: `swift test --package-path Packages/GlobyCore`.
La suite non apre connessioni di rete.

## Che cosa prova

- Il primo avvio costruisce una baseline dal RSS e non notifica l'archivio.
- SSE è un hint: senza conferma HTTP non nasce un VOX e non parte una notifica.
- Catch-up da `lastSuccessfulSyncAt`: RSS se copre il buco, JSON paginato altrimenti.
- L'elenco JSON è richiesto con `sort=createdAt:desc`. L'ordine predefinito di
  Chronocol non è per recenza e non va usato per coprire un buco.
- Dedupe, retry con backoff, offline, payload incompatibile, 503 dello stream.
- Aggiornamento di un VOX già letto ≠ nuova pubblicazione.
- Ritiro solo con 404 sul dettaglio; un VOX uscito dal solo RSS resta disponibile.
- Una raffica diventa un riepilogo; più risvegli ravvicinati condividono una
  sola sincronizzazione in volo.

## Verificato

- `swift test` con Swift 6.3.3 su macOS 26 (arm64), 26 test, senza rete.
