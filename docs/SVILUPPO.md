# Sviluppo

- Aggiornato: 2026-09-16
- Stato: bootstrap documentale; comandi applicativi non ancora disponibili
- Risponde a: come preparare, eseguire e verificare Globy in locale

## Stato reale

Non esistono ancora `.xcodeproj`, `Package.swift`, sorgenti Swift o test eseguibili.
Non inventare comandi di build finché lo spike non crea il progetto e li verifica.

## Prerequisiti da decidere

- versione di Xcode;
- versione minima di macOS;
- toolchain Swift;
- gestione del progetto: Xcode nativo o generatore dichiarato;
- dipendenze esterne ammesse;
- bundle identifier di sviluppo e produzione.

Quando vengono scelti, registrarli qui con data e comando di verifica.

## Struttura proposta

La struttura definitiva nasce dallo spike. La direzione preferita è separare la shell
macOS dalla logica verificabile:

```text
Globy.xcodeproj
Globy/                  # entry point, menu bar, finestre, asset, entitlement
Packages/GlobyCore/     # dominio, sincronizzazione, persistenza astratta
GlobyTests/
GlobyUITests/
Fixtures/               # risposte HTTP e sequenze SSE prive di dati sensibili
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
- paginazione e cursore;
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
