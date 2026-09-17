# Contribuire a Globy

Globy è in pre-alpha. La licenza è GNU GPL versione 3. I contributi esterni di
codice sono chiusi: il progetto è piccolo e per ora non servono (decisione del
2026-09-17, dopo la chiusura della fase 3). Issue che correggono fatti, chiariscono requisiti o mettono
in discussione una decisione sono benvenute.

`Packages/GlobyCore/` è verificabile con `swift test --package-path Packages/GlobyCore`.
L'app: `xcodebuild -project Globy.xcodeproj -scheme Globy -destination 'platform=macOS' test`.

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

Per problemi, correzioni e proposte usa i template in `.github/ISSUE_TEMPLATE/`.
Come segnalare un problema dell'app: `docs/SEGNALARE.md`. Per questioni di sicurezza
segui `SECURITY.md`.

## Licenza

Codice e asset originali sono GNU GPL versione 3. Vedi `LICENSE`. Non inviare file
con una licenza incompatibile.
