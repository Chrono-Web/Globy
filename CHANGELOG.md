# Changelog

Le modifiche rilevanti a Globy sono registrate qui.

## 0.3.2 — 2026-09-21

Correzione dell'avvio sul Mac. DMG e installer non firmati con Developer ID.

### Corretto

- **Mac:** Globy 0.3.1 si chiudeva subito dopo l'autorizzazione in Impostazioni di
  Sistema: macOS bloccava il caricamento di Sparkle per la library validation della
  firma locale. La 0.3.2 consente il framework dell'aggiornamento e si avvia
  normalmente. Chi ha scaricato la 0.3.1 deve installare manualmente la 0.3.2,
  perché la copia che non si avvia non può aggiornarsi da sola.

## 0.3.1 — 2026-09-20

Miglioramento per Mac. DMG e installer non firmati.

### Aggiunto

- **Risveglio del Mac:** nelle Impostazioni si può scegliere se mostrare il saluto di
  Globy quando si riapre il portatile o si riaccende lo schermo. La sincronizzazione
  continua anche quando il saluto è disattivato. L'avvio dopo accensione o riavvio
  resta distinto e avviene al login, come richiesto da macOS.

## 0.3.0 — 2026-09-18

Aggiornamenti automatici su Mac, Windows e Linux. DMG e installer non firmati.

### Aggiunto

- **Aggiornamenti automatici:** Globy controlla una volta al giorno se c'è una versione
  nuova. Se c'è, lo dice nel fumetto e si aggiorna con «Aggiornati»; intanto compaiono
  un pallino arancione sull'icona di Globy e una voce nel menu. In Impostazioni ›
  Aggiornamenti si scarica e installa con un clic e Globy si riapre da solo. Ogni
  aggiornamento è verificato con una firma. Su Linux il pacchetto `.deb` chiede la
  password di amministratore; sul Mac Globy deve stare in Applicazioni.
- Da questa versione in poi gli aggiornamenti arrivano da soli; per passare dalla 0.2.1
  alla 0.3.0 serve ancora scaricare l'installer a mano.

## 0.2.1 — 2026-09-18

Correzioni per Mac, Windows e Linux. DMG e installer non firmati.

### Corretto

- **VOX non letti:** un VOX mostrato nel fumetto di Globy ora conta come letto; sul Mac
  anche il clic sul fumetto e sul banner di notifica lo segna come letto.
- **Menu:** il clic su un VOX lo fa mostrare a Globy invece di aprire il sito, che si
  apre dal fumetto. Con Globy spento il menu apre ancora il sito.
- **Mac:** il cursore diventa la manina su globo, fumetto e pulsanti.

## 0.2.0 — 2026-09-17

Globy arriva su Windows e Linux (ADR 0005), **in test**: nessuno l'ha ancora collaudato
su quei sistemi. DMG e installer non firmati. Il Mac cambia solo numero di versione.

### Aggiunto

- **Windows e Linux:** app in `desktop/` con icona di sistema, elenco dei VOX,
  Impostazioni, notifiche di sistema, avvio all'accesso e Globy con fumetto, coda,
  saluti e onboarding. Vetro Acrylic su Windows; con Wayland un Globy ridotto.
- **Nucleo in Rust:** `desktop/globy-core`, stesse regole e stessi test di GlobyCore.
- **Installer:** `Globy-Windows.exe`, `Globy-Linux.AppImage` e `Globy-Linux.deb` creati
  dalla CI, non firmati.
- **README:** pulsanti di download per Mac, Windows e Linux.
- **Segnalazioni:** modulo «Problema» nelle issue e guida in `docs/SEGNALARE.md`.

## 0.1.1 — 2026-09-17

Pre-alpha. DMG non firmato e non notarizzato; macOS 15 o successivo.

### Aggiunto

- **Impostazioni:** «Gli occhi seguono il puntatore». Spento, gli occhi di Globy
  guardano verso chi osserva e il movimento del mouse non lo fa più ridisegnare.
- **Avviso sulla batteria** sotto la sezione Globy quando «Mostra sempre Globy» è
  acceso.

### Migliorato

- **Consumi:** Globy si ridisegna al massimo 30 volte al secondo, solo quando lo
  sguardo cambia in modo visibile, con una sfocatura in meno per fotogramma e linee
  più leggere. La finestra aggiorna i clic una volta per gruppo di movimenti del mouse.
  Con Globy sempre visibile e il mouse in movimento la CPU scende da circa 22% a 18%,
  e a circa 4% con gli occhi che non seguono il puntatore.

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
