# Spike della mascotte (2D)

- Aggiornato: 2026-09-16
- Stato: prototipo usa e getta, non è il progetto dell'app
- Risponde a: il globo 2D disegnato in SwiftUI funziona come mascotte transitoria?

Non contiene sincronizzazione: la VOX si simula dal menu. Il globo è disegnato dal
codice, quindi non ci sono asset da registrare in `docs/ASSET.md`.

## Uso

```bash
cd Spikes/MascotSpike
swift run MascotSpike            # icona nella barra dei menu → "Simula nuova VOX" (⌘N)
swift run MascotSpike --demo     # richiamo automatico dopo 1 s
swift run MascotSpike --snapshot globo.png   # esporta il disegno senza finestre
```

## Che cosa prova

- `NSPanel` trasparente e non attivante: non ruba il focus.
- Presente su tutti gli Space e sopra le app a schermo intero.
- Angolo inferiore destro della `visibleFrame` dello schermo col puntatore (Dock escluso).
- Click-through attivo; disattivandolo dal menu il globo si può trascinare.
- Entrata a molla del globo, poi fumetto sopra con la VOX di esempio (fixture scritta a
  mano) che si scrive carattere per carattere. Gli occhi seguono il carattere appena
  scritto (posizione calcolata con TextKit), poi guardano chi osserva per 1,2 s e tornano
  al puntatore. Il fumetto resta 6 s dopo la lettura; un nuovo richiamo ricomincia.
- Sfera scura con 3 paralleli, 3 meridiani e due occhi a trattino, tutti solidali:
  nessuna rotazione automatica, la "testa" si orienta verso il puntatore. Battito di
  ciglia, a volte doppio. Niente bocca né continenti.
- "Sempre presente" dal menu: il globo resta a schermo (preferenza ricordata tra un
  avvio e l'altro); una nuova VOX lo fa salutare con un doppio battito.
- Il render loop si accende solo quando serve (puntatore in movimento, battito di ciglia)
  e si spegne da fermo, anche con il globo sempre presente.
- Paralleli e meridiani come tubicini in rilievo: nastri costruiti sulla sfera 3D e
  proiettati, che si assottigliano e scompaiono dietro il bordo senza tagli.
- Menu "Superficie": Scura, Liquid Glass, Liquid Glass trasparente (`NSGlassEffectView`,
  macOS 26) e Vetro smerigliato (`NSVisualEffectView` dietro la finestra), con una
  velatura scura che tiene leggibili gli occhi. Aspetto da valutare dal vivo.
- Reduce Motion: solo dissolvenza, niente rotazione né oscillazione.

## Verificato

- Compila con Swift 6.3.3 su macOS 26 (arm64).
- `--snapshot` produce il disegno atteso.
- Misure con `top` sulla build release, globo sempre presente e mouse fermo (non
  Instruments): 0–2% CPU, con brevi picchi fino a circa 6% durante i battiti di ciglia.
  Durante la scrittura della VOX (circa 7 s): 10–21%. Non misurato mentre il mouse
  si muove.

Da provare a mano: più monitor, fullscreen, Reduce Motion, CPU e GPU durante
l'animazione e confronto con RealityKit.
