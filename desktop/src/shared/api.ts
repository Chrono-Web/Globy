// Contratto con il lato Rust (`src-tauri/src/session.rs`, `commands.rs`).
import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

export interface VoxView {
  documentId: string;
  text: string;
  permalink: string;
  createdAt: string;
  isUnread: boolean;
  isRead: boolean;
  isNotified: boolean;
}

export interface Preferences {
  mascotEnabled: boolean;
  permanence: boolean;
  mascotSoundEnabled: boolean;
  gazeFollowsPointer: boolean;
  didGreet: boolean;
  didOnboard: boolean;
  customSizesEnabled: boolean;
  textScale: number;
  buttonScale: number;
  globeScale: number;
  updateChecksEnabled: boolean;
}

export interface Platform {
  windows: boolean;
  linux: boolean;
  wayland: boolean;
}

/** Aggiornamenti (`src-tauri/src/updates.rs`). */
export interface UpdateState {
  currentVersion: string;
  phase: "idle" | "checking" | "available" | "downloading" | "installing";
  version: string | null;
  notesUrl: string | null;
  progress: number | null;
  message: string | null;
  needsPassword: boolean;
}

export const hasUpdate = (update: UpdateState | null): update is UpdateState =>
  !!update && ["available", "downloading", "installing"].includes(update.phase);

export interface AppState {
  recent: VoxView[];
  unreadCount: number;
  isSyncing: boolean;
  lastFailure: string | null;
  preferences: Preferences;
  launchAtLogin: boolean;
  usesFixture: boolean;
  platform: Platform;
  update: UpdateState | null;
}

export const getState = () => invoke<AppState>("get_state");

/** Stato iniziale e ogni aggiornamento successivo. */
export async function watchState(onState: (state: AppState) => void): Promise<UnlistenFn> {
  const unlisten = await listen<AppState>("state", (event) => onState(event.payload));
  onState(await getState());
  return unlisten;
}

export const commands = {
  openVox: (documentId: string) => invoke("open_vox", { documentId }),
  openPermalink: (permalink: string) => invoke("open_permalink", { permalink }),
  setPreferences: (patch: Partial<Preferences>) => invoke("set_preferences", { patch }),
  finishOnboarding: () => invoke("finish_onboarding"),
  setLaunchAtLogin: (on: boolean) => invoke("set_launch_at_login", { on }),
  resetLocalData: () => invoke("reset_local_data"),
  uninstall: () => invoke<void>("uninstall"),
  showSettings: () => invoke("show_settings"),
  hideMenu: () => invoke("hide_menu"),
  quit: () => invoke("quit"),
  hasGlass: () => invoke<boolean>("has_glass"),
  checkUpdates: () => invoke("check_updates"),
  installUpdate: () => invoke("install_update"),
  simulatePublication: (count: number) => invoke("simulate_publication", { count }),
};

/** Crea un elemento con classe e testo, senza HTML interpretato: i VOX sono testo. */
export function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  text?: string,
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}
