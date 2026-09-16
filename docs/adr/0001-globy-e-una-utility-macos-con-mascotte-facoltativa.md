# 0001 — Globy è una utility macOS con mascotte facoltativa

- Stato: proposto
- Data: 2026-09-16
- Proprietario: progetto Globy
- Vincolante per: prodotto, shell macOS, mascotte
- Nasce da: fondazione iniziale della repository
- Sostituisce: nulla

## Contesto

Globy deve poter segnalare le nuove VOX quando il sito non è aperto e mantenere una
presenza visiva riconoscibile. Una finestra tradizionale obbligherebbe a tenere aperta
un'interfaccia più grande del necessario; una mascotte sempre visibile renderebbe invece
il prodotto invasivo e confonderebbe visibilità con funzionamento.

La prima versione è destinata soltanto a macOS. Questo permette integrazione con barra
dei menu, notifiche, login item e finestre trasparenti senza un runtime multipiattaforma.

## Decisione

Globy viene progettato come applicazione macOS autonoma. Un pulsante persistente nella
barra dei menu apre l'elenco delle VOX recenti; sincronizzazione ed elenco funzionano
senza una finestra principale permanente.

Quando la sincronizzazione conferma una nuova VOX, la mascotte compare brevemente
nell'angolo inferiore destro e poi scompare. È facoltativa e può essere disabilitata
senza chiudere Globy o interrompere la sincronizzazione. Swift e SwiftUI sono la base
proposta; AppKit resta confinato agli adattatori necessari per il comportamento della
finestra.

## Come si verifica

- la scomparsa automatica della mascotte non ferma una sincronizzazione simulata;
- la barra dei menu resta utilizzabile con mascotte disabilitata;
- una nuova VOX confermata produce una sola entrata e una sola uscita del globo;
- il globo rispetta l'area visibile dello schermo scelto;
- il processo non mostra un'icona Dock se il comportamento scelto non la richiede;
- stop, Space, fullscreen e più monitor rispettano la specifica approvata;
- una build nativa mostra consumi a riposo entro soglie ancora da definire.

## Conseguenze

- integrazione macOS più diretta e superficie tecnica contenuta;
- nessun supporto multipiattaforma nella prima versione;
- necessità di test AppKit specifici e collaudi visivi;
- il ciclo di vita della menu bar deve essere distinto dalla visibilità transitoria
  della mascotte;
- il motore grafico resta una decisione separata dopo lo spike.

## Quando riesaminare

1. Globy deve supportare un'altra piattaforma.
2. La mascotte diventa l'esperienza primaria e la barra dei menu risulta superflua.
3. I vincoli della distribuzione scelta impediscono il comportamento della finestra.
4. Le misure dimostrano che l'implementazione nativa proposta non raggiunge i requisiti.
