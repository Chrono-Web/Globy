# 0002 — HTTP è autorevole e SSE è un segnale

- Stato: accettato
- Data: 2026-09-16
- Accettato: 2026-09-16
- Proprietario: progetto Globy
- Vincolante per: rete, sincronizzazione, notifiche, stato locale
- Nasce da: verifica dello stream VOX esistente il 2026-09-16 e scelta del catch-up
- Sostituisce: nulla

## Contesto

Chronocol espone uno stream SSE pubblico a bassa latenza. Il 2026-09-16
`https://chronocol.com/api/voxes/stream` rispondeva `text/event-stream` con il
commento `: connected` e, in una finestra breve, senza eventi nominati.

Dal codice di Chronocol, non dall'osservazione pubblica di quella finestra, il bus
è in memoria, non conserva eventi persi e limita a 500 le connessioni contemporanee.
Il payload previsto contiene un identificativo e invita il client a rileggere il
contenuto. Il frontend Chronocol esistente esegue già un catch-up quando si collega
o torna visibile.

Un'app desktop può restare connessa per molte ore e attraversa normalmente stop, cambio
rete e deploy. Trattare lo stream come coda affidabile produrrebbe perdite silenziose;
usarlo come unico trasporto consumerebbe inoltre il limite condiviso.

Globy non è un browser dell'archivio: mostra le VOX recenti e, al massimo, quelle
pubblicate da quando ha sincronizzato l'ultima volta. Il feed RSS pubblico è corto
(osservati 50 item; tetto 100 nel codice Chronocol) e non esprime i ritiri. L'elenco
JSON è paginato e copre l'archivio.

## Decisione

La lettura HTTP e il confronto con lo stato locale sono la fonte autorevole. SSE è un
segnale facoltativo che richiede una sincronizzazione e riduce la latenza quando
disponibile.

Il cursore locale è `lastSuccessfulSyncAt`: l'istante dell'ultimo catch-up riuscito.
Copre avvio, stop, crash e Mac in sleep meglio di un diario accensione/spegnimento.

Al risveglio Globy chiede le VOX con pubblicazione successiva a `lastSuccessfulSyncAt`:

1. legge il RSS;
2. se l'item più vecchio del feed è anteriore o uguale a `lastSuccessfulSyncAt` (o
   il feed si sovrappone a VOX già in store), il buco è coperto dal RSS;
3. altrimenti pagina l'elenco JSON finché non supera quell'orario;
4. se non c'è nulla di nuovo, mostra l'ultima VOX già nota in locale, o l'ultima del
   feed se lo store è vuoto.

Il primo avvio costruisce la baseline dalle VOX recenti (il RSS basta) e non notifica
l'archivio.

Primo avvio, apertura dello stream, riconnessione, risveglio e ritorno online eseguono
un catch-up idempotente. La perdita o il rifiuto dello stream degrada a polling con
backoff, non a uno stato di errore permanente.

Una release ampia resta bloccata finché frequenza HTTP e scalabilità dello stream non
sono state concordate e provate con Chronocol.

## Come si verifica

- la suite passa con SSE completamente disabilitato;
- duplicare o riordinare eventi SSE non duplica notifiche;
- una sequenza persa viene recuperata dal catch-up;
- un RSS che copre `lastSuccessfulSyncAt` non provoca letture JSON;
- un RSS il cui item più vecchio è posteriore a `lastSuccessfulSyncAt` pagina il JSON
  fino a coprire il buco;
- un 503 dello stream attiva il fallback senza loop di connessioni;
- più risvegli ravvicinati producono una sola sincronizzazione in volo;
- una prova di carico misura l'effetto combinato di sito e client desktop.

## Conseguenze

- correttezza indipendente dalla connessione persistente;
- maggiore complessità nel coordinatore e nello store locale;
- il RSS è la lettura ordinaria; il JSON è la rete di sicurezza quando il feed non
  arriva indietro abbastanza;
- una VOX sparita dal solo RSS non è un ritiro: può essere soltanto uscita dalla
  finestra corta del feed;
- la notifica può arrivare più tardi quando SSE non è disponibile;
- la mascotte reagisce allo stato confermato, non al pacchetto ricevuto.

## Quando riesaminare

1. Chronocol espone un registro durevole con cursore o `since=`.
2. Viene introdotto APNs con garanzie e semantica documentate.
3. Il limite o l'architettura dello stream cambia.
4. Il polling concordato produce carico o latenza non accettabili.
5. Il tetto del RSS diventa insufficiente per i buchi reali osservati.
