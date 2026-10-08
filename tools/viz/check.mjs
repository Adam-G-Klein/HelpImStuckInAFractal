#!/usr/bin/env node
// Checks the systems viz (docs/viz/) without a browser:
//   node tools/viz/check.mjs            every pane listed in index.html loads, and every file:line
//                                       it cites exists at the pane's pinned commit
//   node tools/viz/check.mjs --print    also prints each cited line, to eyeball that it points
//                                       where the tooltip says
//   node tools/viz/check.mjs --pane fog-sim   limit to one pane
// Exit 0 clean, 1 on any broken reference or pane that fails to load. Layout and drawing errors
// only show in the browser (the red box bottom-left, and the console).
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const VIZ_DIR = join(ROOT, "docs", "viz");
const args = process.argv.slice(2);
const PRINT = args.includes("--print");
const ONLY = args.includes("--pane") ? args[args.indexOf("--pane") + 1] : null;

const git = (...a) => execFileSync("git", ["-C", ROOT, ...a], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });

const html = readFileSync(join(VIZ_DIR, "index.html"), "utf8");
const paneFiles = [...html.matchAll(/<script src="(panes\/[^"]+)"><\/script>/g)].map(m => m[1]);
if (!paneFiles.length) { console.error("no panes/*.js <script> lines in docs/viz/index.html"); process.exit(1); }

let bad = 0;
// The engine itself must at least parse (a syntax error there blanks the whole page).
try { new vm.Script(readFileSync(join(VIZ_DIR, "viz.js"), "utf8"), { filename: "viz.js" }); }
catch (e) { console.error(`✗ viz.js does not parse: ${e.message}`); bad++; }
const panes = [];
const sandbox = { VIZ: { pane: p => panes.push(p) }, console };
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const f of paneFiles) {
  const before = panes.length;
  try { vm.runInContext(readFileSync(join(VIZ_DIR, f), "utf8"), sandbox, { filename: f }); }
  catch (e) { console.error(`✗ ${f} failed to load: ${e.message}`); bad++; continue; }
  if (panes.length === before) { console.error(`✗ ${f} registered no pane (VIZ.pane was never called)`); bad++; }
}

// Every {file, line?} object anywhere in a pane's data.
function refs(obj, out = [], seen = new Set()) {
  if (!obj || typeof obj !== "object" || seen.has(obj)) return out;
  seen.add(obj);
  if (typeof obj.file === "string") out.push({ file: obj.file, line: obj.line });
  for (const v of Object.values(obj)) if (typeof v === "object") refs(v, out, seen);
  return out;
}

const fileCache = new Map();
function linesAt(commit, file) {
  const key = `${commit}:${file}`;
  if (!fileCache.has(key)) {
    try { fileCache.set(key, git("show", key).split("\n")); } catch { fileCache.set(key, null); }
  }
  return fileCache.get(key);
}

for (const p of panes) {
  if (ONLY && p.id !== ONLY) continue;
  try { git("cat-file", "-e", `${p.commit}^{commit}`); }
  catch { console.error(`✗ pane ${p.id}: commit ${p.commit} is not in this repo`); bad++; continue; }
  const remote = git("branch", "-r", "--contains", p.commit).trim();
  if (p.rows || !Array.isArray(p.tabs) || !p.tabs.length) {
    console.error(`✗ pane ${p.id}: needs a non-empty \`tabs\` array (pane-level \`rows\` is retired)`); bad++; continue;
  }
  const all = refs(p.tabs);
  const uniq = [...new Map(all.map(r => [`${r.file}:${r.line ?? ""}`, r])).values()];
  let paneBad = 0;
  for (const r of uniq) {
    const lines = linesAt(p.commit, r.file);
    if (!lines) { console.error(`✗ ${p.id}: ${r.file} does not exist at ${p.commit.slice(0, 9)}`); paneBad++; continue; }
    if (r.line !== undefined && (!Number.isInteger(r.line) || r.line < 1 || r.line > lines.length)) {
      console.error(`✗ ${p.id}: ${r.file}:${r.line} is past the end (${lines.length} lines)`); paneBad++; continue;
    }
    if (PRINT) console.log(`${r.file}:${r.line ?? "-"}\t${r.line ? lines[r.line - 1].trim().slice(0, 140) : ""}`);
  }
  bad += paneBad;
  console.log(`${paneBad ? "✗" : "✓"} pane ${p.id}: ${uniq.length} distinct file refs at ${p.commit.slice(0, 9)}, ${paneBad} broken` +
    (remote ? "" : "  (commit is on no remote branch: GitHub links 404 until it is pushed)"));
}
process.exit(bad ? 1 : 0);
