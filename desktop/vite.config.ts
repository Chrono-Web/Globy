import { resolve } from "node:path";
import { defineConfig } from "vite";

// Tre pagine, una per finestra: elenco dei VOX, Impostazioni, Globy.
export default defineConfig({
  clearScreen: false,
  server: { port: 1420, strictPort: true },
  build: {
    target: ["es2022", "chrome110", "safari16"],
    rollupOptions: {
      input: {
        menu: resolve(import.meta.dirname, "menu.html"),
        settings: resolve(import.meta.dirname, "settings.html"),
        mascot: resolve(import.meta.dirname, "mascot.html"),
      },
    },
  },
});
