import { cpSync, mkdirSync } from "node:fs";
import { basename, resolve } from "node:path";

const projectRoot = process.cwd();
const webDir = resolve(projectRoot, "www");
const assetFiles = [
  "index.html",
  "styles.css",
  "script.js",
  "sw.js",
  "manifest.webmanifest",
  "icon.svg",
  "favicon.ico",
  "mini-todo-preview.png",
];

mkdirSync(webDir, { recursive: true });

for (const relativePath of assetFiles) {
  cpSync(resolve(projectRoot, relativePath), resolve(webDir, basename(relativePath)));
}

console.log(`Synced ${assetFiles.length} web assets to ${webDir}`);
