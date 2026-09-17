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
- Saluto di rientro a ogni avvio e risveglio: «non ti sei perso nulla» o i VOX
  nuovi dietro la freccia.
- Al primo avvio il globo chiede se mostrare gli ultimi 5 VOX pubblicati («Sì, partiamo»
  / «No, grazie»); la fixture Debug ha 6 VOX per provarlo.
- Il fumetto resta a schermo in base alla lunghezza del testo, non più 6 s fissi.
- Impostazioni «Dimensioni personalizzate» per testo e pulsanti del fumetto, con
  anteprima dal vivo sul globo.
- La Release legge Chronocol pubblico (solo GET); «Simula…» resta nella Debug.
- L'archivio del primo avvio non conta più tra i non letti.
- Fumetto, menu e banner mostrano i VOX senza fonti e link, con il testo intero
  (limite di sicurezza a 16 righe).
- Onboarding raccontato da Globy: presentazione, menu, Impostazioni, poi i 5 VOX recenti.
- Globy più piccolo di default (70 pt di disco); i VOX in sequenza vanno sempre dal
  più vecchio al più recente.
- DMG con finestra curata (sfondo, freccia, icone) e istruzioni di installazione e
  disinstallazione (`scripts/crea-dmg.sh`).
- Icona dell’app: il globo di Globy in vetro trasparente su sfondo azzurro.
- «Preferenze» diventano «Impostazioni», con «Disinstalla Globy…» in fondo.
- Una sola copia di Globy alla volta. Fase 3 chiusa dopo il collaudo umano.
- Clic destro su Globy: «Impostazioni…» e «Nascondi Globy». Feedback aptico sui cursori
  delle dimensioni.
- Impostazioni riorganizzate: sezione Globy (mostra sempre, login, suono), grandezza di
  Globy tra le dimensioni, «Notifiche di sistema» come modalità al posto di Globy.
- Checklist di collaudo della fase 3 in `docs/COLLAUDO_FASE3.md`.
- Controllo periodico ogni 5 minuti mentre il Mac è acceso, con backoff sugli errori
  e sync immediata al ritorno della rete.
- Licenza GNU GPL versione 3.
- Fase 0 chiusa: macOS 15, `com.chronocol.globy`, GitHub non firmato, ADR 0001 e 0002 accettati.
- Spike di sincronizzazione in `Packages/GlobyCore/`: baseline, catch-up, hint SSE e
  suite di 29 test senza rete.
- Spike mascotte 2D: coda, permanenza, frecce di coda, saluto di primo avvio
  (fessura arcuata, non è un VOX). RealityKit scartato (ADR 0003). Fase 2 chiusa.
- Store locale JSON dietro `ContentStore` (ADR 0004), con test di round-trip.
- App macOS (`Globy.xcodeproj`): barra dei menu, store JSON, saluto, preferenze,
  notifiche locali senza suono e mascotte sulle fixture in processo. Fase 3 `[~]`.

### Corretto

- File di comunità e contratto API allineati a ciò che esiste oggi: niente canali,
  SLA o bug di un'app inesistente.
- Spike mascotte: globo e fumetto restano nella `visibleFrame`; il fumetto si
  centra sopra il globo e passa sotto se in alto non c'è spazio. Comparsa e
  scomparsa non spostano più il globo.
