# Sicurezza

## Versioni supportate

Globy non ha ancora rilasci pubblici. Questa politica verrà aggiornata prima della
prima beta distribuibile.

## Segnalare una vulnerabilità

Non aprire una issue pubblica con dettagli sfruttabili, token, dati personali o output
sensibile. Contatta privatamente il responsabile del progetto attraverso il canale di
sicurezza che verrà pubblicato prima della prima release.

Al momento manca ancora un indirizzo pubblico dedicato. Se scopri un problema durante
lo sviluppo interno, usa il canale privato già concordato dal gruppo e includi:

- versione o commit interessato;
- impatto osservato;
- passaggi minimi per riprodurre;
- eventuale mitigazione;
- conferma che non sono stati inclusi segreti reali.

## Ambito iniziale

Sono particolarmente rilevanti:

- esecuzione di contenuti non fidati provenienti dalle VOX;
- apertura di URL non validati;
- esposizione di token o configurazioni di firma;
- scrittura o lettura oltre il contenitore previsto dell'app;
- aggiornamenti non firmati o feed di update manomettibile;
- dati locali leggibili da processi non autorizzati;
- uso di endpoint editoriali senza autorizzazione.

Le sole letture di contenuti pubblici non giustificano l'inserimento di credenziali nel
bundle.
