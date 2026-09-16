# Prodotto

- Aggiornato: 2026-09-16
- Stato: bozza da validare con il primo prototipo
- Risponde a: che cosa è Globy, per chi esiste e dove finisce la prima versione

## Promessa

Globy porta Chronocol vicino senza chiedere di tenere il sito aperto: il pulsante nella
barra dei menu raccoglie le VOX recenti e ricorda che cosa è già stato visto. Quando
arriva una nuova VOX confermata, un piccolo globo compare brevemente nell'angolo
inferiore destro dello schermo e poi scompare.

La presenza stabile è il pulsante nella barra dei menu. La mascotte è un richiamo
transitorio, non una finestra da tenere sempre sul desktop.

## Persona e contesto

La prima versione è per una persona che:

- usa macOS;
- vuole seguire le VOX pubbliche di Chronocol;
- accetta di lasciare una piccola utility in esecuzione nella barra dei menu;
- non deve possedere un account Chronocol.

Non è ancora un prodotto per la redazione e non sostituisce il sito come esperienza di
lettura completa.

## Esperienza principale

1. Al primo avvio Globy spiega che cosa legge e quando può notificare.
2. Costruisce una baseline locale senza notificare l'archivio.
3. La barra dei menu mostra un pulsante persistente; un clic apre le VOX recenti e il
   numero di non lette.
4. Quando una nuova pubblicazione è stata verificata, il piccolo globo compare in basso
   a destra, richiama brevemente l'attenzione e si nasconde automaticamente.
5. Globy può mostrare anche una notifica locale, secondo permessi e preferenze.
6. Un clic su una VOX apre il permalink pubblico nel browser predefinito.
7. Dopo rete assente, stop o riavvio, Globy recupera lo stato senza una raffica di
   notifiche.

## Mascotte

La mascotte è un avviso visivo transitorio, non il motore del prodotto.

- Compare soltanto dopo la conferma autorevole di una nuova VOX.
- Entra nell'angolo inferiore destro e si nasconde automaticamente.
- La sua durata esatta verrà scelta nello spike, senza codificarla nella specifica.
- Può essere disabilitata senza interrompere la sincronizzazione.
- Continenti, occhi e animazioni appartengono allo stesso corpo visivo.
- Quando è ferma non deve richiedere un render loop continuo non necessario.
- Rispetta Reduce Motion.
- Non ostacola clic, fullscreen, cambio Space o lavoro su più monitor.

Sono ancora decisioni aperte:

- quale schermo usare quando ce n'è più di uno;
- margine preciso dall'angolo e rispetto di Dock e area visibile;
- livello della finestra rispetto ad app e fullscreen;
- click-through ed eventuale interazione diretta;
- animazione di entrata, attesa e uscita;
- comportamento con più VOX arrivate insieme.

## Prima versione

Incluso:

- app macOS nella barra dei menu;
- elenco recente delle VOX;
- conteggio e stato letto/non letto;
- stato distinto di contenuto già notificato;
- notifiche locali, inizialmente senza suono;
- pausa temporanea delle notifiche;
- avvio al login facoltativo;
- recupero dopo interruzioni;
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

## Domande che bloccano il progetto Xcode

- Qual è la versione minima di macOS?
- Qual è il bundle identifier definitivo?
- La distribuzione ufficiale sarà Developer ID o Mac App Store?
- Quale licenza si applica al codice?
- Chi possiede e con quale licenza vengono distribuiti modello, texture, font e suoni?
