// Globy: fasi di entrata e uscita, fumetto, coda, saluti, anteprima e tempi.
// Porting di `MascotModel` (MascotView.swift) e `MascotWindowController`.

import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { ReadingPolicy } from "./reading";
import { drawBody, drawFeatures, drawSheen, eyeOpen, globeRadius, type Gaze } from "./globe";
import { GazeTracker, cursorGoal, type GazeTarget } from "./gaze";
import { metrics, placement, defaultGlobeCenter, size, type Placement, type Point, type Rect } from "./metrics";
import { cardTitle, previewVox, VoxLayout, type Vox } from "./vox";
import { tink } from "./sound";

type Phase = "hidden" | "entering" | "idle" | "leaving";
export type GreetingOutcome = "accepted" | "declined" | "timedOut";

/** Quanto resta una domanda «Sì / No» dopo la lettura, se nessuno risponde. */
const CHOICE_LINGER = 20;
const QUEUE_PAUSE = 1;
const DRAG_GRACE = 5;
/** Dopo aver scritto il VOX Globy guarda chi osserva, poi torna al puntatore. */
const LOOK_AT_VIEWER = 1.2;
const SMILE_DURATION = 0.5;
const GREETING_EYE_WIDTH = 1.48;
const GREETING_EYE_ARCH = 0.042;
/** Variazione minima dello sguardo, in radianti, che risveglia il disegno. */
const GAZE_WAKE_THRESHOLD = 0.012;
const FRAME = 1 / 30;

const now = () => performance.now() / 1000;
const reduceMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

export interface Environment {
  workArea: Rect;
  glass: boolean;
  wayland: boolean;
}

export class Mascot {
  // MARK: Stato del modello
  private phase: Phase = "hidden";
  private generation = 0;
  private reading: VoxLayout | null = null;
  private typingStart = 0;
  private smiling = false;
  private smileFrom = 0;
  private smileTo = 0;
  private smileStart = -1e9;
  private blinkStart = -Infinity;
  private doubleBlink = false;
  private blinkCount = 0;
  private blinkTimer: number | undefined;
  private activeUntil = 0;
  private frameRequested = false;
  private lastFrame = 0;
  private lastTyped = -1;
  private readonly gaze = new GazeTracker();
  private pointer: Point | null = null;
  private lastMouseGoal: Gaze | null = null;
  private remaining = 0;
  private previous = 0;

  // MARK: Stato della finestra
  private queue: Vox[] = [];
  private history: Vox[] = [];
  private current: Vox | null = null;
  private showingGreeting = false;
  private greetingItems: Vox[] = [];
  private greetingAsksChoice = false;
  private greetingSteps = 0;
  private greetingCompletion: ((outcome: GreetingOutcome) => void) | null = null;
  private previewing = false;
  private previewRequested = false;
  private movedThisAppearance = false;
  private globeCenter: Point | null = null;
  private layoutCardHeight: number | null = null;
  private placement: Placement | null = null;
  private lastShapes = "";
  private hideTimer: number | undefined;
  private hideDeadline: number | null = null;
  private collapseTimer: number | undefined;

  // MARK: Preferenze
  private permanenceOn = false;
  soundEnabled = true;
  private followOn = true;

  // MARK: Vista
  private readonly root = document.getElementById("root")!;
  private readonly globeEl = document.getElementById("globe")!;
  private readonly bodyCanvas = document.getElementById("globe-body") as HTMLCanvasElement;
  private readonly featuresCanvas = document.getElementById("globe-features") as HTMLCanvasElement;
  private readonly sheenCanvas = document.getElementById("globe-sheen") as HTMLCanvasElement;
  private cardEl: HTMLElement | null = null;

  constructor(private env: Environment) {
    document.body.classList.toggle("glass", env.glass);
    this.redrawStatic();
    this.bindPointer();
  }

  get followsPointer(): boolean {
    return this.followOn && !this.env.wayland;
  }

  set followsPointer(on: boolean) {
    if (this.followOn === on) return;
    this.followOn = on;
    this.lastMouseGoal = null;
    invoke("mascot_follow_pointer", { on: this.followsPointer });
    this.wake(0.8);
  }

  /** Se attiva, Globy resta a schermo: la X chiude solo il fumetto. */
  get permanence(): boolean {
    return this.permanenceOn;
  }

  set permanence(on: boolean) {
    if (on === this.permanenceOn) return;
    this.permanenceOn = on;
    if (on) {
      this.cancelHide();
      this.show();
    } else if (!this.reading) {
      this.dismiss();
    } else {
      this.scheduleHide(ReadingPolicy.linger(this.reading.text));
    }
  }

  /** Posizione del puntatore sullo schermo, dal lato Rust. */
  pointerMoved(p: Point): void {
    this.pointer = p;
    if (this.phase === "hidden") return;
    const target = this.gazeTarget(now());
    if (target.kind !== "cursor") {
      this.wake(0.8);
      return;
    }
    const goal = cursorGoal(p, this.globeScreenCenter());
    const last = this.lastMouseGoal;
    if (last && Math.hypot(goal.dx - last.dx, goal.dy - last.dy) < GAZE_WAKE_THRESHOLD) return;
    this.lastMouseGoal = goal;
    this.wake(0.8);
  }

  // MARK: Richieste

  /** Accoda un VOX. Se Globy è nascosto parte il richiamo; se sta già leggendo, gli
   *  altri aspettano con una pausa di un secondo tra uno e l'altro. */
  summon(vox: Vox): void {
    this.queue.push(vox);
    if (!this.current && !this.showingGreeting) this.presentNext(true);
    else this.refreshChrome();
  }

  summonBurst(items: Vox[]): void {
    items.forEach((vox) => this.summon(vox));
  }

  presentGreeting(
    greeting: Vox,
    items: Vox[] = [],
    followingSteps = 0,
    completion: ((outcome: GreetingOutcome) => void) | null = null,
  ): void {
    if (this.current) {
      this.summonBurst(items);
      return;
    }
    this.previewing = false;
    this.queue.push(...items);
    this.greetingItems.push(...items);
    this.greetingSteps = followingSteps;
    this.greetingCompletion = completion;
    this.greetingAsksChoice = !!greeting.asksChoice && (items.length > 0 || completion !== null);
    this.showingGreeting = true;
    this.setSmiling(true);
    if (this.phase === "hidden" || this.phase === "leaving") {
      this.movedThisAppearance = false;
      if (!this.show()) this.greet();
    } else {
      this.greet();
    }
    this.playSound();
    this.refreshChrome();
    const readingDone = this.present(greeting);
    if (this.permanenceOn) {
      this.cancelHide();
    } else {
      // A una domanda, o a un passo dell'onboarding, si lascia più tempo.
      const waits = this.greetingAsksChoice || this.greetingSteps > 0;
      this.scheduleHide(readingDone + (waits ? CHOICE_LINGER : ReadingPolicy.linger(greeting.text)));
    }
  }

  /** Anteprima delle dimensioni, finché le Impostazioni sono aperte. */
  showPreview(): void {
    this.previewRequested = true;
    if (this.current || this.showingGreeting || this.previewing) return;
    this.previewing = true;
    this.cancelHide();
    if (this.phase === "hidden" || this.phase === "leaving") {
      this.movedThisAppearance = false;
      if (!this.show()) this.greet();
    }
    this.refreshChrome();
    this.present(previewVox);
  }

  hidePreview(): void {
    this.previewRequested = false;
    if (!this.previewing) return;
    this.previewing = false;
    this.dismissVox();
    this.refreshChrome();
    if (!this.permanenceOn) this.dismiss();
  }

  /** Impostazioni di dimensione cambiate: fumetto, pulsanti e globo si adattano subito. */
  metricsDidChange(): void {
    this.redrawStatic();
    if (this.reading) {
      const layout = new VoxLayout(this.reading.vox);
      this.layoutCardHeight = layout.height;
      this.reading = layout;
      this.renderCard(false);
    }
    if (this.phase !== "hidden") this.applyLayout();
    this.wake(0.2);
  }

  /** «Nascondi Globy»: esce subito con fumetto e coda. I VOX restano nell'elenco. */
  hideNow(): void {
    this.cancelHide();
    this.previewing = false;
    this.previewRequested = false;
    this.greetingCompletion = null;
    this.greetingItems = [];
    this.greetingAsksChoice = false;
    this.greetingSteps = 0;
    this.showingGreeting = false;
    this.setSmiling(false);
    this.queue = [];
    this.history = [];
    this.current = null;
    this.dismissVox();
    this.refreshChrome();
    this.leave();
  }

  dismissAll(): void {
    this.dismiss();
  }

  // MARK: Azioni sul fumetto

  /** Clic su globo o fumetto: apre il VOX visibile su Chronocol. */
  private openCurrent(): void {
    if (this.previewing) return;
    if (this.showingGreeting) {
      // Con «Sì / No» si risponde dai pulsanti, non con un clic qualsiasi.
      if ((this.queue.length > 0 || this.greetingSteps > 0) && !this.greetingAsksChoice) this.acceptGreeting();
      return;
    }
    if (this.current?.permalink) invoke("open_permalink", { permalink: this.current.permalink });
  }

  /** X: chiude solo il fumetto. Globy resta se c'è la permanenza. */
  private closeVoxOnly(): void {
    if (this.previewing) {
      this.hidePreview();
      return;
    }
    if (this.showingGreeting) {
      // X sul saluto vuol dire «dopo»: i VOX portati restano nell'elenco.
      this.finishGreeting("declined");
      return;
    }
    if (this.queue.length > 0) this.queue.shift();
    this.current = null;
    if (this.queue.length === 0) this.history = [];
    this.dismissVox();
    this.refreshChrome();
    if (this.permanenceOn) this.cancelHide();
  }

  /** «No»: chiude il fumetto e, senza permanenza, Globy esce poco dopo. */
  private declineGreeting(): void {
    this.closeVoxOnly();
    if (!this.permanenceOn && !this.current && !this.showingGreeting) this.scheduleHide(1.2);
  }

  private acceptGreeting(): void {
    if (this.showingGreeting) this.finishGreeting("accepted");
  }

  private finishGreeting(outcome: GreetingOutcome): void {
    const completion = this.greetingCompletion;
    this.greetingCompletion = null;
    if (outcome !== "accepted") {
      const brought = this.greetingItems;
      this.queue = this.queue.filter((vox) => !brought.includes(vox));
      this.greetingItems = [];
    }
    this.endGreeting();
    completion?.(outcome);
    // Risposta data e niente altro da dire: Globy esce poco dopo.
    if (outcome !== "timedOut" && !this.showingGreeting && !this.current && this.queue.length === 0 && !this.permanenceOn) {
      this.scheduleHide(1.2);
    }
  }

  private endGreeting(): void {
    this.greetingItems = [];
    this.greetingAsksChoice = false;
    this.greetingSteps = 0;
    this.showingGreeting = false;
    this.setSmiling(false);
    this.dismissVox();
    if (this.permanenceOn) this.cancelHide();
    if (this.queue.length > 0) this.presentNext(false, false);
    else this.refreshChrome();
  }

  private goToNext(): void {
    if (this.previewing) return;
    if (this.showingGreeting) {
      this.acceptGreeting();
      return;
    }
    if (this.queue.length <= 1) return;
    this.history.push(this.queue.shift()!);
    this.presentNext(false);
  }

  private goToPrevious(): void {
    if (this.previewing) return;
    const previous = this.history.pop();
    if (!previous) return;
    this.queue.unshift(previous);
    this.presentNext(false, false);
  }

  private presentNext(fromHidden: boolean, playSound = true): void {
    this.previewing = false;
    this.showingGreeting = false;
    this.setSmiling(false);
    const vox = this.queue[0];
    if (!vox) {
      this.current = null;
      this.history = [];
      this.refreshChrome();
      if (!this.permanenceOn) this.dismiss();
      return;
    }
    this.current = vox;
    if (fromHidden || this.phase === "hidden" || this.phase === "leaving") {
      this.movedThisAppearance = false;
      if (!this.show()) this.greet();
    } else {
      this.greet();
    }
    if (playSound) this.playSound();
    this.refreshChrome();
    const readingDone = this.present(vox);
    if (this.permanenceOn) this.cancelHide();
    else this.scheduleHide(readingDone + ReadingPolicy.linger(vox.text));
  }

  // MARK: Tempi

  private scheduleHide(delay: number): void {
    this.cancelHide();
    this.hideDeadline = now() + delay;
    this.hideTimer = window.setTimeout(() => this.hideTimerFired(), delay * 1000);
  }

  private cancelHide(): void {
    window.clearTimeout(this.hideTimer);
    this.hideTimer = undefined;
    this.hideDeadline = null;
  }

  private hideTimerFired(): void {
    this.hideTimer = undefined;
    this.hideDeadline = null;
    if (this.permanenceOn || this.previewing) return;
    if (this.showingGreeting) {
      this.finishGreeting("timedOut");
      if (this.queue.length === 0 && !this.showingGreeting) this.dismiss();
      return;
    }
    if (this.reading && this.queue.length > 1) {
      this.history.push(this.queue.shift()!);
      this.current = null;
      this.dismissVox();
      this.refreshChrome();
      this.hideTimer = window.setTimeout(() => this.presentNext(false), QUEUE_PAUSE * 1000);
      return;
    }
    if (this.reading) this.closeVoxOnly();
    this.dismiss();
  }

  /** Senza permanenza, un trascinamento aggiunge 5 secondi prima della scomparsa. */
  private extendHideAfterDrag(): void {
    if (this.permanenceOn || this.phase !== "idle") return;
    const t = now();
    this.scheduleHide(Math.max(0, (this.hideDeadline ?? t) - t) + DRAG_GRACE);
  }

  private refreshChrome(): void {
    if (this.previewing) {
      // Frecce finte con numerini, solo per far vedere la misura dei pulsanti.
      this.remaining = 2;
      this.previous = 1;
    } else if (this.showingGreeting) {
      this.remaining = this.greetingAsksChoice ? 0 : this.greetingItems.length === 0 ? this.greetingSteps : this.queue.length;
      this.previous = 0;
    } else {
      this.remaining = Math.max(0, this.queue.length - 1);
      this.previous = this.history.length;
    }
    this.renderChrome();
  }

  // MARK: Comparsa e uscita

  /** Vero se Globy stava entrando in scena. */
  private show(): boolean {
    const entering = this.phase === "hidden" || this.phase === "leaving";
    if (entering) {
      this.layoutCardHeight = null;
      this.reposition();
      invoke("mascot_set_visible", { visible: true, followPointer: this.followsPointer });
      this.enter();
    }
    return entering;
  }

  private dismiss(): void {
    if (this.previewRequested && !this.previewing && !this.current && !this.showingGreeting) {
      this.showPreview();
      return;
    }
    this.history = [];
    this.leave();
  }

  private enter(): void {
    this.generation += 1;
    const current = this.generation;
    this.phase = "entering";
    this.startLife();
    this.wake(1);
    this.globeEl.className = "out";
    window.setTimeout(() => {
      if (this.generation !== current) return;
      this.phase = "idle";
      this.globeEl.className = "in";
    }, 50);
  }

  private leave(): void {
    this.generation += 1;
    window.clearTimeout(this.collapseTimer);
    this.setSmiling(false);
    const current = this.generation;
    this.phase = "leaving";
    this.globeEl.className = "leaving";
    this.removeCard(true);
    window.setTimeout(() => {
      if (this.generation !== current) return;
      this.phase = "hidden";
      this.stopLife();
      this.layoutCardHeight = null;
      this.movedThisAppearance = false;
      invoke("mascot_set_visible", { visible: false, followPointer: false });
    }, 400);
  }

  /** Prima il globo, poi il fumetto; poi il testo si scrive e gli occhi lo seguono.
   *  Restituisce dopo quanti secondi lettura e sguardo verso chi osserva sono finiti. */
  private present(vox: Vox): number {
    const current = this.generation;
    const layout = new VoxLayout(vox);
    const delay = this.phase === "idle" ? 0.1 : 0.7;
    const pop = 0.35;
    window.setTimeout(() => {
      if (this.generation !== current || this.phase === "hidden") return;
      window.clearTimeout(this.collapseTimer);
      this.typingStart = now() + pop;
      // Prima la geometria, poi il fumetto: il globo non si sposta durante la comparsa.
      this.layoutCardHeight = layout.height;
      this.applyLayout();
      requestAnimationFrame(() => {
        if (this.generation !== current || this.phase === "hidden") return;
        this.reading = layout;
        this.lastTyped = -1;
        this.renderCard(true);
        this.wake(pop + layout.typingDuration + LOOK_AT_VIEWER + 0.8);
      });
    }, delay * 1000);
    return delay + pop + layout.typingDuration + LOOK_AT_VIEWER;
  }

  private dismissVox(): void {
    window.clearTimeout(this.collapseTimer);
    this.reading = null;
    this.removeCard(false);
    const token = this.generation;
    this.collapseTimer = window.setTimeout(() => {
      if (this.generation !== token || this.reading) return;
      this.layoutCardHeight = null;
      this.applyLayout();
    }, 340);
  }

  private greet(): void {
    this.blink(true);
  }

  private setSmiling(on: boolean): void {
    const t = now();
    this.smileFrom = this.smileAmount(t);
    this.smileTo = on ? 1 : 0;
    this.smileStart = t;
    this.smiling = on;
    this.wake(SMILE_DURATION + 0.15);
  }

  private smileAmount(t: number): number {
    const u = Math.min(1, Math.max(0, (t - this.smileStart) / SMILE_DURATION));
    const s = u * u * (3 - 2 * u);
    return this.smileFrom + (this.smileTo - this.smileFrom) * s;
  }

  private startLife(): void {
    if (this.blinkTimer !== undefined) return;
    this.blinkTimer = window.setInterval(() => {
      this.blinkCount += 1;
      this.blink(this.blinkCount % 3 === 0);
    }, 4000);
  }

  private stopLife(): void {
    window.clearInterval(this.blinkTimer);
    this.blinkTimer = undefined;
    this.lastMouseGoal = null;
    this.activeUntil = 0;
  }

  private blink(double: boolean): void {
    this.blinkStart = now();
    this.doubleBlink = double;
    this.wake(double ? 0.5 : 0.25);
  }

  private playSound(): void {
    if (this.soundEnabled && !reduceMotion()) tink();
  }

  // MARK: Disegno

  /** Tiene acceso il disegno almeno per `duration` secondi; poi si ferma da solo. */
  private wake(duration: number): void {
    this.activeUntil = Math.max(this.activeUntil, now() + duration);
    if (!this.frameRequested) {
      this.frameRequested = true;
      requestAnimationFrame(() => this.frame());
    }
  }

  private frame(): void {
    this.frameRequested = false;
    const t = now();
    if (this.phase === "hidden") return;
    // Al massimo 30 fotogrammi al secondo: bastano per sguardo smorzato e battiti.
    if (t - this.lastFrame >= FRAME - 0.004) {
      this.lastFrame = t;
      this.drawFrame(t);
    }
    if (t < this.activeUntil) {
      this.frameRequested = true;
      requestAnimationFrame(() => this.frame());
    }
  }

  private gazeTarget(t: number): GazeTarget {
    if (this.smileAmount(t) > 0.12) return { kind: "viewer" };
    const rest: GazeTarget = this.followsPointer ? { kind: "cursor" } : { kind: "viewer" };
    const reading = this.reading;
    if (!reading) return rest;
    const typingEnd = this.typingStart + reading.typingDuration;
    if (t < typingEnd) return { kind: "point", ...this.caretOnScreen(reading, reading.typedCount(t - this.typingStart)) };
    return t < typingEnd + LOOK_AT_VIEWER ? { kind: "viewer" } : rest;
  }

  private globeScreenCenter(): Point {
    const p = this.placement;
    if (!p) return { x: 0, y: 0 };
    return { x: p.window.x + p.globe.x + p.globe.w / 2, y: p.window.y + p.globe.y + p.globe.h / 2 };
  }

  private caretOnScreen(layout: VoxLayout, count: number): Point {
    const p = this.placement;
    if (!p?.card) return this.globeScreenCenter();
    const caret = layout.caret(count);
    return {
      x: p.window.x + p.card.x + size.padding + caret.x,
      y: p.window.y + p.card.y + size.padding + size.headerHeight + size.spacing + caret.y,
    };
  }

  private drawFrame(t: number): void {
    const still = reduceMotion();
    const smile = still ? (this.smiling ? 1 : 0) : this.smileAmount(t);
    const blink = still ? 1 : eyeOpen(t - this.blinkStart, this.doubleBlink);
    const gaze = still && smile < 0.12 ? { dx: 0, dy: 0 } : this.gaze.update(t, this.globeScreenCenter(), this.pointer, this.gazeTarget(t));
    const ratio = devicePixelRatio;
    const ctx = this.featuresCanvas.getContext("2d")!;
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    drawFeatures(ctx, size.globeDrawn, ratio, {
      glass: this.env.glass,
      gaze,
      eyeOpen: blink * (1 - smile),
      eyeWidth: 1 + (GREETING_EYE_WIDTH - 1) * smile,
      eyeArch: GREETING_EYE_ARCH * smile,
    });

    const reading = this.reading;
    if (reading && this.cardEl) {
      const typed = still ? reading.count : reading.typedCount(t - this.typingStart);
      if (typed !== this.lastTyped) {
        this.lastTyped = typed;
        const [shown, hidden] = reading.typedText(typed);
        this.cardEl.querySelector(".typed")!.textContent = shown;
        this.cardEl.querySelector(".untyped")!.textContent = hidden;
      }
    }
  }

  private redrawStatic(): void {
    const drawn = size.globeDrawn;
    const ratio = devicePixelRatio;
    for (const canvas of [this.bodyCanvas, this.featuresCanvas, this.sheenCanvas]) {
      canvas.width = Math.ceil(drawn * ratio);
      canvas.height = Math.ceil(drawn * ratio);
      canvas.style.width = `${drawn}px`;
      canvas.style.height = `${drawn}px`;
    }
    const body = this.bodyCanvas.getContext("2d")!;
    body.setTransform(ratio, 0, 0, ratio, 0, 0);
    drawBody(body, drawn, this.env.glass);
    const sheen = this.sheenCanvas.getContext("2d")!;
    sheen.setTransform(ratio, 0, 0, ratio, 0, 0);
    drawSheen(sheen, drawn);
    this.drawFrame(now());
  }

  // MARK: Disposizione

  private async reposition(): Promise<void> {
    this.globeCenter = defaultGlobeCenter(this.env.workArea);
    this.applyLayout();
    // Lo schermo con il puntatore può essere un altro, o la barra spostata.
    const area = await invoke<Rect>("mascot_screen");
    this.env.workArea = area;
    if (!this.movedThisAppearance) this.globeCenter = defaultGlobeCenter(area);
    this.applyLayout();
  }

  /** Ricalcola fumetto e finestra intorno al globo, dentro l'area utile. */
  private applyLayout(): void {
    const requested = this.globeCenter ?? defaultGlobeCenter(this.env.workArea);
    const p = placement(requested, this.layoutCardHeight, this.env.workArea);
    this.globeCenter = p.center;
    this.placement = p;
    this.root.style.width = `${p.window.w}px`;
    this.root.style.height = `${p.window.h}px`;
    const inset = (size.globeArea - size.globeDrawn) / 2;
    Object.assign(this.globeEl.style, {
      left: `${p.globe.x + inset}px`,
      top: `${p.globe.y + inset}px`,
      width: `${size.globeDrawn}px`,
      height: `${size.globeDrawn}px`,
    });
    if (this.cardEl && p.card) this.positionCard(this.cardEl, p);
    this.sendShapes(p);
  }

  private sendShapes(p: Placement): void {
    const drawn = size.globeDrawn;
    const r = globeRadius(drawn);
    const center: [number, number] = [p.globe.x + p.globe.w / 2, p.globe.y + p.globe.h / 2 - r * 0.04];
    const rounded: { rect: Rect; radius: number }[] = [];
    // Il fumetto resta nella forma anche mentre sfuma, finché la sua riserva di spazio c'è.
    if (p.card) {
      rounded.push({ rect: p.card, radius: size.cardRadius });
      const b = size.buttonSize, o = size.buttonOutset;
      const corner = (x: number, y: number) => rounded.push({ rect: { x, y, w: b, h: b }, radius: b / 2 });
      corner(p.card.x + p.card.w - b + o, p.card.y - o);
      if (this.remaining > 0) corner(p.card.x + p.card.w - b + o, p.card.y + p.card.h - b + o);
      if (this.previous > 0) corner(p.card.x - o, p.card.y + p.card.h - b + o);
    }
    const shapes = { window: p.window, globeCenter: center, globeRadius: r, rounded };
    const key = JSON.stringify(shapes);
    if (key === this.lastShapes) return;
    this.lastShapes = key;
    invoke("mascot_layout", { shapes });
  }

  // MARK: Fumetto

  private renderCard(animated: boolean): void {
    const reading = this.reading;
    const p = this.placement;
    if (!reading || !p) return;
    this.removeCard(true);
    const [title, badge] = cardTitle(reading.vox.kind);
    const card = document.createElement("div");
    card.className = animated && !reduceMotion() ? "card entering" : "card";
    card.setAttribute("role", "dialog");
    card.setAttribute("aria-label", reading.text);
    card.innerHTML = `
      <header><span class="title"></span><span class="badge"></span></header>
      <p class="text"><span class="typed"></span><span class="untyped"></span></p>
      <div class="choices" hidden><button class="pill no"></button><button class="pill yes"></button></div>
      <button class="corner close" aria-label="Chiudi" title="Chiudi">${ICON_CLOSE}</button>
      <button class="corner next" hidden>${ICON_NEXT}<span class="count"></span></button>
      <button class="corner back" hidden>${ICON_BACK}<span class="count"></span></button>`;
    card.querySelector(".title")!.textContent = title;
    card.querySelector(".badge")!.textContent = badge;
    const [shown, hidden] = reading.typedText(animated && !reduceMotion() ? 0 : reading.count);
    card.querySelector(".typed")!.textContent = shown;
    card.querySelector(".untyped")!.textContent = hidden;
    if (!animated) this.lastTyped = -1;
    if (reading.asksChoice) {
      card.querySelector<HTMLElement>(".choices")!.hidden = false;
      card.querySelector(".no")!.textContent = reading.vox.noTitle ?? "No, grazie";
      card.querySelector(".yes")!.textContent = reading.vox.yesTitle ?? "Sì, partiamo";
    }
    this.cardEl = card;
    this.positionCard(card, p);
    this.root.append(card);
    this.renderChrome();
    if (card.classList.contains("entering")) requestAnimationFrame(() => card.classList.remove("entering"));
  }

  private positionCard(card: HTMLElement, p: Placement): void {
    if (!p.card) return;
    Object.assign(card.style, {
      left: `${p.card.x}px`,
      top: `${p.card.y}px`,
      width: `${p.card.w}px`,
      height: `${p.card.h}px`,
      transformOrigin: p.cardAbove ? "50% 100%" : "50% 0%",
    });
  }

  private removeCard(immediately: boolean): void {
    const card = this.cardEl;
    this.cardEl = null;
    if (!card) return;
    if (immediately || reduceMotion()) {
      card.remove();
      return;
    }
    card.classList.add("leaving");
    window.setTimeout(() => card.remove(), 300);
  }

  private renderChrome(): void {
    const card = this.cardEl;
    if (!card) {
      if (this.placement) this.sendShapes(this.placement);
      return;
    }
    const setCorner = (selector: string, count: number, label: string) => {
      const button = card.querySelector<HTMLButtonElement>(selector)!;
      button.hidden = count <= 0;
      button.title = label;
      button.setAttribute("aria-label", label);
      button.querySelector(".count")!.textContent = count > 99 ? "99+" : String(count);
    };
    let nextLabel = this.remaining <= 1 ? "VOX successivo" : `${this.remaining} VOX successivi`;
    if (this.showingGreeting) nextLabel = this.queue.length === 1 ? "Mostra il VOX" : `Mostra i ${this.queue.length} VOX`;
    setCorner(".next", this.remaining, nextLabel);
    setCorner(".back", this.previous, this.previous <= 1 ? "VOX precedente" : `${this.previous} VOX precedenti`);
    if (this.placement) this.sendShapes(this.placement);
  }

  // MARK: Puntatore

  private bindPointer(): void {
    let down: { x: number; y: number; center: Point } | null = null;
    let dragged = false;

    this.root.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      const target = event.target as HTMLElement;
      if (target.closest("button")) return;
      if (!target.closest("#globe, .card")) return;
      down = { x: event.screenX, y: event.screenY, center: this.globeCenter ?? { x: 0, y: 0 } };
      dragged = false;
      this.root.setPointerCapture(event.pointerId);
    });

    this.root.addEventListener("pointermove", (event) => {
      if (!down) return;
      const dx = event.screenX - down.x;
      const dy = event.screenY - down.y;
      if (!dragged && Math.hypot(dx, dy) <= 4) return;
      if (!dragged && this.env.wayland) {
        // Con Wayland la posizione la decide il sistema: trascina la finestra intera.
        down = null;
        getCurrentWindow().startDragging();
        return;
      }
      dragged = true;
      this.movedThisAppearance = true;
      this.globeCenter = { x: down.center.x + dx, y: down.center.y + dy };
      this.applyLayout();
    });

    this.root.addEventListener("pointerup", (event) => {
      if (!down) return;
      this.root.releasePointerCapture(event.pointerId);
      down = null;
      if (dragged) this.extendHideAfterDrag();
      else this.openCurrent();
    });

    this.root.addEventListener("click", (event) => {
      const button = (event.target as HTMLElement).closest("button");
      if (!button) return;
      if (button.classList.contains("close")) this.closeVoxOnly();
      else if (button.classList.contains("next")) this.goToNext();
      else if (button.classList.contains("back")) this.goToPrevious();
      else if (button.classList.contains("yes")) this.acceptGreeting();
      else if (button.classList.contains("no")) this.declineGreeting();
    });

    this.root.addEventListener("contextmenu", (event) => {
      event.preventDefault();
      invoke("mascot_context_menu");
    });
  }
}

const ICON_CLOSE = `<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M2 2l6 6M8 2L2 8"/></svg>`;
const ICON_NEXT = `<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M3.5 1.5L7 5 3.5 8.5"/></svg>`;
const ICON_BACK = `<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M6.5 1.5L3 5l3.5 3.5"/></svg>`;

export { metrics };
