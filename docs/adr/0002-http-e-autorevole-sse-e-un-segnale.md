# 0002 — HTTP è autorevole e SSE è un segnale

- Stato: proposto
- Data: 2026-09-16
- Proprietario: progetto Globy
- Vincolante per: rete, sincronizzazione, notifiche, stato locale
- Nasce da: verifica dello stream VOX esistente il 2026-09-16
- Sostituisce: nulla

## Contesto

Chronocol espone uno stream SSE pubblico a bassa latenza, ma il bus è in memoria, non
conserva eventi persi e limita a 500 le connessioni contemporanee. Il payload contiene
un identificativo e invita il client a rileggere il contenuto. Il frontend Chronocol
esistente esegue già un catch-up quando si collega o torna visibile.

Un'app desktop può restare connessa per molte ore e attraversa normalmente stop, cambio
rete e deploy. Trattare lo stream come coda affidabile produrrebbe perdite silenziose;
usarlo come unico trasporto consumerebbe inoltre il limite condiviso.

## Decisione

La lettura HTTP e il confronto con lo stato locale sono la fonte autorevole. SSE è un
segnale facoltativo che richiede una sincronizzazione e riduce la latenza quando
disponibile.

Primo avvio, apertura dello stream, riconnessione, risveglio e ritorno online eseguono
un catch-up idempotente. La perdita o il rifiuto dello stream degrada a polling con
backoff, non a uno stato di errore permanente.

Una release ampia resta bloccata finché frequenza HTTP e scalabilità dello stream non
sono state concordate e provate con Chronocol.

## Come si verifica

- la suite passa con SSE completamente disabilitato;
- duplicare o riordinare eventi SSE non duplica notifiche;
- una sequenza persa viene recuperata dal catch-up;
- un 503 dello stream attiva il fallback senza loop di connessioni;
- più risvegli ravvicinati producono una sola sincronizzazione in volo;
- una prova di carico misura l'effetto combinato di sito e client desktop.

## Conseguenze

- correttezza indipendente dalla connessione persistente;
- maggiore complessità nel coordinatore e nello store locale;
- serve un contratto incrementale HTTP migliore dell'RSS per garantire recuperi lunghi;
- la notifica può arrivare più tardi quando SSE non è disponibile;
- la mascotte reagisce allo stato confermato, non al pacchetto ricevuto.

## Quando riesaminare

1. Chronocol espone un registro durevole con cursore o replay SSE.
2. Viene introdotto APNs con garanzie e semantica documentate.
3. Il limite o l'architettura dello stream cambia.
4. Il polling concordato produce carico o latenza non accettabili.
