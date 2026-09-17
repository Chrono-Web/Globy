# Changelog

Le modifiche rilevanti a Globy sono registrate qui.

## 0.1.0 — 2026-09-17

Prima versione, pre-alpha. DMG non firmato e non notarizzato; macOS 15 o successivo.

### Aggiunto

- **App nella barra dei menu:** elenco degli ultimi VOX con i non letti in evidenza,
  permalink nel browser, store locale JSON (ADR 0004), una sola copia alla volta.
- **Sincronizzazione:** lettura pubblica di Chronocol con sole GET (RSS, elenco JSON
  per i buchi), baseline senza notificare l'archivio, controllo ogni 5 minuti con
  jitter e backoff, sync al risveglio e al ritorno della rete (ADR 0002).
- **Globy:** globo 2D in vetro in basso a destra (ADR 0003), fumetto che resta il
  tempo di leggerlo, coda dal VOX più vecchio al più recente, testo senza fonti né
  link, trascinabile, clic destro con «Impostazioni…» e «Nascondi Globy».
- **Primo avvio:** onboarding raccontato da Globy (menu, Impostazioni) e proposta
  «Sì / No» degli ultimi 5 VOX come recenti.
- **Saluto di rientro** a ogni avvio e risveglio, con l'esito della sincronizzazione;
  senza novità non si ripete entro 10 minuti.
- **Impostazioni:** Mostra sempre Globy, avvio al login, suono; dimensioni di Globy,
  testo e pulsanti con anteprima dal vivo e aptica; «Notifiche di sistema» come
  modalità al posto di Globy; azzera dati; «Disinstalla Globy…».
- **Distribuzione:** DMG con finestra curata e istruzioni (`scripts/crea-dmg.sh`),
  icona di Globy in vetro su grigio molto scuro.
- **Progetto:** documentazione, ADR 0001–0004, spike di sincronizzazione e mascotte,
  39 test di GlobyCore più i test dell'app, collaudo umano della fase 3
  (`docs/COLLAUDO_FASE3.md`). Licenza GNU GPL versione 3.

### Corretto durante il collaudo

- Vetro del globo e del menu tornati dopo il passaggio al progetto Xcode; menu non
  più tagliato né con il bordo squadrato.
- VOX reali lunghi e pieni di link nel fumetto; archivio del primo avvio contato tra
  i non letti; «Heilà» ripetuto a ogni riavvio; onboarding nell'ordine sbagliato.
- «VOX» usato al femminile in interfaccia e documentazione: è maschile.

### Non ancora verificato

Arrivo di un VOX nuovo reale, notifica di sistema per un VOX nuovo, rientro dallo
stop e cambio rete: sono nella fase 4 di `docs/ROADMAP.md`.
