# Spike della mascotte (2D)

- Aggiornato: 2026-09-17
- Stato: prototipo usa e getta; il motore è il 2D (ADR 0003)
- Risponde a: il globo Canvas funziona come mascotte transitoria?

Non contiene sincronizzazione: la VOX si simula dal menu. Il globo è disegnato dal
codice, quindi non ci sono asset da registrare in `docs/ASSET.md`. Il suono è
`Tink` di sistema. RealityKit è stato provato e rimosso dopo il collaudo visivo.

## Uso

```bash
cd Spikes/MascotSpike
swift run MascotSpike                         # menu: Simula nuova VOX (⌘N), raffica (⌘B), Saluta (⌘G)
swift run MascotSpike --demo                  # un richiamo dopo 1 s
swift run MascotSpike --burst                 # coda di 3 VOX
swift run MascotSpike --greet                 # saluto, anche se già visto
swift run -c release MascotSpike --demo       # per Instruments
swift run MascotSpike --snapshot globo.png    # esporta il disegno senza finestre
./watch                                       # ricompila e riapre a ogni salvataggio (serve watchexec)
```

Menu: Superficie, Permanenza, Click-through (buchi), Suono, Ricarica alle modifiche.
Al primo avvio dello spike (senza `--demo`/`--burst`/`--snapshot`) parte il saluto;
poi restano ⌘G. «Ricarica alle modifiche» (o `./watch`) ricompila e riapre col
saluto a ogni cambio nei sorgenti, così non serve uscire e rilanciare a mano.

## Comportamento

- Transitoria: compare, legge, scompare.
- Schermo del puntatore, angolo inferiore destro della `visibleFrame`, margine 16 pt.
  Globo e fumetto restano interamente visibili: il fumetto sta sopra e centrato
  sul globo se c'è spazio, sotto se il globo è in alto, e si sposta dal bordo
  invece di uscire dallo schermo.
- Tutti gli Space, sopra il fullscreen.
- Fumetto con scrittura carattere per carattere; Reduce Motion: fade, testo già
  scritto, niente suono.
- Coda: un globo; in basso a destra si va avanti, in basso a sinistra si torna
  indietro. Senza permanenza, dopo la lettura c'è una pausa di 1 s e poi la
  VOX seguente.
- Clic su globo o fumetto: apre la VOX visibile su Chronocol.
- X: chiude solo il fumetto, mai il globo.
- Frecce in basso (stessa distanza dagli angoli che ha la X in alto a destra):
  successiva e precedente; i numeretti sono quante VOX ci sono da quella parte.
- Saluto (⌘G): fumetto «Ciao, sono Globy…», occhi chiusi come a metà battito,
  sguardo verso chi guarda; non è una VOX e non apre Chronocol. Al primo avvio
  dello spike parte da solo.
- Trascinabile mentre è visibile; globo e fumetto non escono dalla `visibleFrame`.
  Al richiamo successivo torna in basso a destra.
- Menu Permanenza: il globo resta a schermo, anche senza fumetto; X e frecce
  non lo nascondono. Senza permanenza, un trascinamento aggiunge 5 s e poi
  scompare anche il globo.
- Superficie di default: Liquid Glass su macOS 26, vetro smerigliato sotto.

## Verificato

- Compila debug e release con Swift 6.3.3 su macOS 26 (arm64), macOS 15 come minimo.
- `--snapshot` produce il disegno 2D atteso.
- RealityKit scartato visivamente il 2026-09-16 (ADR 0003).
- Collaudo umano: occhi, trascinamento, Space, fullscreen, scomparsa automatica.

Il multi-monitor non è stato provato e non è un gate. Reduce Motion e Instruments
restano da sogliare in release.
