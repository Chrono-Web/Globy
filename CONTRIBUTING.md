# Contribuire a Globy

Globy è in pre-alpha e non accetta ancora contributi di codice: manca una licenza e non
esiste un progetto compilabile. Issue che correggono fatti, chiariscono requisiti o
mettono in discussione una decisione proposta sono invece benvenute.

Questa limitazione verrà rimossa soltanto dopo la scelta della licenza e la creazione
del progetto Xcode.

## Prima di iniziare

1. Leggi `AGENTS.md`, `docs/PRODOTTO.md` e `docs/TRAPPOLE.md`.
2. Verifica che il lavoro appartenga al perimetro della prima versione.
3. Per cambi architetturali, proponi o aggiorna un ADR prima di costruire molto codice.
4. Una modifica al contratto delle API pubbliche si decide nel servizio Chronocol,
   che non è questa repository. Qui non è documentato un canale pubblico per
   proporre quel cambiamento.

## Pull request dei manutentori

Finché i contributi esterni sono sospesi, queste regole valgono per il lavoro dei
manutentori. Una pull request dovrebbe:

- avere un obiettivo solo e una motivazione leggibile;
- descrivere come è stata verificata;
- aggiornare documentazione e roadmap soltanto quando cambia la realtà;
- non includere segreti, database reali o asset senza licenza nota.

Quando esiste codice, deve anche includere test per la logica modificata e non
dipendere da credenziali o produzione per i test automatici.

Usa `[~]` per lavoro costruito ma non collaudato e `[x]` soltanto quando il criterio
documentato è stato realmente verificato.

## Stile

- Documentazione e testo dell'interfaccia in italiano.
- Identificatori Swift in inglese chiaro e coerente con le API Apple.
- Dipendenze nuove motivate: per una libreria che vincola architettura o distribuzione
  può servire un ADR.
- Nessun accesso di rete diretto dalle view.
- Nessun tempo, clock o casualità globale nella logica che deve essere testata.

## Issue

Per correzioni e proposte usa i template in `.github/ISSUE_TEMPLATE/`. Oggi
servono a errori documentali e a proposte di perimetro, non a bug di un'app
inesistente. Per questioni di sicurezza segui `SECURITY.md`.

## Licenza

La licenza non è ancora stata scelta. Fino alla presenza di un file `LICENSE`, non
inviare contributi di codice o asset e non presumere che i contenuti siano disponibili
per redistribuzione.
