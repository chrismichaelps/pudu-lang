// `pudu run --watch` starts a program again when its sources, or anything
// under an `--also` path, change, and tells it which start this is and what
// changed before it.
//
// Usage: node test/watch.mjs <path-to-pudu>

import { spawn, spawnSync } from "node:child_process";
import { appendFileSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import process from "node:process";

const given = process.argv[2];
if (!given) {
  console.error("usage: node test/watch.mjs <path-to-pudu>");
  process.exit(2);
}
// The program runs in a directory of its own, so a relative path to the
// compiler is resolved from here first.
const executable = given.includes("/") ? resolve(given) : given;

const root = realpathSync(mkdtempSync(join(tmpdir(), "pudu-watch-")));
const source = join(root, "src", "Main.pudu");
const page = join(root, "content", "page.md");
mkdirSync(join(root, "src"));
mkdirSync(join(root, "content"));
writeFileSync(page, "one\n");
writeFileSync(
  source,
  [
    "module Main",
    "",
    "import Std.Env as Env",
    "import Std.Io as Io",
    "",
    "fn main() -> Int {",
    '  let changed = Env.variableOr("PUDU_WATCH_CHANGED", "").trim().replace("\\n", ",")',
    '  let _said = Io.writeLine("start " + Env.variableOr("PUDU_WATCH", "-") + " changed=[" + changed + "]")',
    "  // Waiting on input keeps it running, as a service would.",
    "  let _waited = readLine()",
    "  0",
    "}",
    "",
  ].join("\n"),
);

const watcher = spawn(executable, ["run", "--watch", "--also", "content", source], { cwd: root, stdio: ["pipe", "pipe", "pipe"] });
let seen = "";
watcher.stdout.on("data", (chunk) => (seen += chunk.toString()));
watcher.stderr.on("data", (chunk) => (seen += chunk.toString()));

const failures = [];
const until = (wanted, timeoutMs = 20000) =>
  new Promise((resolve) => {
    const started = Date.now();
    const look = () => {
      if (seen.includes(wanted)) resolve(true);
      else if (Date.now() - started > timeoutMs) resolve(false);
      else setTimeout(look, 50);
    };
    look();
  });
const expect = async (wanted, what) => {
  if (!(await until(wanted))) failures.push(`${what}: never printed ${JSON.stringify(wanted)}`);
};

try {
  await expect("start 1 changed=[]", "the first start is 1 with nothing changed");
  writeFileSync(page, "two\n");
  await expect(`start 2 changed=[${page}]`, "a change under --also starts it again and is named");
  appendFileSync(source, "// edited\n");
  await expect(`start 3 changed=[${source}]`, "a source change starts it again and is named");
  // Stopped the way a supervisor stops it, the watch stops what it started.
  const stopped = new Promise((resolve) => watcher.on("exit", () => resolve(true)));
  watcher.kill("SIGTERM");
  const ended = await Promise.race([stopped, new Promise((resolve) => setTimeout(() => resolve(false), 10000))]);
  if (!ended) failures.push("the watch did not stop on SIGTERM");
  await new Promise((resolve) => setTimeout(resolve, 300));
  const left = spawnSync("pgrep", ["-f", source], { encoding: "utf8" }).stdout.trim();
  if (left) failures.push(`SIGTERM left the program running: ${left}`);
  const refused = await new Promise((resolve) => {
    const run = spawn(executable, ["run", "--watch", "--also", "nowhere", source]);
    let said = "";
    run.stderr.on("data", (chunk) => (said += chunk.toString()));
    run.on("close", (code) => resolve({ code, said }));
  });
  if (refused.code === 0 || !/cannot watch \S*nowhere/.test(refused.said)) {
    failures.push(`a missing --also path was not refused: exit ${refused.code}, ${JSON.stringify(refused.said)}`);
  }
} finally {
  watcher.kill();
  rmSync(root, { recursive: true, force: true });
}

if (failures.length > 0) {
  console.error("watch:\n  " + failures.join("\n  ") + "\n--- output ---\n" + seen);
  process.exit(1);
}
console.log(JSON.stringify({ starts: 3, refusedMissingPath: true }));
