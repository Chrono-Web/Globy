# 0004 — Lo store locale è un file JSON dietro protocollo

- Stato: accettato
- Data: 2026-09-16
- Accettato: 2026-09-16
- Proprietario: progetto Globy
- Vincolante per: persistenza dei contenuti, test, azzeramento dati
- Nasce da: MVP macOS (fase 3); macOS 15 già copre SwiftData, ma le viste non devono
  dipendere da un database
- Sostituisce: nulla

## Contesto

Globy deve ricordare VOX osservati, `readAt`, `notifiedAt` e `lastSuccessfulSyncAt`
tra un avvio e l'altro. Lo spike usava solo memoria. SwiftData e Core Data restano
candidati, ma accoppiano facilmente le viste allo schema e complicano i test.

Il volume della prima versione è l'elenco recente, non l'archivio Chronocol.

## Decisione

I contenuti vivono in un file JSON in Application Support, dietro `ContentStore`.
`InMemoryContentStore` resta per i test. `UserDefaults` solo per preferenze piccole
(mascotte, permanenza, pausa notifiche, avvio al login). Il Portachiavi non serve.

## Come si verifica

- un avvio successivo rilegge baseline, letto e notificato;
- «Azzera dati locali» cancella file e preferenze;
- la suite `FileContentStoreTests` passa senza rete.

## Conseguenze

- persistenza semplice da azzerare e da escludere dal bundle;
- niente migrazioni SwiftData nella prima versione;
- se l'elenco cresce oltre il ragionevole, si rivede con un ADR nuovo.

## Quando riesaminare

1. Serve una query più ricca dell'elenco recente.
2. SwiftData (o altro) dimostra testabilità pari senza accoppiare le viste.
3. Il file JSON si corrompe in casi reali e serve un formato transazionale.
