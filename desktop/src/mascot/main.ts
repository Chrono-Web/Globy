// Finestra di Globy: collega richieste e preferenze dal lato Rust al controllore.
import "./mascot.css";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { commands, watchState, type AppState, type VoxView } from "../shared/api";
import { Mascot, type Environment } from "./controller";
import { metrics, size } from "./metrics";
import type { Vox } from "./vox";

type Request =
  | { kind: "burst"; voxes: VoxView[] }
  | { kind: "welcome"; text: string; voxes: VoxView[] }
  | { kind: "onboarding"; introduction: string; steps: string[]; offer: string | null; latest: VoxView[] }
  | { kind: "show"; vox: VoxView };

interface Screen {
  workArea: Environment["workArea"];
  glass: boolean;
  platform: AppState["platform"];
}

const toVox = (view: VoxView, kind: Vox["kind"] = "publication"): Vox => ({
  id: view.documentId,
  text: view.text,
  permalink: view.permalink,
  kind,
});

const welcome = (text: string, asksChoice = false): Vox => ({
  id: `greeting-${Math.random()}`,
  text,
  permalink: null,
  kind: "greeting",
  asksChoice,
  yesTitle: "Sì, partiamo",
  noTitle: "No, grazie",
});

/** Misure del fumetto come variabili CSS, ricalcolate a ogni cambio di scala. */
function applyScaleVariables(): void {
  const style = document.documentElement.style;
  const px = (value: number) => `${value}px`;
  style.setProperty("--text-scale", String(metrics.textScale));
  style.setProperty("--button-scale", String(metrics.buttonScale));
  style.setProperty("--header-height", px(size.headerHeight));
  style.setProperty("--header-clearance", px(size.cornerClearance - size.padding));
  style.setProperty("--spacing", px(size.spacing));
  style.setProperty("--font-size", px(size.fontSize));
  style.setProperty("--choice-height", px(size.choiceHeight));
  style.setProperty("--choice-spacing", px(size.choiceSpacing));
  style.setProperty("--yes-width", px(size.yesWidth));
  style.setProperty("--no-width", px(size.noWidth));
  style.setProperty("--button-size", px(size.buttonSize));
  style.setProperty("--button-outset", px(size.buttonOutset));
}

/** Primo avvio: presentazione, due passi e la proposta dei VOX recenti. Si avanza con la
 *  freccia; ignorato o chiuso con la X si ferma, e la spiegazione resta nell'elenco. */
function presentOnboarding(mascot: Mascot, request: Extract<Request, { kind: "onboarding" }>): void {
  const latest = request.latest.map((view) => toVox(view, "recent"));
  const hasOffer = request.offer !== null && latest.length > 0;
  mascot.presentGreeting(welcome(request.introduction), [], hasOffer ? 3 : 2, (first) => {
    if (first !== "accepted") return;
    mascot.presentGreeting(welcome(request.steps[0]), [], hasOffer ? 2 : 1, (second) => {
      if (second !== "accepted") return;
      mascot.presentGreeting(welcome(request.steps[1]), [], hasOffer ? 1 : 0, (third) => {
        if (third === "timedOut") return;
        // Letto fino alle Impostazioni (freccia o X): l'onboarding è concluso.
        commands.finishOnboarding();
        if (third === "accepted" && hasOffer) mascot.presentGreeting(welcome(request.offer!, true), latest);
      });
    });
  });
}

async function start(): Promise<void> {
  const screen = await invoke<Screen>("mascot_environment");
  let mascot: Mascot | null = null;
  let lastScales = "";
  let mascotEnabled = true;

  await watchState((state) => {
    const p = state.preferences;
    mascotEnabled = p.mascotEnabled;
    const custom = p.customSizesEnabled;
    metrics.textScale = custom ? p.textScale : 1;
    metrics.buttonScale = custom ? p.buttonScale : 1;
    metrics.globeScale = custom ? p.globeScale : 1;
    const scales = `${metrics.textScale}|${metrics.buttonScale}|${metrics.globeScale}`;
    applyScaleVariables();
    if (!mascot) {
      mascot = new Mascot({ workArea: screen.workArea, glass: screen.glass, wayland: screen.platform.wayland });
      lastScales = scales;
    } else if (scales !== lastScales) {
      lastScales = scales;
      mascot.metricsDidChange();
    }
    mascot.soundEnabled = p.mascotSoundEnabled;
    mascot.followsPointer = p.gazeFollowsPointer;
    mascot.permanence = p.mascotEnabled && p.permanence;
    if (!p.mascotEnabled) mascot.hideNow();
  });

  const ready = mascot as unknown as Mascot;
  await listen<Request>("mascot-request", ({ payload }) => {
    switch (payload.kind) {
      case "burst":
        ready.summonBurst(payload.voxes.map((view) => toVox(view)));
        break;
      case "welcome":
        ready.presentGreeting(welcome(payload.text), payload.voxes.map((view) => toVox(view)));
        break;
      case "onboarding":
        presentOnboarding(ready, payload);
        break;
      case "show":
        ready.showNow(toVox(payload.vox));
        break;
    }
  });
  await listen<[number, number]>("mascot-pointer", ({ payload }) => ready.pointerMoved({ x: payload[0], y: payload[1] }));
  await listen<boolean>("mascot-preview", ({ payload }) => {
    if (!payload) ready.hidePreview();
    else if (mascotEnabled) ready.showPreview();
  });
  await listen("mascot-hide-now", () => ready.hideNow());
  await listen("mascot-dismiss", () => ready.hideNow());
  await invoke("mascot_ready");
}

start();
