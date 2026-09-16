# Globy

> **Stato: pre-alpha, documentazione di progetto.** Non esiste ancora una build
> installabile. Questa repository contiene il perimetro e le decisioni da verificare
> prima del prototipo.

Globy è il compagno macOS di [Chronocol](https://chronocol.com): vive nella barra dei
menu e raccoglie le VOX più recenti. Quando arriva una nuova VOX confermata, un piccolo
globo compare brevemente nell'angolo inferiore destro dello schermo e poi scompare.

Oggi sono presenti soltanto documentazione, roadmap e ADR. Non sono presenti progetto
Xcode, codice applicativo, asset grafici, binari o release. Gli esempi di architettura
descrivono una direzione da verificare, non funzionalità già disponibili.

## Obiettivo della prima versione

- consultare le VOX più recenti dalla barra dei menu;
- ricevere notifiche locali mentre Globy è in esecuzione;
- recuperare gli aggiornamenti persi dopo rete assente, stop o riavvio;
- distinguere contenuti non letti e contenuti già notificati;
- aprire la VOX originale su Chronocol;
- mostrare brevemente la mascotte in basso a destra soltanto per nuove VOX confermate.

Globy non include nella prima versione funzioni editoriali, account, chat, telemetria
o notifiche remote ad applicazione terminata.

## Stato del lavoro

L'implementazione non è iniziata. Le decisioni negli ADR sono **proposte**, non
accettate, e possono cambiare dopo gli spike tecnici.

La roadmap verificabile è in [`docs/ROADMAP.md`](docs/ROADMAP.md). Il brief completo è
in [`docs/PRODOTTO.md`](docs/PRODOTTO.md).

## Documentazione

| Documento | Risponde a |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Come orientarsi e lavorare nella repository |
| [`docs/PRODOTTO.md`](docs/PRODOTTO.md) | Che cosa è Globy e che cosa non è |
| [`docs/GLOSSARIO.md`](docs/GLOSSARIO.md) | Significato dei termini del prodotto |
| [`docs/ARCHITETTURA.md`](docs/ARCHITETTURA.md) | Come separare sincronizzazione, stato e interfaccia |
| [`docs/CONTRATTO_API.md`](docs/CONTRATTO_API.md) | Come Globy può leggere Chronocol oggi e quali garanzie mancano |
| [`docs/SVILUPPO.md`](docs/SVILUPPO.md) | Come predisporre e verificare lo sviluppo locale |
| [`docs/PRIVACY.md`](docs/PRIVACY.md) | Dati locali, rete e telemetria |
| [`docs/DISTRIBUZIONE.md`](docs/DISTRIBUZIONE.md) | Firma, aggiornamenti e release |
| [`docs/ASSET.md`](docs/ASSET.md) | Provenienza e licenze degli asset |
| [`docs/TRAPPOLE.md`](docs/TRAPPOLE.md) | Assunzioni apparentemente vere che possono rompere Globy |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Fasi, gate e stato reale |
| [`docs/adr/`](docs/adr/) | Decisioni architetturali interne a Globy |

## Requisiti

Prima di creare il progetto Xcode vanno decisi:

- versione minima di macOS;
- bundle identifier e Apple Development Team;
- canale di distribuzione;
- licenza del codice e licenze degli asset.

## Contribuire e sicurezza

Vedi [`CONTRIBUTING.md`](CONTRIBUTING.md) e [`SECURITY.md`](SECURITY.md). Il progetto
non accetta contributi di codice. Non c'è un indirizzo di sicurezza dedicato.

## Licenza

Non è stata scelta. In assenza di un file `LICENSE`, i contenuti si possono
consultare ma non sono concessi per copia, modifica o redistribuzione.
