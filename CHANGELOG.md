# Changelog

Le modifiche rilevanti a Globy sono registrate qui. Non c'è ancora un
versionamento pubblico.

## Non rilasciato

### Aggiunto

- Fondazione documentale del progetto.
- Brief di prodotto, architettura e contratto API osservato.
- Regole per agenti, contributi, sicurezza, privacy e distribuzione.
- Roadmap verificabile e registro delle decisioni architetturali.
- Spike usa e getta della mascotte 2D in `Spikes/MascotSpike/`.
- Licenza GNU GPL versione 3.
- Fase 0 chiusa: macOS 15, `com.chronocol.globy`, GitHub non firmato, ADR 0001 e 0002 accettati.
- Spike di sincronizzazione in `Packages/GlobyCore/`: baseline, catch-up, hint SSE e
  suite di 26 test senza rete.
- Spike mascotte 2D: coda, permanenza, frecce di coda, saluto di primo avvio
  (fessura arcuata, non è una VOX). RealityKit scartato (ADR 0003). Fase 2 chiusa.
- Store locale JSON dietro `ContentStore` (ADR 0004), con test di round-trip.

### Corretto

- File di comunità e contratto API allineati a ciò che esiste oggi: niente canali,
  SLA o bug di un'app inesistente.
- Spike mascotte: globo e fumetto restano nella `visibleFrame`; il fumetto si
  centra sopra il globo e passa sotto se in alto non c'è spazio. Comparsa e
  scomparsa non spostano più il globo.
