# GLOBY — mappa del progetto per gli agenti

- Aggiornato: 2026-09-16
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

Non dedurre l'esistenza di codice dal piano: al 2026-09-16 il progetto Xcode non
esiste ancora e la repository contiene soltanto la fondazione documentale.

## Identità del progetto

Globy è un'applicazione macOS autonoma collegata ai contenuti pubblici di Chronocol.
La barra dei menu è la sua presenza stabile: un clic apre l'elenco delle VOX recenti.
La mascotte è un piccolo globo transitorio che compare nell'angolo inferiore destro
quando viene confermata una nuova VOX e poi scompare. Mascotte e sincronizzazione
devono restare indipendenti.

La fonte autorevole dello stato è una lettura HTTP di Chronocol. Lo stream SSE, se
usato, è soltanto un segnale che invita a sincronizzare: non è uno storico e non
garantisce il recupero degli eventi persi.

## Mappa dei documenti

| Documento | Fonte autorevole per |
|---|---|
| `docs/PRODOTTO.md` | Perimetro, persone, comportamenti e non-obiettivi |
| `docs/GLOSSARIO.md` | Vocabolario del prodotto e degli stati locali |
| `docs/ARCHITETTURA.md` | Componenti interni, dipendenze e flusso dati |
| `docs/CONTRATTO_API.md` | Endpoint Chronocol, garanzie e lacune |
| `docs/SVILUPPO.md` | Bootstrap locale, fixture, test e comandi verificati |
| `docs/PRIVACY.md` | Dati trattati, conservazione e telemetria |
| `docs/DISTRIBUZIONE.md` | Build, firma, notarizzazione e aggiornamenti |
| `docs/ASSET.md` | Provenienza, licenza e uso di grafica, font e suoni |
| `docs/TRAPPOLE.md` | Errori ricorrenti e assunzioni vietate |
| `docs/ROADMAP.md` | Stato reale e criteri di completamento |
| `docs/adr/` | Perché una decisione interna è stata presa |

Un fatto deve avere una casa sola. Gli altri documenti lo collegano, non lo copiano.

## Regole non negoziabili

1. **Niente eventi inventati.** La mascotte compare soltanto dopo che la sincronizzazione
   autorevole ha confermato una nuova VOX; un pacchetto SSE non basta.
2. **HTTP è autorevole, SSE è un indizio.** Ogni riconnessione, risveglio o evento SSE
   termina in una sincronizzazione idempotente.
3. **`documentId` identifica il contenuto, non la sua versione.** Letto, notificato,
   aggiornato e ritirato sono stati diversi.
4. **Il primo avvio non notifica l'archivio.** Costruisce una baseline e informa la
   persona soltanto degli arrivi successivi.
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

## Vincoli di implementazione proposti

Finché gli ADR corrispondenti sono `proposto`, trattali come direzione da validare e
non come decisione irreversibile:

- Swift e SwiftUI per l'app macOS;
- AppKit soltanto dove SwiftUI non esprime il comportamento della finestra-mascotte;
- RealityKit o una soluzione 2D da confrontare con uno spike misurato;
- persistenza locale dietro un protocollo, senza accoppiare le viste al database;
- client di rete dietro un protocollo e verificabile con fixture locali.

Non introdurre SceneKit in un progetto nuovo senza un ADR che giustifichi la scelta.

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

Quando esisterà il progetto Xcode, non modificare a mano file generati da strumenti o
build. Non versionare DerivedData, `.xcuserstate`, profili, certificati, chiavi,
token, configurazioni personali o database reali.
