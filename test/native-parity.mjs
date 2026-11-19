// Native executables against the interpreter, across the program corpus.
//
// Every program with a `main` under the corpus roots that passes checking runs
// under `pudu run` and as its `pudu build --native` executable, with the same
// environment and no input. Standard output, standard error and exit status
// must agree, and a native refusal of such a program is a failure.
//
// Usage: node test/native-parity.mjs <path-to-pudu> [--jobs N] [--only <substring>]

import { spawn } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { availableParallelism, tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import process from "node:process";

const pudu = resolve(process.argv[2] ?? "pudu");
const option = (name) => {
  const at = process.argv.indexOf(name);
  return at >= 0 ? process.argv[at + 1] : null;
};
const jobs = Number(option("--jobs") ?? Math.max(1, availableParallelism() - 1));
const only = option("--only");

const roots = ["test-fixtures", "examples", "website/playground/examples"];
const runLimit = 20_000;
const buildLimit = 300_000;

/// Programs whose output varies between any two runs; only their exit status
/// is compared.
const nondeterministic = new Map([
  ["test-fixtures/lanes/UsesOverlapPairs.pudu", "prints elapsed milliseconds"],
  ["website/playground/examples/19-time-and-randomness.pudu", "prints elapsed milliseconds"],
  ["examples/media/Studio.pudu", "counts video frames presented in a time window"],
  ["test-fixtures/stdlib/LaunchAudioStream.pudu", "counts audio bytes delivered in a time window"],
  ["test-fixtures/stdlib/UsesHttpServer.pudu", "logs the client's ephemeral port"],
]);

/// Programs that serve on a fixed port until stopped. They never finish, and
/// two of them run at once race for the port: the loser exits early with a
/// bind error, so its interpreted run looks finished and its native run then
/// serves forever. They are outside the comparison.
const servers = new Map([
  ["examples/web/Notes.pudu", "serves on 127.0.0.1:8080 until stopped"],
  ["examples/social/Main.pudu", "serves until stopped"],
]);

/// Programs that differ today, each with its open issue. A listed program that
/// agrees fails the gate, so the entry leaves with the fix.
const knownDifferences = new Map([]);

/// Every `.pudu` file under a directory.
const programsUnder = (directory) =>
  readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) return programsUnder(path);
    return path.endsWith(".pudu") ? [path] : [];
  });

/// Runs a command to completion or the limit, collecting both streams.
const run = (command, args, cwd, limit) =>
  new Promise((done) => {
    const child = spawn(command, args, { cwd, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
    const timer = setTimeout(() => { timedOut = true; child.kill("SIGKILL"); }, limit);
    child.on("close", (code, signal) => {
      clearTimeout(timer);
      done({ status: code ?? signal, stdout, stderr, timedOut });
    });
  });

/// Where a program runs from and the path it is named by there. A file whose
/// name is not its module's is copied under the module's path.
const placement = (path, source, scratch) => {
  const header = /^\s*module\s+([A-Za-z0-9_.]+)/m.exec(source);
  const segments = header ? header[1].split(".") : [basename(path, ".pudu")];
  const named = `${segments.at(-1)}.pudu`;
  if (basename(path) === named) {
    let root = dirname(path);
    for (let level = 1; level < segments.length; level++) root = dirname(root);
    return { cwd: root, file: relative(root, path) };
  }
  const file = join(...segments) + ".pudu";
  mkdirSync(dirname(join(scratch, file)), { recursive: true });
  copyFileSync(path, join(scratch, file));
  return { cwd: scratch, file };
};

/// The first lines where two texts differ, for a failure report.
const firstDifference = (left, right) => {
  const a = left.split("\n");
  const b = right.split("\n");
  const at = a.findIndex((line, index) => line !== b[index]);
  const line = at < 0 ? a.length : at;
  return `line ${line + 1}: interpreter ${JSON.stringify(a[line] ?? "")}, native ${JSON.stringify(b[line] ?? "")}`;
};

/// One program's verdict: compared, skipped with a reason, or failed with one.
const compare = async (path, scratch) => {
  const source = readFileSync(path, "utf8");
  if (basename(path).startsWith("Rejects") || servers.has(path)) return { path, kind: "outside" };
  if (!/^\s*(export\s+)?fn\s+main\s*\(/m.test(source)) return { path, kind: "outside" };
  const { cwd, file } = placement(path, source, scratch);
  if ((await run(pudu, ["check", file], cwd, buildLimit)).status !== 0) return { path, kind: "outside" };
  const interpreted = await run(pudu, ["run", file], cwd, runLimit);
  if (interpreted.timedOut) return { path, kind: "skipped", reason: "the interpreter did not finish" };
  const executable = join(scratch, "program");
  const built = await run(pudu, ["build", "--native", file, "-o", executable], cwd, buildLimit);
  if (built.status !== 0) {
    const reason = (built.stderr || built.stdout).split("\n").slice(0, 2).join(" ").trim();
    return { path, kind: "failed", reason: `native build failed: ${reason}` };
  }
  const native = await run(executable, [], cwd, runLimit * 2);
  if (native.timedOut) return { path, kind: "failed", reason: "the native executable did not finish" };
  if (native.status !== interpreted.status) {
    return { path, kind: "failed", reason: `exit ${interpreted.status} interpreted, ${native.status} native` };
  }
  if (nondeterministic.has(path)) return { path, kind: "compared" };
  for (const stream of ["stdout", "stderr"]) {
    if (native[stream] !== interpreted[stream]) {
      return { path, kind: "failed", reason: `${stream} ${firstDifference(interpreted[stream], native[stream])}` };
    }
  }
  return { path, kind: "compared" };
};

/// A verdict against the known differences: an expected one is reported, and a
/// listed program that agrees is a failure until its entry is removed.
const judged = (verdict) => {
  const issue = knownDifferences.get(verdict.path);
  if (issue === undefined) return verdict;
  if (verdict.kind === "failed") return { ...verdict, kind: "known", reason: `#${issue}: ${verdict.reason}` };
  if (verdict.kind === "compared") {
    return { ...verdict, kind: "failed", reason: `agrees now; remove it from knownDifferences (#${issue})` };
  }
  return verdict;
};

const programs = roots.flatMap(programsUnder).filter((path) => !only || path.includes(only)).sort();
const scratchRoot = mkdtempSync(join(tmpdir(), "pudu-parity-"));
const verdicts = [];
let next = 0;
try {
  await Promise.all(Array.from({ length: jobs }, async (_, worker) => {
    while (next < programs.length) {
      const index = next++;
      const scratch = join(scratchRoot, String(worker), String(index));
      mkdirSync(scratch, { recursive: true });
      verdicts.push(judged(await compare(programs[index], scratch)));
      rmSync(scratch, { recursive: true, force: true });
    }
  }));
} finally {
  rmSync(scratchRoot, { recursive: true, force: true });
}

const counted = (kind) => verdicts.filter((verdict) => verdict.kind === kind);
const failed = counted("failed").sort((a, b) => a.path.localeCompare(b.path));
for (const { path, reason } of counted("skipped")) console.log(`skip  ${path}: ${reason}`);
for (const { path, reason } of counted("known")) console.log(`known ${path}: ${reason}`);
for (const { path, reason } of failed) console.log(`FAIL  ${path}: ${reason}`);
console.log(`native-parity: ${counted("compared").length} agree, ${failed.length} differ, `
  + `${counted("known").length} known, ${counted("skipped").length} skipped, `
  + `${counted("outside").length} outside the comparison`);
process.exit(failed.length === 0 ? 0 : 1);
