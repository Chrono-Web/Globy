# Globy

> **Stato: pre-alpha.** Le fasi 0–3 sono chiuse. La Release legge Chronocol pubblico
> con sole GET ed è stata collaudata a mano; arrivi reali, rientro e rete sono la
> fase 4. Non c'è ancora una build firmata da distribuire.

Globy è il compagno ufficiale macOS di [Chronocol](https://chronocol.com): vive nella
barra dei menu e raccoglie i VOX più recenti. Quando arriva un nuovo VOX confermato,
un piccolo globo compare brevemente nell'angolo inferiore destro dello schermo e poi
scompare.

## Obiettivo della prima versione

- consultare i VOX più recenti dalla barra dei menu;
- ricevere notifiche locali mentre Globy è in esecuzione;
- recuperare i VOX usciti da quando Globy ha sincronizzato l'ultima volta;
- distinguere contenuti non letti e contenuti già notificati;
- aprire il VOX originale su Chronocol;
- mostrare brevemente la mascotte in basso a destra soltanto per nuovi VOX confermati.

Globy non include nella prima versione funzioni editoriali, account, chat, telemetria
o notifiche remote ad applicazione terminata.

## Stato del lavoro

La fondazione (fase 0), lo spike di sincronizzazione (fase 1) e lo spike della
mascotte (fase 2) sono verificati. Gli ADR 0001, 0002, 0003 e 0004 sono **accettati**.
L'app è `Globy.xcodeproj` (fase 3 chiusa): menu, store JSON, onboarding raccontato da
Globy, saluto di rientro, controllo periodico, Impostazioni e modalità notifiche di sistema. `Packages/GlobyCore/` e `Spikes/MascotSpike/`
non sono il prodotto.

Requisiti di piattaforma e canale: macOS 15 o successivo, identificatore
`com.chronocol.globy`, GitHub fuori dallo Store. Dettaglio in
[`docs/SVILUPPO.md`](docs/SVILUPPO.md) e [`docs/DISTRIBUZIONE.md`](docs/DISTRIBUZIONE.md).

```bash
swift test --package-path Packages/GlobyCore
xcodebuild -project Globy.xcodeproj -scheme Globy -destination 'platform=macOS' build
```

La roadmap è in [`docs/ROADMAP.md`](docs/ROADMAP.md). Il brief è in
[`docs/PRODOTTO.md`](docs/PRODOTTO.md).

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
| [`docs/DISTRIBUZIONE.md`](docs/DISTRIBUZIONE.md) | Come si pubblica una release |
| [`docs/ASSET.md`](docs/ASSET.md) | Provenienza e licenze degli asset |
| [`docs/TRAPPOLE.md`](docs/TRAPPOLE.md) | Assunzioni apparentemente vere che possono rompere Globy |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Fasi, gate e stato reale |
| [`docs/adr/`](docs/adr/) | Perché una decisione interna è stata presa |

## Contribuire e sicurezza

Vedi [`CONTRIBUTING.md`](CONTRIBUTING.md) e [`SECURITY.md`](SECURITY.md). I contributi
esterni di codice per ora sono chiusi: il progetto è piccolo e non servono. Non c'è
un indirizzo di sicurezza dedicato.

## Licenza

GNU GPL versione 3. Vedi [`LICENSE`](LICENSE).
