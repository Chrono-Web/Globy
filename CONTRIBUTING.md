# Contribuire a Globy

Globy è nella fase iniziale: prima di proporre codice, controlla la roadmap e gli ADR
proposti. Una modifica tecnicamente valida può essere prematura se anticipa una
decisione ancora aperta.

## Prima di iniziare

1. Leggi `AGENTS.md`, `docs/PRODOTTO.md` e `docs/TRAPPOLE.md`.
2. Verifica che il lavoro appartenga al perimetro della prima versione.
3. Per cambi architetturali, proponi o aggiorna un ADR prima di costruire molto codice.
4. Per cambi al contratto Chronocol, coordina una decisione nel progetto Chronocol.

## Pull request

Una pull request dovrebbe:

- avere un obiettivo solo e una motivazione leggibile;
- descrivere come è stata verificata;
- includere test per la logica modificata;
- non dipendere da credenziali o produzione per i test automatici;
- aggiornare documentazione e roadmap soltanto quando cambia la realtà;
- non includere segreti, database reali o asset senza licenza nota.

Usa `[~]` per lavoro costruito ma non collaudato e `[x]` soltanto quando il criterio
documentato è stato realmente verificato.

## Stile

- Documentazione e testo dell'interfaccia in italiano.
- Identificatori Swift in inglese chiaro e coerente con le API Apple.
- Dipendenze nuove motivate: per una libreria che vincola architettura o distribuzione
  può servire un ADR.
- Nessun accesso di rete diretto dalle view.
- Nessun tempo, clock o casualità globale nella logica che deve essere testata.

## Segnalazioni

Per bug e proposte usa i template in `.github/ISSUE_TEMPLATE/`. Per vulnerabilità non
aprire una issue pubblica: segui `SECURITY.md`.

## Licenza

La licenza non è ancora stata scelta. Fino alla presenza di un file `LICENSE`, non
presumere che contributi, codice o asset siano disponibili per redistribuzione.
