# Collaudo della fase 3

- Aggiornato: 2026-09-17
- Vale per: la build Release di `Globy.xcodeproj` installata in `/Applications`
- Ruolo: checklist del collaudo umano che chiude la fase 3 in `docs/ROADMAP.md`

La Release legge Chronocol pubblico con sole GET: i VOX sono quelli veri. Non esistono
comandi «Simula»: le prove su un nuovo VOX dipendono da una pubblicazione reale.
Mai pubblicare o ritirare in produzione per far scattare una prova (`AGENTS.md`, regola 5).

## Preparazione

1. Chiudi ogni Globy aperto (Debug da Xcode compreso): menu del globo › Esci.
2. Compila e installa la Release, dalla cartella del progetto:

   ```bash
   xcodebuild -project Globy.xcodeproj -scheme Globy -configuration Release -derivedDataPath build/release build
   ditto build/release/Build/Products/Release/Globy.app /Applications/Globy.app
   ```

   Prima di `ditto` Globy deve essere chiuso: sovrascrivere l'app mentre gira la fa
   terminare dal sistema, e un `open` subito dopo può non riaprirla. Se succede,
   attendi qualche secondo e rilancia `open`.
3. Solo se ripeti il collaudo da zero, azzera i dati della Release (non tocca la Debug):

   ```bash
   defaults delete com.chronocol.globy
   rm -rf ~/Library/Application\ Support/Globy/com.chronocol.globy
   ```

   Il permesso notifiche resta: per riprovarlo, Impostazioni di Sistema › Notifiche ›
   Globy.
4. Avvia `/Applications/Globy.app` dal Finder o con `open /Applications/Globy.app`.

Segna ogni riga con ✅, ❌ (con una nota su cosa è successo) o «non provato».

## 1. Primo avvio

- [ ] Compare il globo nella barra dei menu; nessuna icona nel Dock.
- [ ] Dopo pochi secondi Globy si presenta in basso a destra; la freccia (numerino 3)
      porta a: barra dei menu e menu, poi Preferenze.
- [ ] Per ultimo chiede «Partiamo con gli ultimi 5 VOX pubblicati?».
- [ ] «Sì, partiamo»: passano 5 VOX veri, intestazione «VOX recente · già uscito»,
      frecce con numerini, nessun banner di sistema.
- [ ] I VOX si leggono interi, senza «Fonti:» né link.
- [ ] Clic su un VOX recente: apre il permalink giusto nel browser.
- [ ] Esci e riapri Globy: la presentazione **non** ricompare; compare il saluto di
      rientro («Non ti sei perso nulla…» se non è uscito niente).
- [ ] (Da zero una seconda volta) «No, grazie»: il fumetto si chiude e il globo esce.
- [ ] Clic sul testo del fumetto durante la domanda: non succede nulla.

## 2. Menu nella barra

- [ ] Clic sul globo: pannello in vetro con angoli arrotondati, nessun bordo squadrato.
- [ ] Al primo avvio l'intestazione dice «Nessun VOX non letto»: l'archivio non conta.
- [ ] Se l'onboarding di Globy è stato chiuso con la X prima delle Preferenze, «Due cose,
      poi basta» resta in cima al menu; «Ho capito» lo chiude.
- [ ] L'elenco scorre; intestazione, Preferenze ed Esci restano visibili.
- [ ] Clic su un VOX: apre il browser e il menu si chiude.
- [ ] Clic fuori dal pannello o Esc: il pannello si chiude.
- [ ] Nessuna riga «Simula…».

## 3. Un VOX nuovo vero

Richiede una pubblicazione reale su Chronocol mentre Globy è acceso. Il controllo
periodico passa ogni 5 minuti circa.

- [ ] Entro ~5 minuti dalla pubblicazione Globy compare con «Nuovo VOX», senza
      notifica del Mac.
- [ ] Il menu mostra «1 VOX non letto» e l'etichetta «Non letto · Notificato».
- [ ] Aperto il VOX dal menu, diventa «Letto» e il conteggio scende.
- [ ] Il fumetto resta più o meno il tempo di leggerlo, poi il globo esce da solo.

## 4. Rientro e rete

- [ ] Menu Apple › Stop, attendi almeno un minuto, risveglia: dopo ~3 s il saluto di
      rientro compare una volta sola.
- [ ] Se nel frattempo sono usciti VOX: «Mentre eri via sono usciti N nuovi VOX», la
      freccia li apre, la X li lascia nel menu.
- [ ] Spegni il Wi-Fi e fai Stop/risveglio: il saluto dice che non riesce a raggiungere
      Chronocol, non «nulla di nuovo».
- [ ] Riaccendi il Wi-Fi: nessun errore visibile; il menu si aggiorna.
- [ ] Spegnimento dello schermo (non stop): al risveglio il saluto compare una volta.

## 5. Mascotte

- [ ] Trascinamento del globo: globo e fumetto non escono dallo schermo.
- [ ] X: chiude solo il fumetto.
- [ ] Clic destro su Globy o sul fumetto: menu «Preferenze…» (apre le Preferenze) e
      «Nascondi Globy» (esce subito; torna al prossimo VOX).
- [ ] In un'app a tutto schermo e in un altro Space il globo compare sopra.
- [ ] Fuori da globo, fumetto, X e frecce i clic passano all'app sotto.
- [ ] Impostazioni di Sistema › Accessibilità › Schermo › Riduci movimento: solo
      dissolvenza, testo già scritto, nessun suono.

## 6. Preferenze

- [ ] Menu › Preferenze…: finestra normale con barra del titolo; Globy compare nel Dock
      e in ⌘Tab finché è aperta, poi sparisce di nuovo. Nessuna parola «mascotte».
- [ ] Mentre è aperta, in basso a destra c'è il fumetto «Anteprima».
- [ ] «Dimensioni personalizzate» acceso: i cursori Globy, Testo e Pulsanti cambiano
      subito globo, fumetto, X e frecce; il testo non viene mai tagliato né tocca le frecce.
- [ ] Trascinando i cursori con il trackpad si sente un tocco a ogni scatto, più forte
      al 100%.
- [ ] Spento: tornano le dimensioni standard; riacceso, tornano quelle scelte.
- [ ] «Mostra sempre Globy»: Globy resta a schermo; la X chiude solo il fumetto.
- [ ] «Suono» spento: nessun suono all'arrivo.
- [ ] «Notifiche di sistema» acceso: avviso di conferma, poi richiesta di permesso del
      Mac; Globy e l'anteprima spariscono, le sezioni Globy e Dimensioni si disattivano.
- [ ] Con le notifiche di sistema, un nuovo VOX arriva come notifica del Mac e Globy
      non compare. Permesso negato: Globy resta acceso e c'è una nota.
- [ ] Spento di nuovo: Globy e l'anteprima tornano.
- [ ] «Apri Globy al login» acceso, poi logout e login: Globy parte da solo e saluta.
- [ ] «Azzera…» e conferma: menu vuoto, poi nuova baseline e presentazione da capo.

## Esito

Registra qui data, versione di macOS, esito e problemi aperti. Con tutte le righe
✅ (o «non provato» motivato) i punti della fase 3 passano da `[~]` a `[x]`.

| Data | macOS | Esito | Note |
|---|---|---|---|
| | | | |
