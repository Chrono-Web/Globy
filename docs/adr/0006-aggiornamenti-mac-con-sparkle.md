# 0006 — Aggiornamenti automatici: Sparkle sul Mac, updater di Tauri su Windows e Linux

- Stato: accettato
- Data: 2026-09-18
- Proprietario: Palu17
- Vincolante per: `Globy/UpdateController.swift`, `Globy/Info.plist`,
  `scripts/crea-appcast.sh`, `desktop/src-tauri/src/updates.rs`,
  `desktop/scripts/latest-json.mjs`, `.github/workflows/desktop.yml`,
  `docs/DISTRIBUZIONE.md`
- Nasce da: fase 5 della roadmap, «Meccanismo di aggiornamento»
- Sostituisce: nulla

## Contesto

Fino alla 0.2.1 per aggiornare bisognava tornare su GitHub e riscaricare il DMG. Chi
non lo fa resta indietro senza saperlo. Globy non è firmato con Developer ID né
notarizzato (docs/DISTRIBUZIONE.md), ed è un'app accessoria senza Dock: le finestre
standard di un updater compaiono fuori contesto.

## Decisione

- **Sparkle 2** (pacchetto Swift) scarica, verifica e installa. Ogni archivio è firmato
  con una chiave **EdDSA**: la pubblica sta in `Info.plist` (`SUPublicEDKey`), la
  privata nel Portachiavi di chi pubblica (account `globy`). La firma sostituisce, per
  l'integrità, quella Developer ID che manca.
- **Interfaccia propria**: `UpdateController` implementa `SPUUserDriver` al posto delle
  finestre di Sparkle. Una versione nuova si segnala con un pallino arancione sul globo
  nella barra dei menu, una riga nel menu, un avviso nel fumetto di Globy una sola
  volta per versione («Aggiornati» o «Più tardi»; notifica del Mac se Globy è spento
  a favore delle notifiche di sistema) e la sezione «Aggiornamenti» delle Impostazioni con
  «Scarica e installa», avanzamento e «Riavvia Globy».
- **Feed**: `appcast.xml` allegato a ogni Release, letto da
  `/releases/latest/download/appcast.xml`. Contiene una sola voce, l'ultima versione.
- Controllo automatico una volta al giorno, disattivabile; nessun profilo di sistema
  inviato.
- **Windows e Linux**: plugin `tauri-plugin-updater`, stessa interfaccia (pallino
  sull'icona, voce nell'elenco e nel menu dell'icona, avviso di Globy, sezione nelle
  Impostazioni). Feed `latest.json` creato dalla CI sui tag; installer NSIS, AppImage e
  `.deb` firmati con una chiave minisign, la pubblica in `tauri.conf.json`, la privata nel
  secret `TAURI_SIGNING_PRIVATE_KEY` del repository. Il `.deb` si installa con pkexec:
  chiede la password di amministratore.

Escluse: un controllo fatto a mano sulle API di GitHub con apertura del browser (non
installa e resta il percorso Gatekeeper a ogni versione); le finestre standard di
Sparkle (fuori stile per un'app nella barra dei menu).

## Come si verifica

Una copia 0.3.0 con feed locale (`--update-feed`, solo Debug) vede una 0.3.1 firmata:
pallino e sezione compaiono, «Scarica e installa» scarica e verifica, «Riavvia Globy»
sostituisce l'app e la riapre alla 0.3.1; «Aggiornati» nel fumetto avvia lo stesso
percorso. Provato il 2026-09-18.

Stessa prova con la build Tauri compilata sul Mac (`GLOBY_UPDATE_FEED`, solo Debug): il
fumetto compare, `--install-update` scarica, verifica, installa e riapre alla 0.3.1.
Installer Windows, AppImage e `.deb` si provano con `docs/COLLAUDO_DESKTOP.md` §6.
Resta da provare con una Release vera da 0.3.0 alla successiva.

## Conseguenze

- Chi ha la 0.2.1 o precedenti aggiorna a mano una volta.
- **Perdere una chiave privata** vuol dire che le copie installate di quel sistema non
  accettano più aggiornamenti: serve una nuova chiave e un'altra installazione manuale.
  Vanno tenute copie di sicurezza fuori dalla repository (docs/DISTRIBUZIONE.md).
- `CURRENT_PROJECT_VERSION` deve crescere a ogni release: Sparkle confronta il numero di
  build.
- Un'app avviata dal DMG o da Download (App Translocation) non si può aggiornare:
  Sparkle mostra l'errore e va spostata in Applicazioni.
- Su Linux l'AppImage si aggiorna solo se il file è scrivibile dall'utente; il `.deb`
  richiede la password.

## Quando riesaminare

Se Globy passa a Developer ID e notarizzazione, o al Mac App Store; se Sparkle smette di
essere mantenuto.
