// Misure di Globy e del fumetto: porting di `MascotMetrics`, `MascotLayout`, `VoxLayout`
// e `VoxCornerButton`. Coordinate logiche, asse y verso il basso.

export const metrics = { textScale: 1, buttonScale: 1, globeScale: 1 };

export const size = {
  /** Misure standard (100%): 96 pt di area e 70 pt di disco. */
  get globeArea() { return 96 * metrics.globeScale; },
  get globeDrawn() { return 70 * metrics.globeScale; },
  cardGap: 10,
  margin: 16,
  get cardWidth() { return 330 * metrics.textScale; },
  get padding() { return 14 * metrics.textScale; },
  get headerHeight() { return 14 * metrics.textScale; },
  get spacing() { return 8 * metrics.textScale; },
  get fontSize() { return 12.5 * metrics.textScale; },
  get choiceHeight() { return 24 * metrics.textScale; },
  get choiceSpacing() { return 8 * metrics.textScale; },
  get yesWidth() { return 92 * metrics.textScale; },
  get noWidth() { return 78 * metrics.textScale; },
  get buttonSize() { return 22 * metrics.buttonScale; },
  get buttonOutset() { return 3 * metrics.buttonScale; },
  /** Zona degli angoli dove stanno X e frecce: testo e pulsanti ne restano fuori. */
  get cornerClearance() { return this.buttonSize - this.buttonOutset + 8; },
  get cardSafeInset() { return this.margin + this.buttonOutset; },
  cardRadius: 18,
  charactersPerSecond: 80,
  maxLines: 16,
};

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Point {
  x: number;
  y: number;
}

/** Dal bordo dell'area utile al centro del globo, nella posa di default in basso a destra. */
function defaultPad(): number {
  return size.margin + (size.globeArea - size.globeDrawn) / 2 + size.globeDrawn / 2;
}

export function defaultGlobeCenter(visible: Rect): Point {
  return { x: visible.x + visible.w - defaultPad(), y: visible.y + visible.h - defaultPad() };
}

/** Il disco disegnato resta a `margin` dal bordo dell'area utile. */
export function clampGlobeCenter(c: Point, visible: Rect): Point {
  const r = size.globeDrawn / 2;
  const m = size.margin;
  const inner = { x: visible.x + m, y: visible.y + m, w: visible.w - 2 * m, h: visible.h - 2 * m };
  if (inner.w < size.globeDrawn || inner.h < size.globeDrawn) {
    return { x: visible.x + visible.w / 2, y: visible.y + visible.h / 2 };
  }
  return {
    x: Math.min(Math.max(c.x, inner.x + r), inner.x + inner.w - r),
    y: Math.min(Math.max(c.y, inner.y + r), inner.y + inner.h - r),
  };
}

/** Preferisce sopra il globo e centrato; se non entra scende sotto o si sposta. */
export function placeCard(height: number, c: Point, visible: Rect): { rect: Rect; above: boolean } {
  const r = size.globeDrawn / 2;
  const inset = size.cardSafeInset;
  const safe = { x: visible.x + inset, y: visible.y + inset, w: visible.w - 2 * inset, h: visible.h - 2 * inset };
  const width = Math.min(size.cardWidth, Math.max(safe.w, 1));
  const h = Math.min(Math.max(height, 1), Math.max(safe.h, 1));
  const globeTop = c.y - r;
  const globeBottom = c.y + r;
  const spaceAbove = globeTop - size.cardGap - safe.y;
  const spaceBelow = safe.y + safe.h - (globeBottom + size.cardGap);
  const above = h <= spaceAbove ? true : h <= spaceBelow ? false : spaceAbove >= spaceBelow;

  const maxX = Math.max(safe.x, safe.x + safe.w - width);
  const x = Math.min(Math.max(c.x - width / 2, safe.x), maxX);
  let y: number;
  if (above) {
    y = globeTop - size.cardGap - h;
    y = Math.max(y, safe.y);
    y = Math.min(y, safe.y + safe.h - h);
  } else {
    y = globeBottom + size.cardGap;
    y = Math.min(y, safe.y + safe.h - h);
    y = Math.max(y, safe.y);
  }
  return { rect: { x, y, w: width, h }, above };
}

export interface Placement {
  /** Finestra in coordinate schermo. */
  window: Rect;
  /** Area del globo e fumetto, locali alla finestra. */
  globe: Rect;
  card: Rect | null;
  cardAbove: boolean;
  center: Point;
}

export function placement(requested: Point, cardHeight: number | null, visible: Rect): Placement {
  const center = clampGlobeCenter(requested, visible);
  const a = size.globeArea;
  const globeScreen = { x: center.x - a / 2, y: center.y - a / 2, w: a, h: a };
  let card: Rect | null = null;
  let above = true;
  let x0 = globeScreen.x, y0 = globeScreen.y, x1 = globeScreen.x + a, y1 = globeScreen.y + a;
  if (cardHeight !== null) {
    const placed = placeCard(cardHeight, center, visible);
    card = placed.rect;
    above = placed.above;
    const pad = size.buttonOutset;
    x0 = Math.min(x0, card.x - pad);
    y0 = Math.min(y0, card.y - pad);
    x1 = Math.max(x1, card.x + card.w + pad);
    y1 = Math.max(y1, card.y + card.h + pad);
  }
  const win = { x: Math.floor(x0), y: Math.floor(y0), w: Math.ceil(x1) - Math.floor(x0), h: Math.ceil(y1) - Math.floor(y0) };
  const local = (rect: Rect): Rect => ({ x: rect.x - win.x, y: rect.y - win.y, w: rect.w, h: rect.h });
  return { window: win, globe: local(globeScreen), card: card && local(card), cardAbove: above, center };
}
