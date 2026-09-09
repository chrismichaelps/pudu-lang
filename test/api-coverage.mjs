// How much of the public library the fixtures actually exercise.
//
// The library exports a few thousand names and the fixtures reach some of
// them. Which ones is not something a reader can hold in their head, and a
// module gaining an export gains no test with it — so the untested part grows
// quietly, and is discovered by whoever first calls one of those names.
//
// The compiler already knows what is public: `pudu api --json` is the same
// index the API-lifecycle check reads, so this measures against what is
// actually exported rather than against a list kept by hand beside it.
//
// A reference is a qualified call — `Text.trim(...)` against `import Std.Text
// as Text` — which is how the fixtures are written. That undercounts a name
// only ever called some other way, which is the right direction for a floor to
// err in: it can ask for more coverage than exists, never less.
//
// Usage: node test/api-coverage.mjs <path-to-pudu> [--report] [--module Std.X]

import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";

const executable = process.argv[2] ?? "pudu";
const wantsReport = process.argv.includes("--report");
const onlyIndex = process.argv.indexOf("--module");
const only = onlyIndex >= 0 ? process.argv[onlyIndex + 1] : null;

/// Every file under a directory with the given extension.
const filesUnder = (root, extension) => {
  const found = [];
  const walk = (directory) => {
    for (const entry of readdirSync(directory)) {
      const path = join(directory, entry);
      if (statSync(path).isDirectory()) walk(path);
      else if (path.endsWith(extension)) found.push(path);
    }
  };
  walk(root);
  return found;
};

const library = filesUnder("packages/pudu/v0.1/lib", ".pudu");
const index = JSON.parse(
  execFileSync(executable, ["api", "--json", ...library], { stdio: "pipe", maxBuffer: 64 * 1024 * 1024 })
    .toString()
);

const exported = new Map();
for (const item of index.exports) {
  if (!exported.has(item.module)) exported.set(item.module, new Set());
  exported.get(item.module).add(item.name);
}

// What the fixtures name, by the module the name belongs to.
const referenced = new Map();
const note = (moduleName, member) => {
  if (!referenced.has(moduleName)) referenced.set(moduleName, new Set());
  referenced.get(moduleName).add(member);
};

for (const path of filesUnder("test-fixtures", ".pudu")) {
  const text = readFileSync(path, "utf8");
  const alias = new Map();
  for (const line of text.split("\n")) {
    const aliased = /^\s*import\s+([A-Za-z0-9_.]+)\s+as\s+([A-Za-z0-9_]+)/.exec(line);
    if (aliased) {
      alias.set(aliased[2], aliased[1]);
      continue;
    }
    // A selective import brings its names in unqualified, so they are reached
    // by writing them and there is no qualifier to look for.
    const selective = /^\s*import\s+([A-Za-z0-9_.]+)\s*\{([^}]*)\}/.exec(line);
    if (selective) {
      for (const picked of selective[2].split(",")) {
        const name = picked.trim();
        if (name) note(selective[1], name);
      }
      continue;
    }
    const plain = /^\s*import\s+([A-Za-z0-9_.]+)\s*$/.exec(line);
    if (plain) alias.set(plain[1].split(".").pop(), plain[1]);
  }
  for (const [, qualifier, member] of text.matchAll(/\b([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)/g)) {
    const moduleName = alias.get(qualifier);
    if (moduleName) note(moduleName, member);
  }
}

let total = 0;
let covered = 0;
const gaps = [];
for (const [moduleName, names] of exported) {
  if (only && moduleName !== only) continue;
  const reached = referenced.get(moduleName) ?? new Set();
  const missing = [...names].filter((name) => !reached.has(name)).sort();
  total += names.size;
  covered += names.size - missing.length;
  if (missing.length > 0) gaps.push({ module: moduleName, missing });
}

if (wantsReport) {
  gaps.sort((a, b) => b.missing.length - a.missing.length);
  for (const gap of gaps) {
    console.log(`${gap.module}  (${gap.missing.length} not reached)`);
    console.log("  " + gap.missing.join(", "));
  }
  console.log("");
}

// The floor only ever rises. A module gaining an export without a fixture
// reaching it drops the figure below this and fails, which is the whole point:
// the untested part of the library cannot grow without somebody saying so.
const floor = 2052;
const percent = total === 0 ? 100 : Math.floor((covered / total) * 100);

console.log(JSON.stringify({ exports: total, covered, percent, floor }));

if (!only && covered < floor) {
  console.error(
    `\napi-coverage: fixtures reach ${covered} of ${total} exports, below the floor of ${floor}.`
  );
  console.error("Run with --report to see which names are not reached.\n");
  process.exit(1);
}
