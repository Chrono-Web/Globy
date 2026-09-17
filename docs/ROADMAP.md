# Roadmap

- Aggiornato: 2026-09-17
- Risponde a: che cosa viene prima, quale prova chiude ogni fase e qual è lo stato reale

## Legenda

- `[ ]` non iniziato;
- `[~]` costruito ma non ancora verificato nel contesto dichiarato;
- `[x]` verificato con il criterio scritto.

## Fase 0 — Fondazione

- [x] Definire promessa, perimetro e non-obiettivi del prodotto.
- [x] Separare fonte HTTP autorevole e segnale SSE.
- [x] Documentare privacy, sviluppo, distribuzione e trappole.
- [x] Proporre gli ADR iniziali senza dichiararli accettati.
- [x] Decidere versione minima di macOS: 15, con Liquid Glass su 26.
- [x] Decidere bundle identifier: `com.chronocol.globy`.
- [x] Scegliere licenza del codice e politica degli asset: GNU GPL v3.
- [x] Scegliere il canale di distribuzione: GitHub, fuori Mac App Store, binari non firmati.
- [x] Approvare gli ADR 0001 e 0002.

**Verifica:** il 2026-09-16 una revisione umana ha chiuso le domande in `docs/PRODOTTO.md`
e gli ADR 0001 e 0002 sono `accettato`.

## Fase 1 — Spike di sincronizzazione

- [x] Creare il core Swift verificabile senza UI.
- [x] Creare fixture HTTP e SSE locali.
- [x] Implementare baseline senza notifiche.
- [x] Implementare catch-up, dedupe e retry.
- [x] Simulare aggiornamento, ritiro, 503 e offline prolungato.
- [x] Verificare i limiti del contratto attuale con Chronocol.

**Verifica:** il 2026-09-16 `swift test --package-path Packages/GlobyCore` (Swift 6.3.3)
ha eseguito 26 test senza rete. Un evento SSE non crea un VOX senza conferma HTTP.
Il test di più pagine JSON è definito e passa sulle fixture; il contratto Chronocol
resta instabile per una release (manca un cursore dei cambiamenti).

## Fase 2 — Spike della mascotte

- [x] Confrontare RealityKit e rappresentazione 2D.
- [x] Verificare occhi e meridiani solidali alla rotazione (niente continenti in v1).
- [x] Provare finestra trasparente, trascinamento e click-through.
- [x] Provare entrata e uscita automatica nell'angolo inferiore destro.
- [x] Definire lo schermo di destinazione e rispettarne l'area visibile.
- [x] Provare Space e fullscreen. (più monitor: rimandato, non è un gate)
- [x] Rispettare Reduce Motion.
- [x] Consumo a riposo nel collaudo qualitativo; soglie Instruments restano per la release.
- [x] Globo e fumetto restano nella `visibleFrame`: il fumetto sta sopra e centrato
      se c'è spazio, sotto se il globo è in alto; le animazioni non spostano il globo.

**Verifica:** il 2026-09-16 collaudo umano sul globo 2D. ADR 0003 accettato. Permanenza
opzionale; senza permanenza il trascinamento aggiunge 5 s. Il multi-monitor non è
stato provato e non blocca la fase. Il 2026-09-17 collaudo umano sul vincolo a
schermo: globo e fumetto non escono dall'area visibile durante lo spostamento.

## Fase 3 — MVP macOS

- [x] Creare app e target di test.
- [x] Aggiungere pulsante persistente nella barra dei menu ed elenco recente al clic.
- [x] Persistenza locale di contenuti, letto e notificato.
- [x] Primo avvio: presentazione e onboarding raccontati da Globy (menu, Preferenze),
      baseline senza raffica, poi «Sì / No» per vedere gli ultimi 5 VOX come recenti.
- [x] Saluto di rientro a ogni avvio e risveglio, con esito della sincronizzazione
      e freccia verso i VOX nuovi.
- [x] Controllo periodico a macchina accesa (5 min, jitter, backoff), pausa durante
      lo stop e sync al ritorno della rete.
- [x] Preferenze: Mostra sempre Globy, login, suono, dimensioni personalizzate (Globy,
      testo, pulsanti) con anteprima dal vivo e aptica, azzera dati.
- [x] Modalità «Notifiche di sistema» senza suono, al posto di Globy.
- [x] Apertura del permalink nel browser.
- [x] Globy transitorio, con menu contestuale, indipendente dalla sincronizzazione;
      una sola copia dell'app alla volta.

**Verifica:** il 2026-09-17 `xcodebuild … build` e `test` passano su Xcode 26.6 e il
collaudo umano sulla Release con Chronocol pubblico (sole GET) ha dato esito positivo
per primo avvio e onboarding, menu, Globy e Preferenze (`docs/COLLAUDO_FASE3.md`).
Non provati, e spostati alla fase 4: arrivo di un VOX nuovo reale, notifica di sistema
per un VOX nuovo, rientro dallo stop e cambio rete. Fase 3 chiusa.

## Fase 4 — Collegamento e affidabilità

- [~] Collegare le letture pubbliche di Chronocol: la Release legge già RSS ed elenco
      JSON con sole GET; restano frequenza concordata e SSE.
- [ ] Verificare pubblicazione reale senza operazioni distruttive: Globy, menu non
      letti e, in modalità notifiche di sistema, la notifica del Mac
      (`docs/COLLAUDO_FASE3.md`, sezioni 3 e 6).
- [ ] Verificare stop/risveglio, spegnimento dello schermo e cambio rete, compreso il
      saluto di rientro (`docs/COLLAUDO_FASE3.md`, sezione 4).
- [ ] Verificare riavvio di Globy e del backend.
- [ ] Verificare riepilogo dopo molti arrivi.
- [ ] Verificare modifica e ritiro.
- [ ] Eseguire una prova di carico che includa sito e client desktop.

**Verifica:** tutti gli scenari sono registrati con esito; il client resta corretto con
SSE disabilitato e non supera la frequenza HTTP concordata.

## Fase 5 — Beta distribuibile

- [ ] CI per build e test.
- [ ] Firma e notarizzazione o flusso Mac App Store.
- [ ] Meccanismo di aggiornamento.
- [ ] Licenze e attribuzioni complete.
- [ ] Test su installazione e utente puliti.
- [ ] Misure energetiche entro le soglie decise.
- [ ] Procedura di rollback e segnalazione sicurezza.

**Verifica:** un'altra persona clona e compila senza credenziali, installa la build
ufficiale e completa un aggiornamento dalla versione precedente.

## Fuori roadmap iniziale

- APNs e ricezione ad app terminata;
- account e sincronizzazione fra dispositivi;
- funzioni editoriali;
- altre piattaforme;
- telemetria remota.

Questi temi entrano in roadmap soltanto con un nuovo perimetro e, quando coinvolgono
Chronocol, con una decisione condivisa.
