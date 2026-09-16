# Distribuzione

- Aggiornato: 2026-09-16
- Stato: strategia da scegliere
- Risponde a: come una build diventa una release installabile e aggiornabile

## Decisione aperta

I due percorsi candidati sono:

1. Developer ID, notarizzazione e aggiornamenti firmati fuori dal Mac App Store;
2. Mac App Store con i relativi requisiti di sandbox e revisione.

Non produrre una pipeline definitiva finché il canale non è scelto. Firma e
notarizzazione non costituiscono da sole un sistema di aggiornamento.

## Requisiti comuni

- bundle identifier stabile;
- versione minima di macOS dichiarata;
- numero di versione e build riproducibili;
- asset con provenienza e licenza registrate;
- privacy e permessi coerenti con il comportamento reale;
- release notes;
- test su un Mac o utente pulito;
- possibilità di compilare senza credenziali di distribuzione.

## Developer ID

Se scelto, vanno progettati:

- archivio Xcode firmato;
- notarizzazione e stapling;
- pacchetto `.dmg` o `.zip` verificato;
- feed di aggiornamento firmato, per esempio tramite un framework valutato con ADR;
- separazione tra certificati di CI e repository;
- procedura di revoca, rollback e rilascio urgente.

## Mac App Store

Se scelto, lo spike deve verificare presto:

- App Sandbox e client di rete;
- login item;
- comportamento della finestra-mascotte;
- aggiornamenti gestiti dallo Store;
- regole applicabili a contenuti e collegamenti esterni.

## Canali

La proposta iniziale distingue:

- **Debug locale:** fixture o staging;
- **Beta:** gruppo limitato, diagnostica manuale e contratto ancora evolvibile;
- **Stable:** contratto compatibile, update funzionante e criteri della roadmap `[x]`.

Una beta non deve usare automaticamente la produzione per operazioni che modificano
contenuti. Le sole letture pubbliche possono essere collaudate contro produzione con
frequenza rispettosa dei limiti.

## Gate di release

- build e test automatici riusciti;
- firma verificata;
- notarizzazione verificata se applicabile;
- aggiornamento dalla release precedente provato;
- avvio su installazione pulita provato;
- notifiche consentite e negate provate;
- login item abilitato e disabilitato provato;
- consumo a riposo entro le soglie ancora da fissare;
- licenza del codice scelta;
- licenze di tutti gli asset registrate;
- `CHANGELOG.md`, privacy e documentazione aggiornati.

## Credenziali

Certificati, password, profili e token non entrano nella repository. La CI riceve solo
i privilegi necessari e la compilazione non firmata resta disponibile ai contributori.
