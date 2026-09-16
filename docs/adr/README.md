# Decisioni architetturali

Gli ADR registrano decisioni interne a Globy che sarebbe costoso o ambiguo riscoprire.
Una decisione che vincola anche Chronocol appartiene agli ADR di Chronocol; qui se ne
mantiene soltanto il collegamento.

## Stati

- `proposto`: direzione da discutere o verificare;
- `accettato`: decisione attiva;
- `sostituito`: rimpiazzato da un ADR successivo;
- `ritirato`: non più applicabile senza sostituzione.

## Indice

| ADR | Stato | Decisione |
|---|---|---|
| [0001](0001-globy-e-una-utility-macos-con-mascotte-facoltativa.md) | accettato | Globy è una utility macOS con mascotte facoltativa |
| [0002](0002-http-e-autorevole-sse-e-un-segnale.md) | accettato | HTTP è autorevole e SSE è un segnale |
| [0003](0003-la-mascotte-e-un-globo-2d.md) | accettato | La mascotte è un globo 2D, non RealityKit |
| [0004](0004-store-locale-file-json.md) | accettato | Lo store locale è un file JSON dietro protocollo |

Usa [`0000-template.md`](0000-template.md) per una nuova decisione. Il numero viene
assegnato una sola volta e gli ADR accettati non vengono rinumerati.
