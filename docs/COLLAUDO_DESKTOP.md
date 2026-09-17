# Collaudo di Globy per Windows e Linux

- Aggiornato: 2026-09-17
- Vale per: gli installer della Release 0.2.0 e quelli creati dalla CI (`.github/workflows/desktop.yml`)
- Ruolo: checklist del collaudo umano prima di pubblicare la 0.2.0

Chi sviluppa lavora su un Mac e non vede Windows e Linux: questa prova la fanno persone
con quei sistemi. Gli installer leggono Chronocol vero con sole GET. Mai pubblicare o
ritirare VOX per far scattare una prova (`AGENTS.md`, regola 5).

## Dove prendere gli installer

Dai pulsanti del README (ultima Release). Per provare una modifica non ancora
pubblicata: GitHub › **Actions** › workflow **Desktop** › l'ultima esecuzione verde ›
**Artifacts** (`Globy-Windows`, `Globy-Linux`).

Ogni riga ❌ diventa una issue con il modulo «Problema» (`docs/SEGNALARE.md`).

Segna ogni riga con ✅, ❌ (con una nota e, se puoi, uno screenshot) o «non provato».
Scrivi anche sistema e versione: Windows 10 o 11; per Linux distribuzione, ambiente
(GNOME, KDE…) e se la sessione è **X11** o **Wayland** (`echo $XDG_SESSION_TYPE`).

## 1. Installazione e primo avvio

- [ ] Windows: SmartScreen avvisa; «Ulteriori informazioni › Esegui comunque» installa
      senza chiedere la password di amministratore.
- [ ] Linux: l'AppImage, reso eseguibile, si apre con un doppio clic; il `.deb` si installa.
- [ ] L'icona di Globy (sfera scura con due occhi) compare tra le icone di sistema.
- [ ] Dopo pochi secondi Globy si presenta in basso a destra; la freccia (numerino 3)
      spiega icona e Impostazioni e alla fine chiede «Partiamo con gli ultimi 5 VOX?».
- [ ] «Sì, partiamo»: passano 5 VOX veri, «VOX recente · già uscito», frecce con numerini.
- [ ] Il testo si scrive un carattere alla volta e gli occhi lo seguono.
- [ ] Clic su un VOX nel fumetto: apre il sito di Chronocol nel browser.
- [ ] Chiudi Globy (icona › Esci) e riaprilo: la presentazione non ricompare; compare il
      saluto «Heilà!».
- [ ] Aprendo Globy una seconda volta non parte una seconda copia: si apre l'elenco.

## 2. Icona ed elenco dei VOX

- [ ] Windows: clic sinistro sull'icona apre l'elenco vicino all'icona; clic destro apre
      il menu «Ultimi VOX / Impostazioni… / Esci».
- [ ] Linux: clic sull'icona apre il menu; «Ultimi VOX» apre l'elenco in alto a destra.
- [ ] Al primo avvio l'intestazione dice «Nessun VOX non letto».
- [ ] Clic su un VOX: apre il browser e l'elenco si chiude.
- [ ] Clic fuori dall'elenco o Esc: l'elenco si chiude.
- [ ] Windows: l'elenco ha lo sfondo in vetro sfocato.

## 3. Globy

- [ ] Globo e fumetto sono nitidi, anche con lo schermo al 125% o 150%.
- [ ] Windows: dietro globo e fumetto c'è il vetro sfocato; fuori dalle loro forme non
      c'è nessun rettangolo.
- [ ] Fuori da globo, fumetto, X e frecce i clic passano alla finestra sotto.
- [ ] Quando compare Globy, il cursore resta nell'app in cui stavi scrivendo.
- [ ] Trascinando il globo, globo e fumetto non escono dallo schermo.
- [ ] X chiude solo il fumetto; «No, grazie» chiude e Globy esce poco dopo.
- [ ] Clic destro su Globy: «Impostazioni…» e «Nascondi Globy» funzionano.
- [ ] Gli occhi seguono il puntatore (X11 e Windows).
- [ ] Wayland: Globy compare in una finestra posizionata dal sistema e resta usabile.
- [ ] Con «Riduci animazioni» del sistema: niente scrittura animata, nessun suono.

## 4. Impostazioni

- [ ] Si aprono in una finestra normale; mentre sono aperte, in basso a destra c'è il
      fumetto «Anteprima».
- [ ] «Dimensioni personalizzate»: i cursori cambiano subito globo, testo e pulsanti.
- [ ] «Mostra sempre Globy»: Globy resta a schermo; compare la nota sulla batteria.
- [ ] «Gli occhi seguono il puntatore» spento: gli occhi guardano avanti.
- [ ] «Suono» spento: nessun suono all'arrivo.
- [ ] «Apri Globy all'accesso» acceso, poi esci dall'account e rientra: Globy parte da solo.
- [ ] «Notifiche di sistema» acceso: conferma, poi Globy sparisce.
- [ ] «Azzera…»: elenco vuoto, poi nuova presentazione da capo.
- [ ] «Disinstalla Globy…»: Windows apre il programma di disinstallazione; Linux chiude
      Globy e cancella i dati.

## 5. Arrivi, rientro e consumi

- [ ] Un VOX nuovo vero arriva entro ~5 minuti con «Nuovo VOX»; nell'elenco «Non letto».
- [ ] Con le notifiche di sistema, un VOX nuovo arriva come notifica e Globy non compare.
- [ ] Sospensione del computer per qualche minuto, poi risveglio: il saluto di rientro
      compare una volta sola.
- [ ] Senza rete, il saluto dice che non riesce a raggiungere Chronocol.
- [ ] Gestione attività (Windows) o `top` (Linux): con Globy nascosto la CPU sta vicino
      a 0%; con Globy a schermo e mouse fermo resta bassa.

## Esito

| Data | Sistema | Esito | Note |
|---|---|---|---|
