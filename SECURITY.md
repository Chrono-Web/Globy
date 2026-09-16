# Sicurezza

## Stato

Questa repository contiene soltanto documentazione: non esistono codice eseguibile,
binari o versioni supportate. Non c'è una superficie applicativa di Globy su cui
promettere correzioni, tempi di risposta o un programma di bug bounty.

Al 2026-09-16 non è abilitato un canale privato di segnalazione su questa
repository e non è pubblicato un indirizzo di sicurezza dedicato.

## Segnalare un problema

Non aprire una issue pubblica con dettagli sfruttabili, token, dati personali o
output sensibile.

- Per un errore nei documenti di Globy, senza payload sfruttabile, usa i template
  in `.github/ISSUE_TEMPLATE/`.
- Se stai revisionando una modifica non ancora pubblicata, contatta chi te l'ha
  data con lo stesso canale già usato per quella revisione.
- Per i servizi Chronocol già online: il 2026-09-16 `https://chronocol.com` non
  esponeva un `security.txt` né una pagina di contatto di sicurezza distinguibile
  da un'applicazione a pagina singola. Questa repository non è il canale di
  Chronocol e non lo sostituisce.

Quando Globy conterrà codice, questa pagina verrà aggiornata soltanto dopo che il
canale privato sarà davvero disponibile sulla piattaforma che ospita la
repository. Fino ad allora non promettere GitHub Security Advisories, caselle
`security@` o SLA.

Una segnalazione utile contiene:

- versione o commit interessato;
- impatto osservato;
- passaggi minimi per riprodurre;
- eventuale mitigazione;
- conferma che non sono stati inclusi segreti reali.

## Ambito previsto

Sono particolarmente rilevanti, quando esisterà codice:

- esecuzione di contenuti non fidati provenienti dalle VOX;
- apertura di URL non validati;
- esposizione di token o configurazioni di firma;
- scrittura o lettura oltre il contenitore previsto dell'app;
- aggiornamenti non firmati o feed di update manomettibile;
- dati locali leggibili da processi non autorizzati;
- uso di endpoint editoriali senza autorizzazione.

Le sole letture di contenuti pubblici non giustificano l'inserimento di
credenziali nel bundle. Questa sezione descrive rischi da verificare durante lo
sviluppo, non problemi già presenti.
