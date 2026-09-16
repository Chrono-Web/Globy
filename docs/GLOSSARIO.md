# Glossario

- Aggiornato: 2026-09-16
- Risponde a: che cosa significano i termini usati da prodotto, codice e test

| Termine | Significato in Globy |
|---|---|
| **Globy** | L'app macOS nel suo insieme, non soltanto la mascotte |
| **mascotte** | La rappresentazione facoltativa del globo sul desktop |
| **VOX** | Unità pubblica di contenuto Chronocol: notizia verificata con fonti e metadati |
| **baseline** | Stato osservato al primo avvio; non genera notifiche retroattive |
| **catch-up** | Sincronizzazione autorevole dopo avvio, riconnessione, risveglio o ritorno online |
| **lastSuccessfulSyncAt** | Istante dell'ultimo catch-up riuscito; il buco da coprire parte da lì |
| **diretta** | Cambiamento confermato mentre Globy era connesso; non è sinonimo di evento SSE |
| **hint** | Segnale non autorevole, per esempio SSE, che richiede un catch-up |
| **saluto** | Prima apparizione della mascotte al primo avvio; non è una VOX |
| **onboarding** | Spiegazione al primo avvio dell'app: cosa legge, baseline, notifiche |
| **letto** | Contenuto che la persona ha esplicitamente aperto o marcato come letto |
| **notificato** | Contenuto per cui Globy ha già programmato o mostrato un avviso |
| **ritirato** | Contenuto prima disponibile che la fonte autorevole non considera più pubblico |
| **riepilogo** | Un solo avviso che rappresenta più arrivi recuperati insieme |
| **store locale** | Persistenza sul Mac di contenuti osservati, cursore e stati utente |
| **stream** | Connessione SSE pubblica di Chronocol; non è una coda durevole |
| **polling** | Lettura HTTP periodica usata anche come fallback dello stream |

`documentId` identifica una VOX, ma non una versione immutabile della VOX. “Nuovo”,
“aggiornato”, “letto” e “notificato” non devono essere compressi in un solo booleano.
