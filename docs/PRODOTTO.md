# Prodotto

- Aggiornato: 2026-09-17
- Stato: bozza; le domande che bloccavano il progetto Xcode sono chiuse il 2026-09-16
- Risponde a: che cosa è Globy, per chi esiste e dove finisce la prima versione

## Promessa

Globy è il compagno ufficiale macOS di Chronocol: porta i contenuti pubblici vicino
senza chiedere di tenere il sito aperto. Il pulsante nella barra dei menu raccoglie le
VOX recenti e ricorda che cosa è già stato visto. Quando arriva una nuova VOX
confermata, un piccolo globo compare brevemente nell'angolo inferiore destro dello
schermo e poi scompare.

La presenza stabile è il pulsante nella barra dei menu. La mascotte è un richiamo
transitorio, non una finestra da tenere sempre sul desktop.

## Persona e contesto

La prima versione è per una persona che:

- usa macOS 15 o successivo;
- vuole seguire le VOX pubbliche di Chronocol;
- accetta di lasciare una piccola utility in esecuzione nella barra dei menu;
- non deve possedere un account Chronocol.

Non è ancora un prodotto per la redazione e non sostituisce il sito come esperienza di
lettura completa.

## Esperienza principale

1. Al primo avvio Globy saluta una volta con la mascotte, poi spiega che cosa legge
   e quando può notificare. L'archivio non viene notificato.
2. Costruisce una baseline locale senza notificare l'archivio.
3. La barra dei menu mostra un pulsante persistente; un clic apre le VOX recenti e il
   numero di non lette. Se non c'è nulla di nuovo, resta visibile l'ultima VOX nota.
4. Quando una nuova pubblicazione è stata verificata, il piccolo globo compare in basso
   a destra, richiama brevemente l'attenzione e si nasconde automaticamente.
5. Globy può mostrare anche una notifica locale, secondo permessi e preferenze.
6. Un clic su una VOX apre il permalink pubblico nel browser predefinito.
7. Dopo rete assente, stop o riavvio, Globy recupera lo stato senza una raffica di
   notifiche.

## Mascotte

La mascotte è un avviso visivo transitorio, non il motore del prodotto.

- Compare dopo la conferma autorevole di una nuova VOX, con un'unica eccezione:
  il saluto di primo avvio (non è una VOX, non apre un permalink; gli occhi
  restano chiusi come a metà battito, verso chi guarda).
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
  lettura il fumetto resta 6 s. Reduce Motion: solo fade.
- Più VOX: una coda, un globo solo. La freccia in basso a destra passa alla
  successiva, quella in basso a sinistra torna alla precedente; senza
  permanenza, dopo la lettura resta una pausa di circa 1 s.
- Clic su globo o fumetto: apre la VOX visibile su Chronocol.
- La X chiude solo il fumetto. Con più VOX, due frecce in basso (stessa
  distanza dagli angoli che ha la X in alto a destra): indietro e avanti;
  i numeretti indicano quante ce ne sono da quella parte.
- Trascinabile mentre è visibile; al richiamo successivo torna in basso a destra.
  Durante lo spostamento globo e fumetto non escono dalla `visibleFrame`.
  Permanenza disattivata (default): dopo un trascinamento restano 5 s in più, poi
  scompare anche il globo. Permanenza attivabile dal menu: il globo resta a schermo
  anche senza fumetto; la X chiude solo il fumetto.
- Superficie: Liquid Glass su macOS 26, vetro smerigliato sotto.
- Suono di sistema breve, disattivabile; mai con Reduce Motion.

## Primo avvio

Il saluto della mascotte è il prototipo già collaudabile nello spike. Nell'app (fase 3)
resta una sola apparizione, poi due fatti in un fumetto o in un foglio breve:

1. Globy legge le VOX pubbliche di Chronocol;
2. non notifica l'archivio; chiede il permesso notifiche solo dopo questa spiegazione.

Niente wizard a più schermate. Il permesso negato non è un errore: casa
`docs/TRAPPOLE.md` e `docs/PRIVACY.md`.

## Preferenze

Prima versione:

- mascotte accesa o spenta (la sincronizzazione continua);
- permanenza del globo;
- suono della mascotte;
- pausa temporanea delle notifiche;
- avvio al login;
- azzeramento dei dati locali.

Nello spike si possono anche cambiare superficie e click-through; non sono un
obbligo di v1. Fuori dalla prima versione: temi extra, lingue della mascotte,
chat, account.

## Prima versione

Incluso:

- app macOS nella barra dei menu;
- elenco recente delle VOX;
- conteggio e stato letto/non letto;
- stato distinto di contenuto già notificato;
- notifiche locali, inizialmente senza suono;
- pausa temporanea delle notifiche;
- avvio al login facoltativo;
- recupero dopo interruzioni, limitato alle VOX uscite da `lastSuccessfulSyncAt`;
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
