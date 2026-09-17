// VOX mostrati da Globy e impaginazione del fumetto. Porting di `Vox` e `VoxLayout`:
// altezza fissa fin dall'inizio e posizione del carattere appena scritto.

import { metrics, size } from "./metrics";

export type VoxKind = "publication" | "greeting" | "recent" | "preview";

export interface Vox {
  id: string;
  text: string;
  permalink: string | null;
  kind: VoxKind;
  /** Il fumetto mostra «Sì» e «No» invece della freccia. */
  asksChoice?: boolean;
  yesTitle?: string;
  noTitle?: string;
}

export const previewVox: Vox = {
  id: "preview",
  text: "Così appare il fumetto con queste dimensioni. X e frecce mostrano la misura dei pulsanti.",
  permalink: null,
  kind: "preview",
};

/** Elemento nascosto con lo stesso testo del fumetto, per misurare righe e caret. */
const measurer = document.createElement("div");
measurer.className = "measure";
measurer.setAttribute("aria-hidden", "true");
document.body.append(measurer);

function prepareMeasurer(text: string): Text {
  measurer.style.width = `${size.cardWidth - 2 * size.padding}px`;
  measurer.style.fontSize = `${size.fontSize}px`;
  measurer.textContent = text;
  return measurer.firstChild as Text;
}

function lineHeight(): number {
  return Math.round(size.fontSize * 1.32 * 100) / 100;
}

function linesOf(text: string): number {
  prepareMeasurer(text || " ");
  return Math.round(measurer.getBoundingClientRect().height / lineHeight());
}

/** Testo tagliato a `maxLines` righe con «…», alla larghezza e al corpo attuali. */
export function fitted(text: string): string {
  if (linesOf(text) <= size.maxLines) return text;
  let low = 0;
  let high = text.length;
  while (low < high) {
    const mid = Math.ceil((low + high) / 2);
    if (linesOf(text.slice(0, mid).trimEnd() + "…") <= size.maxLines) low = mid;
    else high = mid - 1;
  }
  let prefix = text.slice(0, low);
  // Spazio per «…» sull'ultima riga: toglie l'ultima parola, poi gli spazi.
  const space = prefix.trimEnd().search(/\s\S*$/);
  if (space > 0) prefix = prefix.slice(0, space);
  return prefix.trimEnd() + "…";
}

export class VoxLayout {
  readonly text: string;
  readonly chars: string[];
  readonly textHeight: number;
  readonly scaleKey: string;

  constructor(readonly vox: Vox) {
    this.text = fitted(vox.text);
    // Per caratteri visibili, non per unità UTF-16: emoji e bandiere contano uno.
    this.chars = Array.from(new Intl.Segmenter("it", { granularity: "grapheme" }).segment(this.text), (s) => s.segment);
    prepareMeasurer(this.text || " ");
    this.textHeight = Math.ceil(measurer.getBoundingClientRect().height + 2 * metrics.textScale);
    this.scaleKey = `${metrics.textScale}|${metrics.buttonScale}`;
  }

  get count(): number {
    return this.chars.length;
  }

  get asksChoice(): boolean {
    return !!this.vox.asksChoice;
  }

  get height(): number {
    return (
      size.padding + size.cornerClearance + size.headerHeight + size.spacing + this.textHeight +
      (this.asksChoice ? size.spacing + size.choiceHeight : 0)
    );
  }

  get typingDuration(): number {
    return this.count / size.charactersPerSecond;
  }

  typedCount(elapsed: number): number {
    return Math.max(0, Math.min(this.count, Math.floor(elapsed * size.charactersPerSecond)));
  }

  typedText(n: number): [string, string] {
    return [this.chars.slice(0, n).join(""), this.chars.slice(n).join("")];
  }

  /** Fine dell'ultimo carattere scritto, nel riquadro del testo (origine in alto a sinistra). */
  caret(n: number): { x: number; y: number } {
    const node = prepareMeasurer(this.text || " ");
    const box = measurer.getBoundingClientRect();
    if (n <= 0 || !node) return { x: 0, y: lineHeight() / 2 };
    const offset = this.typedText(Math.min(n, this.count))[0].length;
    const range = document.createRange();
    range.setStart(node, Math.max(0, offset - 1));
    range.setEnd(node, offset);
    const rects = range.getClientRects();
    const rect = rects[rects.length - 1] ?? range.getBoundingClientRect();
    return { x: rect.right - box.left, y: rect.top - box.top + rect.height / 2 };
  }
}

export function cardTitle(kind: VoxKind): [string, string] {
  switch (kind) {
    case "greeting": return ["Globy", "ciao"];
    case "publication": return ["Nuovo VOX", "ora"];
    case "recent": return ["VOX recente", "già uscito"];
    case "preview": return ["Anteprima", "dimensioni"];
  }
}
