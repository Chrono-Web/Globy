// Elenco dei VOX vicino all'icona di sistema. Porting di `Globy/MenuBarView.swift`.
import "./menu.css";
import { commands, el, watchState, type AppState, type VoxView } from "../shared/api";

const root = document.getElementById("menu")!;

function unreadTitle(count: number): string {
  if (count === 0) return "Nessun VOX non letto";
  if (count === 1) return "1 VOX non letto";
  return `${count} VOX non letti`;
}

function divider(): HTMLElement {
  return el("div", "divider");
}

function action(title: string, run: () => void): HTMLButtonElement {
  const button = el("button", "action", title);
  button.addEventListener("click", run);
  return button;
}

function onboarding(): HTMLElement {
  const box = el("section", "onboarding");
  box.append(
    el("h2", undefined, "Due cose, poi basta"),
    el(
      "p",
      undefined,
      "Globy legge i VOX pubblici di Chronocol. L’archivio già presente non viene notificato: in questo elenco trovi gli ultimi VOX, con in evidenza quelli nuovi non letti.",
    ),
    el(
      "p",
      undefined,
      "Nelle Impostazioni puoi tenere Globy sempre a schermo, togliere il suono, cambiare le dimensioni o passare alle notifiche di sistema al posto di Globy.",
    ),
  );
  const ok = el("button", undefined, "Ho capito");
  ok.addEventListener("click", () => commands.finishOnboarding());
  box.append(ok);
  return box;
}

function row(vox: VoxView): HTMLButtonElement {
  const button = el("button", vox.isUnread ? "row unread" : "row");
  button.append(el("div", "text", vox.text));
  // L'archivio del primo avvio non ha etichetta finché non lo apri.
  const labels: string[] = [];
  if (vox.isUnread) labels.push("Non letto");
  else if (vox.isRead) labels.push("Letto");
  if (vox.isNotified) labels.push("Notificato");
  if (labels.length > 0) {
    const line = el("div", "labels");
    labels.forEach((label) => line.append(el("span", undefined, label)));
    button.append(line);
  }
  button.addEventListener("click", () => commands.openVox(vox.documentId));
  return button;
}

function render(state: AppState): void {
  const scroll = root.querySelector(".list")?.scrollTop ?? 0;
  root.replaceChildren();
  if (!state.preferences.didOnboard) {
    root.append(onboarding(), divider());
  }

  const header = el("header", "header");
  header.append(el("h2", undefined, unreadTitle(state.unreadCount)));
  if (state.isSyncing) header.append(el("div", "spinner"));
  root.append(header);
  if (state.lastFailure) root.append(el("div", "failure", "Ultimo controllo non riuscito: riprovo tra poco."));
  root.append(divider());

  const list = el("div", "list");
  if (state.recent.length === 0) {
    list.append(el("div", "empty", state.isSyncing ? "Sincronizzazione…" : "Nessun VOX ancora."));
  } else {
    state.recent.forEach((vox) => list.append(row(vox)));
  }
  root.append(list);
  list.scrollTop = scroll;

  if (state.usesFixture) {
    root.append(
      divider(),
      el("div", "debug-title", "Fixture locale, niente rete"),
      action("Simula nuovo VOX", () => commands.simulatePublication(1)),
      action("Simula raffica (3 VOX)", () => commands.simulatePublication(3)),
    );
  }

  root.append(
    divider(),
    action("Impostazioni…", () => commands.showSettings()),
    action("Esci", () => commands.quit()),
  );
}

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") commands.hideMenu();
});

commands.hasGlass().then((glass) => document.body.classList.toggle("glass", glass));
watchState(render);
