# Roadmap

- Aggiornato: 2026-09-16
- Risponde a: che cosa viene prima, quale prova chiude ogni fase e qual è lo stato reale

## Legenda

- `[ ]` non iniziato;
- `[~]` costruito ma non ancora verificato nel contesto dichiarato;
- `[x]` verificato con il criterio scritto.

## Fase 0 — Fondazione

- [~] Definire promessa, perimetro e non-obiettivi del prodotto.
- [~] Separare fonte HTTP autorevole e segnale SSE.
- [~] Documentare privacy, sviluppo, distribuzione e trappole.
- [~] Proporre gli ADR iniziali senza dichiararli accettati.
- [ ] Decidere versione minima di macOS.
- [ ] Decidere bundle identifier.
- [ ] Scegliere licenza del codice e politica degli asset.
- [ ] Scegliere il canale di distribuzione.
- [ ] Approvare o sostituire gli ADR proposti.

**Verifica:** una revisione umana risponde alle domande aperte in `docs/PRODOTTO.md` e
gli ADR necessari passano ad `accettato`. Fino ad allora la fase resta `[~]`.

## Fase 1 — Spike di sincronizzazione

- [ ] Creare il core Swift verificabile senza UI.
- [ ] Creare fixture HTTP e SSE locali.
- [ ] Implementare baseline senza notifiche.
- [ ] Implementare catch-up, dedupe e retry.
- [ ] Simulare aggiornamento, ritiro, 503 e offline prolungato.
- [ ] Verificare i limiti del contratto attuale con Chronocol.

**Verifica:** la suite passa senza rete e dimostra che nessun evento SSE è considerato
autorevole. Il test di più di una pagina di cambiamenti deve essere definito prima di
considerare stabile il contratto.

## Fase 2 — Spike della mascotte

- [ ] Confrontare RealityKit e rappresentazione 2D.
- [ ] Verificare occhi e continenti solidali alla rotazione.
- [ ] Provare finestra trasparente, trascinamento e click-through.
- [ ] Provare entrata e uscita automatica nell'angolo inferiore destro.
- [ ] Definire lo schermo di destinazione e rispettarne l'area visibile.
- [ ] Provare più monitor, Space e fullscreen.
- [ ] Rispettare Reduce Motion.
- [ ] Misurare CPU, GPU e memoria a riposo.

**Verifica:** una decisione registrata sceglie l'approccio grafico con misure e
comportamenti riproducibili sul target macOS dichiarato.

## Fase 3 — MVP macOS

- [ ] Creare app e target di test.
- [ ] Aggiungere pulsante persistente nella barra dei menu ed elenco recente al clic.
- [ ] Persistenza locale di contenuti, letto e notificato.
- [ ] Notifiche locali senza suono per impostazione iniziale.
- [ ] Apertura del permalink nel browser.
- [ ] Pausa notifiche e avvio al login facoltativo.
- [ ] Mascotte transitoria, disattivabile e indipendente dalla sincronizzazione.
- [ ] Azzeramento dei dati locali.

**Verifica:** una persona installa una build pulita, nega o concede le notifiche,
riceve una pubblicazione simulata, vede il globo comparire e scomparire una sola volta,
apre la barra dei menu e raggiunge il contenuto corretto.

## Fase 4 — Collegamento e affidabilità

- [ ] Collegare le letture pubbliche di Chronocol.
- [ ] Verificare pubblicazione reale senza operazioni distruttive.
- [ ] Verificare stop/risveglio e cambio rete.
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
