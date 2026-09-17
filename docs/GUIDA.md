# Guida alla documentazione

- Aggiornato: 2026-09-17
- Risponde a: che cosa è Globy, a che punto è e dove trovare ogni documento

Per scaricare e installare Globy basta il [README](../README.md) (il pulsante scarica
`Globy.dmg` dall'ultima Release GitHub). Questa guida è per chi vuole capire il
progetto o lavorarci.

> **Stato: pre-alpha, versione 0.1.0.** Le fasi 0–3 sono chiuse. L'app legge Chronocol
> pubblico con sole GET ed è stata collaudata a mano; arrivi reali, rientro e rete sono
> la fase 4. Il DMG non è firmato né notarizzato.

Globy è il compagno ufficiale macOS di [Chronocol](https://chronocol.com): vive nella
barra dei menu e raccoglie i VOX più recenti. Quando arriva un nuovo VOX confermato,
un piccolo globo compare brevemente nell'angolo inferiore destro dello schermo e poi
scompare.

## Che cosa fa la 0.1.0

- mostra nella barra dei menu gli ultimi VOX, con in evidenza quelli nuovi non letti;
- controlla Chronocol all'avvio, al risveglio e circa ogni 5 minuti, senza notificare
  l'archivio al primo avvio;
- quando esce un nuovo VOX, Globy compare in basso a destra e lo legge; in alternativa,
  la modalità «Notifiche di sistema» usa le notifiche del Mac;
- al primo avvio si presenta, spiega menu e Impostazioni e propone gli ultimi 5 VOX;
- apre ogni VOX sul sito di Chronocol.

Fuori perimetro per ora: funzioni editoriali, account, chat, telemetria e notifiche
remote ad applicazione chiusa.

## Stato del lavoro

Gli ADR 0001, 0002, 0003 e 0004 sono **accettati**. L'app è `Globy.xcodeproj`;
`Packages/GlobyCore/` contiene sincronizzazione e politiche testate senza rete;
`Spikes/MascotSpike/` è un prototipo e non è il prodotto. Ogni push su `main` esegue
build e test in GitHub Actions.

Requisiti: macOS 15 o successivo (il vetro Liquid Glass richiede macOS 26),
identificatore `com.chronocol.globy`, distribuzione su GitHub fuori dallo Store.
Dettaglio in [`docs/SVILUPPO.md`](SVILUPPO.md) e
[`docs/DISTRIBUZIONE.md`](DISTRIBUZIONE.md).

```bash
swift test --package-path Packages/GlobyCore
xcodebuild -project Globy.xcodeproj -scheme Globy -destination 'platform=macOS' build
```

La roadmap è in [`docs/ROADMAP.md`](ROADMAP.md). Il brief è in
[`docs/PRODOTTO.md`](PRODOTTO.md).

## Documenti

| Documento | Risponde a |
|---|---|
| [`AGENTS.md`](../AGENTS.md) | Come orientarsi e lavorare nella repository |
| [`docs/PRODOTTO.md`](PRODOTTO.md) | Che cosa è Globy e che cosa non è |
| [`docs/GLOSSARIO.md`](GLOSSARIO.md) | Significato dei termini del prodotto |
| [`docs/ARCHITETTURA.md`](ARCHITETTURA.md) | Come separare sincronizzazione, stato e interfaccia |
| [`docs/CONTRATTO_API.md`](CONTRATTO_API.md) | Come Globy può leggere Chronocol oggi e quali garanzie mancano |
| [`docs/SVILUPPO.md`](SVILUPPO.md) | Come predisporre e verificare lo sviluppo locale |
| [`docs/PRIVACY.md`](PRIVACY.md) | Dati locali, rete e telemetria |
| [`docs/DISTRIBUZIONE.md`](DISTRIBUZIONE.md) | Come si pubblica una release |
| [`docs/ASSET.md`](ASSET.md) | Provenienza e licenze degli asset |
| [`docs/TRAPPOLE.md`](TRAPPOLE.md) | Assunzioni apparentemente vere che possono rompere Globy |
| [`docs/ROADMAP.md`](ROADMAP.md) | Fasi, gate e stato reale |
| [`docs/COLLAUDO_FASE3.md`](COLLAUDO_FASE3.md) | Collaudo umano della fase 3 ed esito |
| [`CHANGELOG.md`](../CHANGELOG.md) | Che cosa è cambiato in ogni versione |
| [`docs/adr/`](adr/) | Perché una decisione interna è stata presa |

## Contribuire e sicurezza

Vedi [`CONTRIBUTING.md`](../CONTRIBUTING.md) e [`SECURITY.md`](../SECURITY.md). I contributi
esterni di codice per ora sono chiusi: il progetto è piccolo e non servono. Non c'è
un indirizzo di sicurezza dedicato.

## Licenza

GNU GPL versione 3. Vedi [`LICENSE`](../LICENSE).
