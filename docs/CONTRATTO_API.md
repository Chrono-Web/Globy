# Contratto Chronocol

- Aggiornato: 2026-09-16
- Stato: fotografia del servizio pubblico; non è un contratto stabile
- Risponde a: che cosa Globy può consumare oggi e quali garanzie servono per la release

## Fonti

Il contratto vive nel servizio Chronocol, non in questo documento. La superficie
pubblica è sulla stessa origine di [Chronocol](https://chronocol.com).

Questa pagina separa due tipi di fatto:

1. **Osservato in produzione** il 2026-09-16 con richieste HTTP non autenticate
   verso `https://chronocol.com`.
2. **Ricavato dal codice sorgente di Chronocol**, che non è in questa repository e
   non è pubblicato insieme a Globy. Quei dettagli restano etichettati come tali:
   un lettore di questa sola repository non può riverificarli.

Non ci sono percorsi filesystem di Chronocol da clonare insieme a Globy.

## Endpoint pubblici osservati

| Metodo | Percorso | Ruolo osservato il 2026-09-16 |
|---|---|---|
| `GET` | `/api/voxes` | Elenco JSON paginato, senza autenticazione |
| `GET` | `/api/voxes/:documentId` | Dettaglio JSON della stessa forma, senza autenticazione |
| `GET` | `/api/voxes/stream` | `text/event-stream`; primo commento `: connected` |
| `GET` | `/api/voxes/rss` | Feed RSS dei VOX, `text/xml` |
| `GET` | `/api/voxes/rss.xsl` | Foglio di stile per il browser, non dato applicativo |

Esempi di produzione:

- [`https://chronocol.com/api/voxes/rss`](https://chronocol.com/api/voxes/rss)
- `https://chronocol.com/api/voxes`
- `https://chronocol.com/api/voxes/stream`

In test e sviluppo la base URL deve restare configurabile. Globy non deve
incorporare token per queste letture.

### Elenco e dettaglio JSON

Sull'elenco, la risposta aveva forma `{ data, meta }`. `meta.pagination` riportava
`page` 1, `pageSize` 25, `pageCount` 172, `total` 4300. Ogni elemento includeva
`documentId` e timestamp. **Non** c'era un campo permalink: l'URL pubblico
osservato nel RSS ha la forma `https://chronocol.com/it/vox/{documentId}`. La
stessa forma JSON valeva per il dettaglio per `documentId`.

La paginazione accettata il 2026-09-16 usava `pagination[page]` e
`pagination[pageSize]`. I parametri `page` / `pageSize` in radice rispondevano 400.

L'ordine predefinito dell'elenco **non** è per recenza: la pagina 1 partiva
dall'inizio dell'archivio. Per il catch-up è stato osservato che
`sort=createdAt:desc` allinea la pagina 1 ai VOX più recenti, nello stesso senso
del RSS. GlobyCore richiede sempre quel sort. Non è una garanzia di contratto:
se Chronocol lo ritira, il JSON non copre più un buco in modo sicuro.

Un dettaglio inesistente rispondeva HTTP 404 con `{ data: null, error }`. Nello
spike un 404 su un `documentId` già in store è l'unico ritiro simulabile: un VOX
assente dal solo RSS non è un ritiro.

La risposta contiene anche campi che non servono a Globy. Non vanno copiati in
questa documentazione, nello store locale o nell'interfaccia: sono metadati del
servizio a monte. Il mapping del sottoinsieme minimo vive in `ChronocolClient`.

Le intestazioni delle stesse risposte esponevano un limite `180` richieste per
finestra di `60` secondi (`ratelimit-policy: 180;w=60`). Una release deve
rispettarlo e concordare con Chronocol una frequenza accettabile per un client
sempre acceso.

### Stream SSE

Osservato: `content-type: text/event-stream`, `cache-control: no-cache, no-transform`,
commento iniziale `: connected`. In otto secondi non è arrivato nessun evento
nominato: l'assenza di eventi in una finestra breve **non** dimostra che lo stream
conservi o riconsegni uno storico.

Dal codice di Chronocol, non dall'osservazione pubblica di oggi:

- eventi previsti `vox-new` (`documentId`, `createdAt`) e `vox-updated`
  (`documentId`);
- bus in memoria, senza storico;
- heartbeat come commenti SSE;
- dedupe temporaneo, non persistente;
- tetto di 500 connessioni contemporanee condivise.

Quindi un evento, anche quando arriverà, non si traduce direttamente in una
notifica. Produce sempre un catch-up HTTP.

### RSS

Osservato il 2026-09-16:

- `language` italiano;
- 50 `item` (non un tetto misurato: è il contenuto di quel momento);
- `guid` uguale al permalink pubblico (`https://chronocol.com/it/vox/…`);
- `pubDate` in ordine decrescente nei primi elementi;
- `category` presente;
- `enclosure` solo su alcuni item, non su tutti.

Dal codice di Chronocol il feed ha un tetto di 100 elementi e ordina per
`createdAt` decrescente. Non rappresenta esplicitamente ritiri o cancellazioni.

È adatto a fixture e alla lettura ordinaria di Globy. Non garantisce da solo un
recupero del buco se, da `lastSuccessfulSyncAt`, sono usciti più VOX di quanti il
feed ne tenga. In quel caso Globy pagina l'elenco JSON con `sort=createdAt:desc`,
come in
[`docs/adr/0002-http-e-autorevole-sse-e-un-segnale.md`](adr/0002-http-e-autorevole-sse-e-un-segnale.md).
Un buco profondo può avvicinarsi al limite di 180 richieste al minuto: 172 pagine
da 25 elementi coprono l'archivio osservato oggi.

## Lacune da chiudere

Per una release pubblica affidabile serve decidere con Chronocol un contratto che
risponda a queste domande:

1. Esiste un cursore monotono dei cambiamenti pubblici?
2. Come si distingue una prima pubblicazione da una ripubblicazione?
3. Come vengono rappresentati ritiri e cancellazioni?
4. Come si recuperano più di una pagina di cambiamenti?
5. Quale timestamp rappresenta davvero la pubblicazione?
6. Qual è l'ordinamento totale quando due elementi hanno lo stesso timestamp?
7. Quale compatibilità viene promessa ai client meno recenti?
8. Quale frequenza di polling è accettabile, dato il limite osservato di 180
   richieste al minuto? In attesa di risposta Globy usa un valore prudente: una
   sync ogni 5 minuti per Mac, con jitter e backoff fino a 30 minuti.

La soluzione preferibile è un feed incrementale paginato con cursore opaco e tipo di
cambiamento. Il dettaglio del VOX può restare nell'endpoint pubblico.

## Compatibilità e configurazione

- La base URL non va sparsa nel codice.
- Produzione usa HTTPS.
- Debug e test possono puntare a una fixture locale.
- Il decoder deve rifiutare in modo osservabile risposte incompatibili, senza
  cancellare lo stato locale valido.
- Una nuova versione del contratto che modifica semantica di notifica richiede
  una decisione nel servizio Chronocol, fuori da questa repository.

## Criteri di verifica

Il contratto è pronto per la release quando una suite automatica dimostra:

- baseline senza notifiche;
- evento duplicato senza notifica duplicata;
- catch-up dopo almeno 24 ore simulate;
- più pagine di cambiamenti;
- aggiornamento di elemento già letto;
- ritiro e cancellazione;
- 503 dello stream con fallback;
- risposta malformata senza perdita dello store.
