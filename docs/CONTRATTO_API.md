# Contratto Chronocol

- Aggiornato: 2026-09-16
- Stato: fotografia verificata del servizio attuale; non è ancora un contratto stabile
- Risponde a: che cosa Globy può consumare oggi e quali garanzie servono per la release

## Fonti autorevoli

Il contratto vive nel progetto Chronocol, non in questo documento. Al momento della
verifica le fonti erano:

- `BACKEND/docs/API_SURFACE.md` per superficie e autenticazione;
- `BACKEND/src/api/vox/routes/01-custom-vox.ts` per le rotte;
- `BACKEND/src/api/vox/services/voxStream.ts` per la semantica SSE;
- `BACKEND/src/api/vox/services/voxRss.ts` per RSS;
- `FRONTEND/src/services/voxStreamService.js` per il comportamento client esistente.

Questi percorsi appartengono a un'altra repository e sono riportati per rintracciabilità,
non come dipendenze filesystem di Globy.

## Endpoint pubblici osservati

| Metodo | Percorso | Ruolo |
|---|---|---|
| `GET` | `/api/voxes` | CRUD pubblico Strapi, con query di paginazione e populate |
| `GET` | `/api/voxes/:documentId` | Dettaglio pubblico, secondo permessi Strapi |
| `GET` | `/api/voxes/stream` | Segnale SSE di pubblicazione o cambiamento |
| `GET` | `/api/voxes/rss` | Feed RSS delle VOX pubblicate |
| `GET` | `/api/voxes/rss.xsl` | Presentazione browser del feed, non dato applicativo |

Le rotte stream e RSS sono intenzionalmente senza autenticazione. Globy non deve
incorporare token per leggerle.

## Stream SSE

Eventi osservati:

| Evento | Payload | Significato sicuro |
|---|---|---|
| `vox-new` | `{ documentId, createdAt }` | Qualcosa relativo alla pubblicazione è cambiato; sincronizzare |
| `vox-updated` | `{ documentId }` | Rileggere la VOX; potrebbe essere cambiata, ritirata o cancellata |

Lo stream:

- è tenuto in memoria da una singola istanza;
- non conserva uno storico;
- manda heartbeat come commenti SSE;
- applica dedupe temporaneo, non persistente;
- ha un tetto di 500 connessioni contemporanee condivise;
- può perdere eventi durante disconnessioni, deploy e stop del Mac.

Quindi un evento non si traduce direttamente in una notifica. Produce sempre un
catch-up HTTP.

## RSS

Il feed osservato:

- usa italiano come locale predefinita;
- contiene al massimo 100 elementi;
- usa il permalink pubblico come `guid`;
- ordina per `createdAt` decrescente;
- include descrizione, categorie e prima immagine disponibile;
- non rappresenta esplicitamente ritiri o cancellazioni.

È adatto a fixture e prototipi. Non garantisce un recupero incrementale completo.

## Lacune da chiudere

Per una release pubblica affidabile serve decidere con Chronocol un contratto che
risponda a queste domande:

1. Esiste un cursore monotono dei cambiamenti pubblici?
2. Come si distingue una prima pubblicazione da una ripubblicazione?
3. Come vengono rappresentati ritiri e cancellazioni?
4. Come si recuperano più di 100 cambiamenti?
5. Quale timestamp rappresenta davvero la pubblicazione?
6. Qual è l'ordinamento totale quando due elementi hanno lo stesso timestamp?
7. Quale compatibilità viene promessa ai client meno recenti?
8. Quale frequenza di polling è accettabile?

La soluzione preferibile è un feed incrementale paginato con cursore opaco e tipo di
cambiamento. Il dettaglio della VOX può restare nel CRUD pubblico.

## Compatibilità e configurazione

- La base URL non va sparsa nel codice.
- Produzione usa HTTPS.
- Debug e test possono puntare a una fixture locale.
- Il decoder deve rifiutare in modo osservabile risposte incompatibili, senza cancellare
  lo stato locale valido.
- Una nuova versione del contratto che modifica semantica di notifica richiede un ADR
  condiviso nel progetto Chronocol.

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
