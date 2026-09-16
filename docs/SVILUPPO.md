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

Restano da registrare, quando verificati: versione di Xcode, toolchain Swift, se il
progetto è Xcode nativo o generato, dipendenze esterne ammesse.

## Stato reale

Non esiste ancora il `.xcodeproj` dell'app. C'è uno spike usa e getta in
`Spikes/MascotSpike/` (SwiftPM) che non è Globy e non sostituisce il target di
produzione. Non inventare comandi di build dell'app finché quel progetto non esiste
e i comandi non sono verificati qui.

## Struttura proposta

La struttura definitiva nasce dallo spike di sincronizzazione. La direzione preferita
è separare la shell macOS dalla logica verificabile:

```text
Globy.xcodeproj
Globy/                  # entry point, menu bar, finestre, asset, entitlement
Packages/GlobyCore/     # dominio, sincronizzazione, persistenza astratta
GlobyTests/
GlobyUITests/
Fixtures/               # risposte HTTP e sequenze SSE prive di dati sensibili
Spikes/                 # prototipi usa e getta, non l'app
docs/
```

Non creare cartelle vuote per simulare moduli: Git non le conserva e i nomi danno una
falsa impressione di implementazione.

## Ambiente

Le build di sviluppo devono poter cambiare base URL senza modificare sorgenti. La
produzione deve avere una base URL esplicita nella configurazione di build.

Non mettere credenziali in `.xcconfig` versionati. Se in futuro servono valori locali,
fornire un file `.example` e ignorare la copia privata.

## Fixture locale

Prima di collegare l'interfaccia alla produzione serve un server o un protocollo finto
capace di riprodurre:

- lista iniziale;
- nuova pubblicazione;
- evento SSE duplicato o malformato;
- aggiornamento e ritiro;
- RSS che copre `lastSuccessfulSyncAt` e RSS che non lo copre;
- paginazione JSON del buco;
- 503 sullo stream;
- timeout, offline e riconnessione;
- raffica di più elementi.

La suite automatica non deve pubblicare o ritirare contenuti reali.

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
