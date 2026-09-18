# GLOBY — mappa del progetto per gli agenti

- Aggiornato: 2026-09-17
- Vale per: tutta la repository `GLOBY/`
- Ruolo: punto d'ingresso autorevole. Se un documento interno lo contraddice, vince
  questo file finché la contraddizione non viene corretta.

## Prima di lavorare

Leggi, nell'ordine:

1. questo file per intero;
2. `docs/PRODOTTO.md`;
3. `docs/GLOSSARIO.md`;
4. `docs/ARCHITETTURA.md`;
5. `docs/TRAPPOLE.md`;
6. il documento specifico dell'area che stai modificando;
7. gli ADR pertinenti in `docs/adr/`.

Non trattare gli spike come se fossero l'app: `Packages/GlobyCore/` e
`Spikes/MascotSpike/` restano libreria e prototipo. L'app Mac è `Globy.xcodeproj`;
Windows e Linux sono l'app Tauri in `desktop/` (ADR 0005).

## Identità del progetto

Globy è il compagno ufficiale macOS di Chronocol, un'applicazione autonoma collegata
ai contenuti pubblici. La barra dei menu è la sua presenza stabile: un clic apre
l'elenco dei VOX recenti. La mascotte è un piccolo globo transitorio che compare
nell'angolo inferiore destro quando viene confermato un nuovo VOX e poi scompare.
Mascotte e sincronizzazione devono restare indipendenti.

La fonte autorevole dello stato è una lettura HTTP di Chronocol: RSS se copre il buco
da `lastSuccessfulSyncAt`, elenco JSON altrimenti. Lo stream SSE, se usato, è soltanto
un segnale che invita a sincronizzare: non è uno storico e non garantisce il recupero
degli eventi persi.

## Mappa dei documenti

| Documento | Fonte autorevole per |
|---|---|
| `docs/GUIDA.md` | Presentazione del progetto, stato e indice dei documenti (il README è solo per scaricare) |
| `docs/PRODOTTO.md` | Perimetro, persone, comportamenti e non-obiettivi |
| `docs/GLOSSARIO.md` | Vocabolario del prodotto e degli stati locali |
| `docs/ARCHITETTURA.md` | Componenti interni, dipendenze e flusso dati |
| `docs/CONTRATTO_API.md` | Endpoint Chronocol, garanzie e lacune |
| `docs/SVILUPPO.md` | Bootstrap locale, fixture, test e comandi verificati |
| `docs/PRIVACY.md` | Dati trattati, conservazione e telemetria |
| `docs/DISTRIBUZIONE.md` | Come si pubblica una release |
| `docs/ASSET.md` | Provenienza, licenza e uso di grafica, font e suoni |
| `docs/TRAPPOLE.md` | Errori ricorrenti e assunzioni vietate |
| `docs/ROADMAP.md` | Stato reale e criteri di completamento |
| `docs/COLLAUDO_FASE3.md` | Checklist del collaudo umano che chiude la fase 3 |
| `docs/COLLAUDO_DESKTOP.md` | Checklist del collaudo umano su Windows e Linux |
| `docs/SEGNALARE.md` | Come chi usa Globy segnala un problema |
| `docs/adr/` | Perché una decisione interna è stata presa |

Un fatto deve avere una casa sola. Gli altri documenti lo collegano, non lo copiano.

## Regole non negoziabili

1. **Niente eventi inventati.** La mascotte compare dopo la conferma autorevole di
   un nuovo VOX; un pacchetto SSE non basta. Eccezioni: il saluto di primo
   avvio, il saluto di rientro e l'avviso di una nuova versione di Globy, che non sono VOX (casa: `docs/PRODOTTO.md`).
   **VOX è maschile**: il VOX, un nuovo VOX, i VOX non letti.
2. **HTTP è autorevole, SSE è un indizio.** Ogni riconnessione, risveglio o evento SSE
   termina in una sincronizzazione idempotente. Il dettaglio è l'ADR 0002.
3. **`documentId` identifica il contenuto, non la sua versione.** Letto, notificato,
   aggiornato e ritirato sono stati diversi.
4. **Il primo avvio non notifica l'archivio.** Costruisce una baseline e informa la
   persona soltanto degli arrivi successivi. Può soltanto *chiedere* se mostrare gli
   ultimi 5 VOX come «recenti», senza banner né `notifiedAt` (casa: `docs/PRODOTTO.md`).
5. **Mai test distruttivi sulla produzione.** Pubblicazioni, ritiri e raffiche si
   provano con fixture o staging.
6. **Nessun segreto nel bundle o nella repository.** Le letture pubbliche non devono
   richiedere credenziali; eventuali segreti futuri vanno nel Portachiavi.
7. **Nessuna telemetria implicita.** Una futura raccolta dati richiede una decisione
   esplicita, documentazione e consenso adeguato.
8. **Accessibilità e consumo sono requisiti.** La mascotte rispetta Reduce Motion e
   non mantiene un render loop costoso quando è ferma o nascosta.
9. **Documentazione in italiano.** Nomi Apple e identificatori del codice restano nella
   loro forma ufficiale.
10. **Non anticipare l'admin.** Account e funzioni editoriali appartengono a una fase e
    a un contratto di sicurezza separati.

## Vincoli di implementazione

Accettati (ADR 0001, 0002, 0003 e 0004):

- Swift e SwiftUI per l'app macOS;
- AppKit soltanto dove SwiftUI non esprime il comportamento della finestra-mascotte;
- catch-up HTTP con RSS se copre il buco, JSON altrimenti; SSE solo come segnale;
- mascotte disegnata in 2D (Canvas), non RealityKit;
- persistenza dei contenuti in un file JSON dietro `ContentStore` (ADR 0004).

Non introdurre SceneKit o RealityKit in un progetto nuovo senza un ADR che
giustifichi la scelta.

## Qualità e verifica

Una modifica è completa soltanto quando:

- compila con il toolchain documentato in `docs/SVILUPPO.md`;
- i test pertinenti passano;
- non richiede produzione o credenziali per i test automatici;
- aggiorna documenti e ADR se cambia un contratto o una decisione;
- aggiorna `docs/ROADMAP.md` soltanto sulla base di una verifica reale.

Le tre caselle hanno significato preciso:

- `[ ]` non iniziato;
- `[~]` costruito ma non ancora verificato nel contesto dichiarato;
- `[x]` verificato con il criterio scritto.

## ADR

Le decisioni interne a Globy vivono in `docs/adr/`. Una decisione che cambia anche il
contratto o il funzionamento di Chronocol deve invece avere un ADR nel progetto
Chronocol e Globy deve collegarlo senza duplicarlo.

Ogni ADR contiene: stato, data, proprietario, ambito, contesto, decisione, verifica,
conseguenze e condizioni di riesame. Gli ADR accettati non si riscrivono per cambiare
il passato: vengono sostituiti da un nuovo ADR.

## File generati e segreti

Quando esiste il progetto Xcode, non modificare a mano file generati da strumenti o
build. Il `project.pbxproj` è mantenuto a mano (cartelle sincronizzate sul filesystem).
Non versionare DerivedData, `.xcuserstate`, profili, certificati, chiavi,
token, configurazioni personali o database reali.
