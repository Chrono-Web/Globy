# Asset e attribuzioni

- Aggiornato: 2026-09-17
- Stato: icona dell'app e sfondo del DMG, originali e generati dal codice
- Risponde a: da dove provengono grafica, font, suoni e modelli e come possono essere usati

## Regola

Ogni asset non creato interamente per Globy deve essere registrato qui prima di entrare
in una build distribuibile. Una URL di download non è una licenza.

Codice e asset originali di Globy sono GNU GPL versione 3, come `LICENSE`. Un asset di
terzi entra solo con una licenza compatibile e riga in questa tabella.

## Stato attuale

Nessun asset di terzi: niente font, suoni, modelli o immagini esterne. Il globo (spike e
app) è disegnato dal codice.

| File | Autore | Fonte | Licenza | Note |
|---|---|---|---|---|
| `Globy/Assets.xcassets/AppIcon.appiconset/*.png` | progetto Globy | `AppIconArt` in `Globy/Mascot/MascotView.swift`, `Globy --render-icon` (Debug) poi `sips` | GPL-3.0 | Vetro trasparente imitato su sfondo grigio molto scuro: il vetro di sistema non passa in un'immagine |
| sfondo del DMG (generato a ogni build) | progetto Globy | `scripts/dmg/sfondo.swift` | GPL-3.0 | Font di sistema, non incluso nel file |
| `desktop/src-tauri/icons/*` | progetto Globy | icona del Mac `icon_512x512@2x.png` convertita con `npx tauri icon` | GPL-3.0 | Stessa immagine dell'app Mac |
| icona nell'area di notifica (Windows e Linux) | progetto Globy | `desktop/src-tauri/src/tray_icon.rs`, disegnata all'avvio | GPL-3.0 | Nessun file |
| suono di arrivo (Windows e Linux) | progetto Globy | `desktop/src/mascot/sound.ts`, sintetizzato | GPL-3.0 | Nessun file audio |

## Chronocol

Globy è il compagno ufficiale macOS di Chronocol. Può usare nome e identità Chronocol
in interfaccia, README e sito per presentarsi come tale e per aprire i permalink
pubblici. Non è una licenza sul codice di Chronocol e non autorizza a copiare il sito.

## Categorie da controllare

- modello o mesh del globo;
- texture della Terra e dati cartografici;
- occhi, espressioni e animazioni;
- icona dell'app e della barra dei menu;
- font non di sistema;
- suoni;
- immagini usate in README, sito o release;
- marchi, nome e identità visiva Chronocol.

Gli asset generati con strumenti AI richiedono comunque provenienza, condizioni d'uso
del servizio e verifica di eventuali somiglianze o marchi. Devono poter essere
rilasciati sotto GPL-3 insieme al resto, altrimenti non entrano.

## Prima della release

- [ ] Ogni file in bundle compare nel registro o è chiaramente prodotto dal codice.
- [ ] Le attribuzioni richieste sono incluse nell'app o nel pacchetto.
- [ ] L'uso del marchio Chronocol resta quello dichiarato sopra.
- [ ] I file sorgente necessari a modificare gli asset sono archiviati dove previsto.
- [ ] Non esistono placeholder o asset di test nella build stabile.
