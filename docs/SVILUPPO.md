# Sviluppo

- Aggiornato: 2026-09-16
- Stato: bootstrap; l'app Xcode non esiste ancora
- Risponde a: come preparare, eseguire e verificare Globy in locale

## Scelte chiuse il 2026-09-16

| Scelta | Valore |
|---|---|
| Versione minima di macOS | 15 Sequoia |
| Liquid Glass | solo su macOS 26; sotto, superficie scura o vetro smerigliato |
| Bundle identifier di produzione | `com.chronocol.globy` |
| Bundle identifier di sviluppo | `com.chronocol.globy.debug` |
| Licenza | GNU GPL versione 3, file `LICENSE` |

Restano da registrare, quando verificati: se il progetto dell'app è Xcode nativo o
generato, dipendenze esterne ammesse.

Toolchain verificata il 2026-09-16 sullo spike di sincronizzazione:

| Strumento | Valore |
|---|---|
| Xcode | 26.6 (build 17F113) |
| Swift | 6.3.3 (`swiftlang-6.3.3.1.3`) |
| Comando | `swift test --package-path Packages/GlobyCore` |

## Stato reale

Non esiste ancora il `.xcodeproj` dell'app. Esistono due spike SwiftPM, nessuno dei
due è Globy:

- `Packages/GlobyCore/` — sincronizzazione verificabile senza UI;
- `Spikes/MascotSpike/` — mascotte 2D usa e getta.

Non inventare comandi di build dell'app finché quel progetto non esiste e i comandi
non sono verificati qui.

## Struttura

La shell macOS arriverà con il progetto Xcode. La logica verificabile vive già nel
package:

```text
Packages/GlobyCore/     # dominio, sincronizzazione, store in memoria, fixture
Spikes/MascotSpike/     # prototipo usa e getta della mascotte
docs/
```

La struttura prevista per l'app, quando esisterà:

```text
Globy.xcodeproj
Globy/                  # entry point, menu bar, finestre, asset, entitlement
Packages/GlobyCore/
GlobyTests/
GlobyUITests/
Spikes/
docs/
```

Le fixture HTTP e SSE dello spike stanno in `Packages/GlobyCore/Tests/GlobyCoreTests/Fixtures/`
e sono sintetiche. Non creare cartelle vuote per simulare moduli.

## Comandi verificati

```bash
swift test --package-path Packages/GlobyCore
cd Spikes/MascotSpike && swift run MascotSpike --snapshot globo.png
cd Spikes/MascotSpike && swift run -c release MascotSpike --demo
```

La suite di `GlobyCore` non apre connessioni di rete.

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
di sviluppo resta utile quando nascerà l'app, non per i test del core.

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
