# Trappole

- Aggiornato: 2026-09-16
- Vale per: tutta la repository
- Risponde a: che cosa sembra vero e non lo è

## 1. Questa non è ancora un'app

La presenza di roadmap e architettura non implica che esistano target Xcode, sorgenti,
asset o test. Verificare il disco prima di descrivere una capacità come realizzata.

## 2. SSE non consegna uno storico

Lo stream VOX corrente vive in memoria. Una riconnessione riuscita non dimostra che
nessun evento sia andato perso. Dopo ogni apertura dello stream serve un catch-up HTTP.

## 3. Il limite di 500 client è condiviso

Quel tetto viene dal codice di Chronocol, non da un header pubblico. Una utility
desktop resta collegata molto più a lungo di una pagina web. Non assumere che lo
stream attuale possa sostenere una release pubblica perché sostiene il sito.

## 4. RSS non è un registro dei cambiamenti

Il feed osservato il 2026-09-16 aveva 50 item e non esprime i ritiri. Dal codice di
Chronocol è limitato e ordinato per `createdAt`. Se l'item più vecchio è posteriore a
`lastSuccessfulSyncAt`, il buco non è coperto: serve l'elenco JSON. Una VOX assente
dal solo RSS non è un ritiro.

## 5. `documentId` non è una versione

Una VOX può essere modificata, ripubblicata o ritirata mantenendo lo stesso
identificativo. Una tabella di soli ID non basta a decidere se notificare.

## 6. Primo avvio e catch-up non sono diretta

Trattare la baseline o una riconnessione come arrivi live produce raffiche di notifiche
e animazioni. La causa della sincronizzazione deve restare disponibile alla politica.

## 7. La scomparsa della mascotte non significa chiudere Globy

La mascotte deve scomparire automaticamente dopo ogni richiamo. Visibilità della
finestra, presenza nella barra dei menu e ciclo di vita del processo sono stati
distinti. Non usare una sola variabile per tutti e tre.

## 8. Una utility solo menu bar può terminare

Il comportamento di rimozione del menu extra e quello dell'app senza icona Dock vanno
provati sul target macOS scelto. Non promettere ricezione persistente senza il test.

## 9. “In basso a destra” non è una coordinata fissa

Dock, area visibile, più monitor, ridimensionamento e coordinate AppKit cambiano il
punto corretto. Posizionare il globo con numeri riferiti allo schermo principale lo può
far apparire fuori posto o fuori schermo.

## 10. Trasparente non significa click-through

Una finestra senza sfondo può comunque intercettare input. Definire aree interattive,
trascinamento e passaggio dei clic con test espliciti.

## 11. Il 3D può consumare anche quando nulla si muove

La mascotte ferma deve sospendere rendering e timer non necessari. Misurare CPU e GPU
con Instruments; non dedurre il consumo dall'aspetto statico.

## 12. SceneKit non è la scelta predefinita

È una tecnologia deprecata per nuovi progetti. RealityKit e un rendering 2D vanno
confrontati sul caso reale prima di scegliere.

## 13. Notifica locale non significa consegna ad app terminata

Globy può programmare una notifica dopo avere osservato un contenuto. Non può osservare
nuovi contenuti mentre è terminato senza un'infrastruttura remota distinta.

## 14. Permesso notifiche negato non è un errore

È uno stato normale e reversibile dell'utente. Il menu continua a mostrare le novità e
l'app deve indicare con precisione come cambiare l'impostazione.

## 15. Firma, notarizzazione e aggiornamenti sono tre problemi

Una build notarizzata può essere difficile da aggiornare. Scegliere il canale di update
prima di chiamare completa la distribuzione.

## 16. La licenza non si presume

Repository visibile non equivale a open source. Finché non esiste `LICENSE`, non
presentare Globy come riutilizzabile e non importare asset senza provenienza.

## 17. I progetti Swift vicini non sono una libreria condivisa

Codice simile nelle altre app non costituisce un contratto. Riutilizzarlo richiede una
verifica di modelli, endpoint, errori e licenza, non un copia-incolla.

## 18. Lo schema pubblico non va copiato per intero

L'elenco VOX può contenere campi estranei al client. Metterli nello store o in
questa repository trascina dettagli di Chronocol in Globy. Servono `documentId`,
permalink, testi dell'elenco, timestamp e un'impronta di versione, non il resto.

## 19. I file di comunità non inventano un processo

README, `SECURITY.md` e `CONTRIBUTING.md` descrivono soltanto canali e procedure
che esistono oggi. Un contatto, un SLA o una issue di bug applicativo si
aggiungono quando il fatto è vero, non per completare un modello di repository.
