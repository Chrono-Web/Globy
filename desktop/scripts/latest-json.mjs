// Scrive latest.json, il feed del plugin updater di Tauri (docs/DISTRIBUZIONE.md).
// Uso: node scripts/latest-json.mjs <versione> <URL base> <target>=<file firmato> … > latest.json
// Esempio: node scripts/latest-json.mjs 0.3.0 https://github.com/Chrono-Web/GLOBY/releases/download/v0.3.0 \
//            windows-x86_64-nsis=out/Globy-Windows.exe linux-x86_64-appimage=out/Globy-Linux.AppImage
// Accanto a ogni file deve esserci la sua firma `<file>.sig`, creata da `tauri build`.
import { readFileSync } from "node:fs";
import { basename } from "node:path";

const [version, baseUrl, ...pairs] = process.argv.slice(2);
if (!version || !baseUrl || pairs.length === 0) {
  console.error("Uso: node scripts/latest-json.mjs <versione> <URL base> <target>=<file> …");
  process.exit(1);
}

const platforms = {};
for (const pair of pairs) {
  const [target, file] = pair.split("=");
  platforms[target] = {
    signature: readFileSync(`${file}.sig`, "utf8").trim(),
    url: `${baseUrl}/${basename(file)}`,
  };
}

const feed = {
  version,
  notes: `https://github.com/Chrono-Web/GLOBY/releases/tag/v${version}`,
  pub_date: new Date().toISOString(),
  platforms,
};
console.log(JSON.stringify(feed, null, 2));
