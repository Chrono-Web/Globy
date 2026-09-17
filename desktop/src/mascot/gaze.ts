// Sguardo smorzato: segue il bersaglio senza scatti. Porting di `GazeTracker`.
// Coordinate schermo con l'asse y verso il basso, come nel browser.

import type { Gaze } from "./globe";

export type GazeTarget = { kind: "cursor" } | { kind: "viewer" } | { kind: "point"; x: number; y: number };

export function direction(px: number, py: number, cx: number, cy: number, falloff: number, reach: number): Gaze {
  const dx = px - cx;
  // Sullo schermo y cresce verso il basso: guardare in alto è dy positivo.
  const dy = cy - py;
  const dist = Math.max(Math.hypot(dx, dy), 1);
  const amount = Math.min(dist / falloff, 1) * reach;
  return { dx: (dx / dist) * amount, dy: (dy / dist) * amount * 0.7 };
}

export function cursorGoal(pointer: { x: number; y: number }, center: { x: number; y: number }): Gaze {
  return direction(pointer.x, pointer.y, center.x, center.y, 500, 0.45);
}

export class GazeTracker {
  private value: Gaze = { dx: 0, dy: 0 };
  private last: number | null = null;

  update(t: number, center: { x: number; y: number }, pointer: { x: number; y: number } | null, target: GazeTarget): Gaze {
    let goal: Gaze = { dx: 0, dy: 0 };
    if (target.kind === "cursor" && pointer) {
      goal = cursorGoal(pointer, center);
    } else if (target.kind === "point") {
      // Il testo è vicino: più sensibile, così la lettura si vede.
      goal = direction(target.x, target.y, center.x, center.y, 260, 0.5);
    }
    const dt = Math.min(t - (this.last ?? t), 0.1);
    this.last = t;
    const k = Math.min(1, dt * 9);
    this.value = { dx: this.value.dx + (goal.dx - this.value.dx) * k, dy: this.value.dy + (goal.dy - this.value.dy) * k };
    return this.value;
  }
}
