# Asset e attribuzioni

- Aggiornato: 2026-09-17
- Stato: nessun file grafico in repository; politica scelta
- Risponde a: da dove provengono grafica, font, suoni e modelli e come possono essere usati

## Regola

Ogni asset non creato interamente per Globy deve essere registrato qui prima di entrare
in una build distribuibile. Una URL di download non è una licenza.

Codice e asset originali di Globy sono GNU GPL versione 3, come `LICENSE`. Un asset di
terzi entra solo con una licenza compatibile e riga in questa tabella.

## Stato attuale

Non sono presenti grafica, font, suoni o modelli. Il globo (spike e app) è disegnato dal
codice, quindi non c'è un file da registrare. Quando verrà aggiunto il primo asset, la
sezione registro diventa una tabella con file, autore, fonte, licenza, modifiche e
attribuzione richiesta.

## Chronocol

Globy è il compagno ufficiale macOS di Chronocol. Può usare nome e identità Chronocol
in interfaccia, README e sito per presentarsi come tale e per aprire i permalink
pubblici. Non è una licenza sul codice di Chronocol e non autorizza a copiare il sito.

## Categorie da controllare

- modello o mesh del globo;
- texture della Terra e dati cartografici;
- occhi, espressioni e animazioni;
- icona dell'app e della barra dei menu;
- font non di sistema;
- suoni;
- immagini usate in README, sito o release;
- marchi, nome e identità visiva Chronocol.

Gli asset generati con strumenti AI richiedono comunque provenienza, condizioni d'uso
del servizio e verifica di eventuali somiglianze o marchi. Devono poter essere
rilasciati sotto GPL-3 insieme al resto, altrimenti non entrano.

## Prima della release

- [ ] Ogni file in bundle compare nel registro o è chiaramente prodotto dal codice.
- [ ] Le attribuzioni richieste sono incluse nell'app o nel pacchetto.
- [ ] L'uso del marchio Chronocol resta quello dichiarato sopra.
- [ ] I file sorgente necessari a modificare gli asset sono archiviati dove previsto.
- [ ] Non esistono placeholder o asset di test nella build stabile.
