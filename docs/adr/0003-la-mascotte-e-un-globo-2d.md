# 0003 — La mascotte è un globo 2D, non RealityKit

- Stato: accettato
- Data: 2026-09-16
- Accettato: 2026-09-16
- Proprietario: progetto Globy
- Vincolante per: mascotte, spike grafico, futura shell macOS
- Nasce da: spike in `Spikes/MascotSpike/` e collaudo visivo sullo stesso comportamento
- Sostituisce: nulla (chiude il punto lasciato aperto dall'ADR 0001 sul motore grafico)

## Contesto

La mascotte è un globo transitorio in basso a destra, con fumetto, occhi solidali e
vetro di sistema. Lo spike ha messo a confronto due renderer nello stesso eseguibile:
Canvas/SwiftUI (2D) e RealityKit (`ARView` su macOS), stesso corpo visivo (sfera,
paralleli, meridiani, occhi a trattino, niente continenti).

Il criterio di scelta, chiuso prima del confronto, era: stesso comportamento; se
RealityKit fatica su qualità, trasparenza, buchi di clic o Reduce Motion, vince il 2D.

Il 2026-09-16 una revisione umana ha provato entrambi i motori. RealityKit è risultato
inaccettabile visivamente. Il 2D resta leggibile, allineato al vetro nativo e già in
grado di sospendere il render loop da fermo.

RealityKit su macOS, nello spike, non esponeva `isPaused`: per non lasciare un loop
acceso si staccava la vista dopo un fotogramma congelato. Quel compromesso non ha
recuperato la qualità.

## Decisione

Il globo si disegna in 2D (SwiftUI `Canvas` e geometria proiettata). RealityKit non
entra nella prima versione. SceneKit resta escluso, come già in `docs/TRAPPOLE.md`.

Il vetro (Liquid Glass su macOS 26, smerigliato sotto) resta un adattatore AppKit
dietro il disegno, non un materiale RealityKit.

## Come si verifica

- lo spike compila e mostra il globo 2D senza dipendere da RealityKit;
- `--snapshot` esporta il disegno 2D atteso;
- una build senza `import RealityKit` nel percorso della mascotte.

Non si rinvia la scelta a una campagna Instruments su RealityKit: la qualità visiva
l'ha già escluso. I consumi a riposo del 2D restano da sogliare in fase 2/3 con
Instruments sulla mascotte nascosta.

## Conseguenze

- niente runtime 3D nel processo della mascotte;
- continenti 3D «veri» restano fuori dalla prima versione;
- l'app futura può riprendere il Canvas dello spike, non l'`ARView`;
- un eventuale ritorno a RealityKit richiede un ADR nuovo e un confronto alla pari.

## Quando riesaminare

1. Il 2D non raggiunge le soglie energetiche o di accessibilità della release.
2. Un nuovo spike RealityKit, sullo stesso comportamento, supera visivamente il 2D
   senza rompere trasparenza, buchi di clic e Reduce Motion.
3. La mascotte diventa un oggetto 3D permanente, contro il brief transitorio.
