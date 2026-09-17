// Impostazioni. Porting di `Globy/SettingsView.swift`, con le differenze di Windows e Linux.
import "./settings.css";
import { commands, el, watchState, type AppState, type Preferences } from "../shared/api";

const root = document.getElementById("settings")!;
const RANGES = { globeScale: [0.75, 2.5], textScale: [0.85, 1.5], buttonScale: [0.8, 1.6] } as const;

// MARK: Conferme

function confirmAction(title: string, message: string, ok: string, danger: boolean): Promise<boolean> {
  const dialog = document.getElementById("confirm") as HTMLDialogElement;
  document.getElementById("confirm-title")!.textContent = title;
  document.getElementById("confirm-message")!.textContent = message;
  const okButton = document.getElementById("confirm-ok")!;
  okButton.textContent = ok;
  okButton.classList.toggle("danger", danger);
  dialog.showModal();
  return new Promise((resolve) => {
    const finish = (value: boolean) => {
      dialog.close();
      okButton.removeEventListener("click", yes);
      document.getElementById("confirm-cancel")!.removeEventListener("click", no);
      resolve(value);
    };
    const yes = () => finish(true);
    const no = () => finish(false);
    okButton.addEventListener("click", yes);
    document.getElementById("confirm-cancel")!.addEventListener("click", no);
    dialog.addEventListener("cancel", no, { once: true });
  });
}

// MARK: Controlli

function section(title: string, items: HTMLElement[], notes: string[] = []): HTMLElement {
  const node = el("section");
  const group = el("div", "group");
  group.append(...items);
  node.append(el("h2", undefined, title), group);
  notes.forEach((note) => node.append(el("p", "footnote", note)));
  return node;
}

function item(label: string, control: HTMLElement, enabled = true): HTMLElement {
  const node = el("div", enabled ? "item" : "item disabled");
  node.append(el("span", undefined, label), control);
  return node;
}

function toggle(label: string, on: boolean, change: (on: boolean) => void, enabled = true): HTMLElement {
  const button = el("button", "switch");
  button.setAttribute("role", "switch");
  button.setAttribute("aria-checked", String(on));
  button.setAttribute("aria-label", label);
  button.disabled = !enabled;
  button.addEventListener("click", () => change(!on));
  return item(label, button, enabled);
}

function slider(label: string, key: keyof typeof RANGES, preferences: Preferences, enabled: boolean): HTMLElement {
  const [min, max] = RANGES[key];
  const box = el("div", "slider");
  const input = el("input");
  input.type = "range";
  input.min = String(min);
  input.max = String(max);
  input.step = "0.05";
  input.value = String(preferences[key]);
  input.disabled = !enabled;
  input.setAttribute("aria-label", label);
  const value = el("span", "value", `${Math.round(preferences[key] * 100)}%`);
  input.addEventListener("input", () => {
    value.textContent = `${Math.round(Number(input.value) * 100)}%`;
    commands.setPreferences({ [key]: Number(input.value) });
  });
  box.append(input, value);
  return item(label, box, enabled);
}

function button(title: string, run: () => void, danger = false, enabled = true): HTMLButtonElement {
  const node = el("button", danger ? "button danger" : "button", title);
  node.disabled = !enabled;
  node.addEventListener("click", run);
  return node;
}

// MARK: Pagina

function render(state: AppState): void {
  // Un cursore trascinato non va ridisegnato sotto il puntatore.
  if (document.activeElement instanceof HTMLInputElement && document.activeElement.type === "range") return;
  const p = state.preferences;
  const { platform } = state;
  const set = (patch: Partial<Preferences>) => commands.setPreferences(patch);
  const mascotOn = p.mascotEnabled;

  let globyNote: string[] = [];
  if (!mascotOn) {
    globyNote = ["Globy è spento mentre sono attive le notifiche di sistema."];
  } else if (p.permanence) {
    globyNote = [
      p.gazeFollowsPointer && !platform.wayland
        ? "Con Globy sempre visibile potrebbe aumentare il consumo della batteria, soprattutto se gli occhi seguono il puntatore: si ridisegnano a ogni movimento del mouse."
        : "Con Globy sempre visibile potrebbe aumentare un po' il consumo della batteria.",
    ];
  }
  if (platform.wayland) {
    globyNote.push(
      "Con Wayland Globy compare in una piccola finestra che il sistema posiziona da sé, e gli occhi non possono seguire il puntatore.",
    );
  }

  const standard = p.globeScale === 1 && p.textScale === 1 && p.buttonScale === 1;
  const sizesOn = mascotOn && p.customSizesEnabled;
  const dataFolder = platform.windows ? "%APPDATA%\\com.chronocol.globy" : "~/.local/share/com.chronocol.globy";
  const uninstallNote = platform.windows
    ? "Cancella VOX salvati, impostazioni e avvio all’accesso, poi apre il programma di disinstallazione di Windows."
    : "Cancella VOX salvati, impostazioni e avvio all’accesso e chiude Globy. Poi elimina il file AppImage, oppure rimuovi il pacchetto con «sudo apt remove globy».";

  root.replaceChildren(
    section(
      "Globy",
      [
        toggle("Mostra sempre Globy", p.permanence, (on) => set({ permanence: on }), mascotOn),
        toggle("Apri Globy all’accesso", state.launchAtLogin, (on) => commands.setLaunchAtLogin(on)),
        toggle("Suono", p.mascotSoundEnabled, (on) => set({ mascotSoundEnabled: on }), mascotOn),
        toggle(
          "Gli occhi seguono il puntatore",
          p.gazeFollowsPointer && !platform.wayland,
          (on) => set({ gazeFollowsPointer: on }),
          mascotOn && !platform.wayland,
        ),
      ],
      globyNote,
    ),
    section(
      "Dimensioni",
      [
        toggle("Dimensioni personalizzate", p.customSizesEnabled, (on) => set({ customSizesEnabled: on }), mascotOn),
        slider("Globy", "globeScale", p, sizesOn),
        slider("Testo", "textScale", p, sizesOn),
        slider("Pulsanti", "buttonScale", p, sizesOn),
        item(
          "",
          button("Ripristina standard", () => set({ globeScale: 1, textScale: 1, buttonScale: 1 }), false, sizesOn && !standard),
          sizesOn,
        ),
      ],
      [
        "Mentre le Impostazioni sono aperte Globy mostra un’anteprima in basso a destra. Se spegni le dimensioni personalizzate i valori restano salvati.",
      ],
    ),
    section(
      "Notifiche",
      [
        toggle("Notifiche di sistema", !mascotOn, async (on) => {
          if (!on) return set({ mascotEnabled: true });
          const yes = await confirmAction(
            "Passare alle notifiche di sistema?",
            "Attivando le notifiche di sistema, disattiverai la visualizzazione di Globy. I nuovi VOX arriveranno come notifiche del sistema.",
            "Attiva",
            false,
          );
          if (yes) set({ mascotEnabled: false });
        }),
      ],
      ["Al posto di Globy, i nuovi VOX arrivano come notifiche del sistema."],
    ),
    section(
      "Dati",
      [
        item(
          "Dati locali",
          button(
            "Azzera…",
            async () => {
              const yes = await confirmAction(
                "Azzerare i dati locali?",
                "Vengono cancellati elenco, stati letto/notificato e le impostazioni di Globy. Poi parte di nuovo la baseline, senza notifiche sull’archivio.",
                "Azzera",
                true,
              );
              if (yes) commands.resetLocalData();
            },
            true,
          ),
        ),
      ],
      [`I contenuti stanno in un file JSON in ${dataFolder}. Azzerare cancella store e impostazioni.`],
    ),
    section(
      "Disinstalla",
      [
        item(
          "Rimuovi Globy da questo computer",
          button(
            "Disinstalla Globy…",
            async () => {
              const yes = await confirmAction("Disinstallare Globy?", uninstallNote, "Disinstalla", true);
              if (yes) commands.uninstall();
            },
            true,
          ),
        ),
      ],
      [uninstallNote],
    ),
  );
}

watchState(render);
