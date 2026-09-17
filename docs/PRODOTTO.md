# Prodotto

- Aggiornato: 2026-09-17
- Stato: bozza; le domande che bloccavano il progetto Xcode sono chiuse il 2026-09-16
- Risponde a: che cosa è Globy, per chi esiste e dove finisce la prima versione

## Promessa

Globy è il compagno ufficiale macOS di Chronocol: porta i contenuti pubblici vicino
senza chiedere di tenere il sito aperto. Il pulsante nella barra dei menu raccoglie i
VOX recenti e ricorda che cosa è già stato visto. Quando arriva un nuovo VOX
confermato, un piccolo globo compare brevemente nell'angolo inferiore destro dello
schermo e poi scompare.

La presenza stabile è il pulsante nella barra dei menu. La mascotte è un richiamo
transitorio, non una finestra da tenere sempre sul desktop.

## Persona e contesto

La prima versione è per una persona che:

- usa macOS 15 o successivo;
- vuole seguire i VOX pubblici di Chronocol;
- accetta di lasciare una piccola utility in esecuzione nella barra dei menu;
- non deve possedere un account Chronocol.

Non è ancora un prodotto per la redazione e non sostituisce il sito come esperienza di
lettura completa.

## Esperienza principale

1. Al primo avvio Globy saluta una volta con la mascotte, poi spiega che cosa legge
   e quando può notificare. L'archivio non viene notificato.
2. Costruisce una baseline locale senza notificare l'archivio.
3. La barra dei menu mostra un pulsante persistente; un clic apre i VOX recenti e il
   numero di non letti. Se non c'è nulla di nuovo, resta visibile l'ultimo VOX noto.
   L'archivio trovato al primo avvio non conta tra i non letti e non ha etichetta:
   non letto vuol dire arrivato dopo la baseline e mai aperto.
4. Quando una nuova pubblicazione è stata verificata, il piccolo globo compare in basso
   a destra, richiama brevemente l'attenzione e si nasconde automaticamente.
5. In alternativa a Globy, la modalità «Notifiche di sistema» delle Preferenze manda
   una notifica del Mac senza suono al posto del globo: mai entrambi.
6. Un clic su un VOX apre il permalink pubblico nel browser predefinito.
7. Dopo rete assente, stop o riavvio, Globy recupera lo stato senza una raffica di
   notifiche.

## Mascotte

La mascotte è un avviso visivo transitorio, non il motore del prodotto.

- Compare dopo la conferma autorevole di un nuovo VOX, con due eccezioni che non
  sono VOX e non aprono un permalink (occhi chiusi come a metà battito, verso chi
  guarda):
  - il saluto di primo avvio, una volta sola;
  - il saluto di rientro, sempre, a ogni avvio successivo e a ogni risveglio del Mac
    o dello schermo, dopo la sincronizzazione. Dice com'è andata: «non ti sei perso
    nulla» se non ci sono VOX nuovi, oppure quanti ne sono usciti con la freccia e
    il numerino per aprirli. Se la sincronizzazione fallisce non dice «nulla»: dice
    che non lo sa ancora. La X vuol dire «dopo»; se nessuno usa la freccia il globo
    se ne va e i VOX restano nel menu. Al posto della raffica, non in aggiunta.
    Se non c'è niente di nuovo e un saluto è già comparso negli ultimi 10 minuti
    (anche prima di un riavvio), non si ripete.
    Il testo sta in `WelcomePolicy` (GlobyCore).
- Entra nell'angolo inferiore destro della `visibleFrame` dello schermo col
  puntatore (margine 16 pt, Dock escluso) e si nasconde automaticamente.
  Globo e fumetto restano interamente in quell'area: il globo non esce dal
  margine; il fumetto sta di preferenza sopra il globo e centrato in
  orizzontale, e passa sotto se in alto non c'è spazio. Se il bordo dello
  schermo lo taglierebbe, si sposta (non resta ancorato in alto a sinistra).
- È transitoria: non resta sul desktop. Si può disabilitare senza interrompere
  la sincronizzazione.
- Paralleli, meridiani, occhi e animazioni appartengono allo stesso corpo visivo.
  Niente continenti nella prima versione.
- Quando è ferma o nascosta non deve richiedere un render loop continuo non necessario.
- Rispetta Reduce Motion (dissolvenza, testo già scritto, niente suono).
- Sta sopra il fullscreen e su tutti gli Space; fuori da globo, fumetto, X e
  frecce i clic passano alle app sotto.

Decisioni di comportamento chiuse il 2026-09-16 (ADR 0003 per il motore):

- Motore: globo 2D (SwiftUI Canvas). RealityKit escluso dalla prima versione.
- Fumetto in v1: il globo entra, poi il testo si scrive carattere per carattere;
  gli occhi seguono il carattere, poi chi osserva, poi il puntatore. Dopo la
  lettura il fumetto resta il tempo di leggerlo: circa 0,3 s per parola, tra 2 e
  15 s (`ReadingPolicy`). Una domanda «Sì / No» resta circa 20 s. Reduce Motion:
  solo fade.
- Più VOX: una coda, un globo solo. La freccia in basso a destra passa al
  successivo, quella in basso a sinistra torna al precedente; senza
  permanenza, dopo la lettura resta una pausa di circa 1 s.
- Clic su globo o fumetto: apre il VOX visibile su Chronocol.
- La X chiude solo il fumetto. Con più VOX, due frecce in basso (stessa
  distanza dagli angoli che ha la X in alto a destra): indietro e avanti;
  i numeretti indicano quanti ce ne sono da quella parte.
- Testo di fumetto, menu e banner: senza la sezione «Fonti:» e senza link
  (`VoxText.readable`); le fonti restano nel VOX completo su Chronocol. Il fumetto
  mostra il testo intero; solo oltre 16 righe, caso estremo, finisce con «…». Il clic
  apre il VOX su Chronocol.
- Gli angoli del fumetto appartengono a X e frecce: testo, intestazione e pulsanti
  interni non entrano mai in quelle zone (`VoxLayout.cornerClearance`), anche
  quando le frecce non sono visibili.
- Trascinabile mentre è visibile; al richiamo successivo torna in basso a destra.
  Durante lo spostamento globo e fumetto non escono dalla `visibleFrame`.
  Permanenza disattivata (default): dopo un trascinamento restano 5 s in più, poi
  scompare anche il globo. Permanenza attivabile dal menu: il globo resta a schermo
  anche senza fumetto; la X chiude solo il fumetto.
- Superficie: Liquid Glass su macOS 26, vetro smerigliato sotto.
- Suono di sistema breve, disattivabile; mai con Reduce Motion.

## Primo avvio

Il saluto della mascotte è il prototipo già collaudabile nello spike. Nell'app (fase 3)
resta una sola apparizione, dopo la baseline, poi tre fatti in un fumetto o in un foglio
breve:

1. Globy legge i VOX pubblici di Chronocol;
2. non notifica l'archivio; il permesso notifiche si chiede solo attivando la modalità
   «Notifiche di sistema» nelle Preferenze;
3. per chiudere l'onboarding (punto 4) il globo chiede «Partiamo con gli ultimi 5 VOX pubblicati?» con
   «Sì, partiamo» e «No, grazie». Solo con «Sì» il globo li mostra in coda, dal più
   recente, con l'etichetta «VOX recente · già uscito»: non sono notifiche, non
   segnano `notifiedAt` e non producono banner. «No», la X o nessuna risposta entro
   circa 20 s chiudono la presentazione. Se la baseline è vuota la domanda non c'è.
4. ordine dei fumetti, avanzando con la freccia: presentazione di Globy; dove
   trovarlo nella barra dei menu e cosa c'è nel menu; le Preferenze (compresa la
   modalità notifiche di sistema); infine la proposta dei VOX recenti del punto 3.
   Arrivati alle Preferenze l'onboarding è concluso. Se un fumetto prima viene
   ignorato o chiuso con la X la sequenza si ferma, e la spiegazione resta in cima al
   menu finché non si preme «Ho capito».

Niente wizard a più schermate. Il permesso negato non è un errore: casa
`docs/TRAPPOLE.md` e `docs/PRIVACY.md`.

## Preferenze

Prima versione:

Nell'interfaccia il nome è sempre Globy: niente «mascotte» né «globo».

- sezione Globy: «Mostra sempre Globy» (permanenza), «Apri Globy al login», «Suono»;
- dimensioni personalizzate: interruttore più tre cursori, Globy (60–150%), testo
  del fumetto (85–150%) e pulsanti X e frecce (80–160%). Spento, valgono le
  dimensioni standard ma i valori scelti restano salvati. Finché le Preferenze sono
  aperte Globy mostra un fumetto di anteprima con X e frecce finte, che cambia dal
  vivo;
- «Notifiche di sistema»: modalità alternativa a Globy. Accenderla chiede conferma
  («Attivando le notifiche di sistema, disattiverai la visualizzazione di Globy») e
  il permesso del Mac; con il permesso negato Globy resta attivo e compare una nota.
  Spegnerla riporta Globy;
- azzeramento dei dati locali.

Nello spike si possono anche cambiare superficie e click-through; non sono un
obbligo di v1. Fuori dalla prima versione: temi extra, lingue della mascotte,
chat, account.

## Prima versione

Incluso:

- app macOS nella barra dei menu;
- elenco recente dei VOX;
- conteggio e stato letto/non letto;
- stato distinto di contenuto già notificato;
- notifiche locali, inizialmente senza suono;
- modalità notifiche di sistema al posto di Globy;
- avvio al login facoltativo;
- recupero dopo interruzioni, limitato ai VOX usciti da `lastSuccessfulSyncAt`;
- mascotte transitoria in basso a destra e disattivabile;
- indirizzo del servizio configurabile nelle build di sviluppo.

Escluso:

- notifiche remote tramite APNs;
- garanzia di ricezione ad app terminata;
- login e sincronizzazione tra dispositivi;
- funzioni editoriali o amministrative;
- chat e assistenza AI;
- telemetria e profilazione;
- supporto a Windows, Linux, iOS o iPadOS;
- replica completa del sito Chronocol.

## Comportamenti promessi

| Condizione | Comportamento |
|---|---|
| Sito chiuso, Globy in esecuzione | Sincronizza e può notificare |
| Mascotte disabilitata o non visibile | Sincronizzazione invariata |
| Mac offline o in stop | Recupero al ritorno, con riepilogo |
| Globy terminato | Nessuna promessa fino al riavvio |
| Notifiche negate | Aggiornamenti visibili nella barra dei menu |
| Stream indisponibile | Sincronizzazione HTTP più lenta ma funzionante |
| Primo avvio | Baseline senza raffica sull'archivio |

## Requisiti di piattaforma e licenza

Chiusi il 2026-09-16. Il dettaglio operativo sta nei documenti indicati, non qui.

- macOS 15 o successivo; Liquid Glass su macOS 26, superficie scura o vetro smerigliato
  sotto. Casa: `docs/SVILUPPO.md`.
- Bundle identifier `com.chronocol.globy`. Casa: `docs/SVILUPPO.md`.
- Distribuzione fuori Mac App Store, sorgente e binari su GitHub, senza notarizzazione
  nella prima strategia. Casa: `docs/DISTRIBUZIONE.md`.
- Codice e asset originali GNU GPL versione 3. Casa: `LICENSE` e `docs/ASSET.md`.
- Globy può presentarsi come compagno ufficiale di Chronocol. Casa: `docs/ASSET.md`.

## Metriche di qualità

Prima della release vanno stabilite soglie misurabili per:

- CPU e GPU della mascotte ferma e nascosta;
- memoria a riposo;
- tempo di comparsa dopo una pubblicazione;
- recupero dopo almeno 24 ore offline;
- assenza di duplicati in una sequenza di riconnessioni;
- accessibilità da tastiera e con VoiceOver.

Nessuna metrica implica telemetria: le misure iniziali si raccolgono nei test e nei
collaudi controllati.
