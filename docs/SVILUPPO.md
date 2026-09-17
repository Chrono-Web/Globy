# Sviluppo

- Aggiornato: 2026-09-17
- Stato: progetto Xcode nativo per il Mac, app Tauri in `desktop/` per Windows e Linux;
  Debug usa fixture in processo, senza rete
- Risponde a: come preparare, eseguire e verificare Globy in locale

## Scelte chiuse il 2026-09-16

| Scelta | Valore |
|---|---|
| Versione minima di macOS | 15 Sequoia |
| Liquid Glass | solo su macOS 26; sotto, superficie scura o vetro smerigliato |
| Bundle identifier di produzione | `com.chronocol.globy` |
| Bundle identifier di sviluppo | `com.chronocol.globy.debug` |
| Licenza | GNU GPL versione 3, file `LICENSE` |

Il progetto dell'app è **Xcode nativo** (`Globy.xcodeproj`, cartelle sincronizzate sul
filesystem). Nessun generatore esterno. Dipendenze: solo il package locale
`Packages/GlobyCore/`.

Toolchain verificata il 2026-09-17:

| Strumento | Valore |
|---|---|
| Xcode | 26.6 (build 17F113) |
| Swift | 6.3.3 (`swiftlang-6.3.3.1.3`) |
| Comandi | sotto |

## Stato reale

Esistono:

- `Globy.xcodeproj` — app macOS senza icona Dock (`LSUIElement`), Debug su fixture;
- `Packages/GlobyCore/` — sincronizzazione verificabile senza UI;
- `Spikes/MascotSpike/` — prototipo usa e getta della mascotte (il codice vivo della
  mascotte nell'app sta in `Globy/Mascot/`).

La Debug non contatta Chronocol, salvo `--live`. La Release legge Chronocol pubblico
con sole GET, per poter collaudare l'app vera; le righe «Simula…» esistono solo in
Debug con la fixture.

## Struttura

```text
Globy.xcodeproj
Globy/                  # entry point, menu bar, mascotte, preferenze
GlobyTests/
Packages/GlobyCore/
Spikes/MascotSpike/
docs/
```

Le fixture HTTP e SSE dello spike stanno in `Packages/GlobyCore/Tests/GlobyCoreTests/Fixtures/`
e sono sintetiche. L'app Debug usa `FixtureChronocol` in processo.

## Comandi verificati

```bash
swift test --package-path Packages/GlobyCore
xcodebuild -project Globy.xcodeproj -scheme Globy -destination 'platform=macOS' build
xcodebuild -project Globy.xcodeproj -scheme Globy -destination 'platform=macOS' test
./scripts/crea-dmg.sh
cd Spikes/MascotSpike && swift run MascotSpike --snapshot globo.png
cd Spikes/MascotSpike && swift run -c release MascotSpike --demo
```

Opzioni di avvio, solo in Debug, per provare l'app senza aspettare eventi reali
(`Globy.app/Contents/MacOS/Globy <opzioni>`):

| Opzione | Effetto |
|---|---|
| `--render-icon FILE` | disegna l'icona 1024 × 1024 in FILE (vedi `docs/ASSET.md`) |
| `--live` | legge Chronocol pubblico (solo GET) invece della fixture; dati in `content-live.json` |
| `--open-menu` | apre il pannello della barra dei menu |
| `--open-preferences` | apre la finestra delle Impostazioni |
| `--simulate-vox` | pubblica un VOX sulla fixture e sincronizza |
| `--simulate-return N` | saluto di rientro con N VOX usciti mentre eri via |
| `--poll-seconds S` | controllo periodico ogni S secondi invece di 5 minuti |
| `--publish-silently` | pubblica un VOX senza sincronizzare: lo trova il controllo periodico |

`swift test --package-path Packages/GlobyCore` il 2026-09-17 ha eseguito 34 test senza
rete. `xcodebuild … test` ha eseguito `GlobyTests` sullo stesso toolchain.

La suite automatica non apre connessioni di rete e non pubblica contenuti reali.

## Windows e Linux (`desktop/`)

App Tauri 2 (ADR 0005). Serve Rust (`rustup`, canale stable) e Node 22. Si sviluppa
anche dal Mac: tray, finestre e globo girano, ma vetro Acrylic, forma della finestra e
Wayland si vedono solo sui sistemi veri (collaudo in `docs/COLLAUDO_DESKTOP.md`).

```text
desktop/
├── globy-core/        # porting di GlobyCore, senza grafica; test con le fixture Swift
├── src-tauri/         # app: sessione, tray, finestre, preferenze, forma di Globy
├── src/               # pagine: elenco (menu), Impostazioni (settings), Globy (mascot)
└── *.html             # una pagina per finestra
```

Comandi, dalla cartella `desktop/`:

```bash
npm ci
cargo test -p globy-core
cargo test -p globy-core --test live -- --ignored
cargo test -p globy
npm run tauri dev
npx tauri build
```

Il test `live` legge Chronocol pubblico ed è escluso di default. Il resto non usa la rete.

In sviluppo l'app usa la fixture in processo, con dati in `content-fixture.json`.
Variabili, solo nelle build di debug salvo `GLOBY_SURFACE`:

| Variabile o opzione | Effetto |
|---|---|
| `GLOBY_LIVE=1` | legge Chronocol pubblico invece della fixture |
| `GLOBY_POLL_SECONDS=S` | controllo periodico ogni S secondi |
| `GLOBY_SIMULATE_VOX=N` | pubblica N VOX sulla fixture 4 secondi dopo l'avvio |
| `globy --simulate-vox N` | con Globy già aperto, pubblica N VOX sulla copia aperta |
| `globy --open-settings` | con Globy già aperto, apre le Impostazioni |
| `GLOBY_SURFACE=dark` | superficie scura anche dove c'è il vetro, per confrontare |

Dati di sviluppo: sul Mac `~/Library/Application Support/com.chronocol.globy/`.
Regole e testi comuni stanno in `globy-core`: una modifica a una politica va fatta in
`Packages/GlobyCore` e in `desktop/globy-core`, con lo stesso test.

## Ambiente

Le build di sviluppo devono poter cambiare base URL senza modificare sorgenti. La
produzione deve avere una base URL esplicita nella configurazione di build.

Non mettere credenziali in `.xcconfig` versionati. Se in futuro servono valori locali,
fornire un file `.example` e ignorare la copia privata.

## Fixture locale

`Packages/GlobyCore` riproduce in processo, senza rete:

- lista iniziale;
- nuova pubblicazione;
- evento SSE duplicato o malformato;
- aggiornamento e ritiro;
- RSS che copre `lastSuccessfulSyncAt` e RSS che non lo copre;
- paginazione JSON del buco;
- 503 sullo stream;
- timeout, offline e riconnessione;
- raffica di più elementi.

La suite automatica non deve pubblicare o ritirare contenuti reali. Un server HTTP
di sviluppo servirà in fase 4; la Debug dell'app usa `FixtureChronocol` in processo.

## Strategia di test

| Livello | Verifica |
|---|---|
| Unitari | dedupe, baseline, politica notifiche, retry, mapping degli stati |
| Contratto | decoding di fixture HTTP/SSE e compatibilità dei payload |
| Integrazione | coordinatore + store in memoria + clock controllabile |
| UI | menu bar, preferenze, permessi negati, apertura del permalink |
| Manuale | finestra trasparente, Space, multi-monitor, fullscreen, VoiceOver |
| Prestazioni | CPU, GPU, memoria e rete a riposo e durante un evento |

Tempo e casualità devono essere iniettabili: testare backoff o pause con attese reali
rende la suite lenta e instabile.

## Definizione di completamento

Una funzionalità non passa a `[x]` perché compila. Deve avere il criterio di verifica
indicato nella roadmap e una prova ripetibile. Se è costruita ma non provata nel
contesto reale dichiarato, resta `[~]`.
