// A built program runs on a machine that has nothing installed.
//
// This cannot be checked from inside the language, and it cannot be checked by
// running the built file in the shell that built it: what is under test is
// that the file needs nothing from around it. So the program is run with an
// empty environment — no PATH, no PUDU_LIB, no working directory it knows —
// from a directory it was not built in.
//
// Usage: node test/build-bundle.mjs [path-to-pudu]

import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, copyFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import process from "node:process";

const executable = process.argv[2] ?? "pudu";
const directory = mkdtempSync(join(tmpdir(), "pudu-build-"));

// The program uses the standard library so the bundle has to carry it: a
// bundle holding only what the author wrote would run here and fail wherever
// the library happened to be missing.
const program = `module Bundled

import Std.Io as Io
import Std.Regex as Regex
import Std.Text as Text

fn main() -> Int {
  let pattern = match Regex.compile("^[a-z]+-[0-9]+$") {
    case Ok(built) => built
    case Err(_) => Regex.unmatchable()
  }
  let matched = Regex.isMatch(&pattern, "order-42")
  let upper = Text.toTitle("bundled")
  match Io.writeLine(upper + " " + display(matched)) {
    case Ok(_) => 0
    case Err(_) => 1
  }
}
`;

const source = join(directory, "Bundled.pudu");
const built = join(directory, "bundled");
writeFileSync(source, program);

const failures = [];

execFileSync(executable, ["build", source, "-o", built], { stdio: "pipe" });

if (!existsSync(built)) {
  console.error("build-bundle: pudu build wrote no file");
  process.exit(1);
}

// Run it the way a deployment would: elsewhere, and with nothing inherited.
const elsewhere = join(mkdtempSync(join(tmpdir(), "pudu-elsewhere-")), "shipped");
copyFileSync(built, elsewhere);

const run = (path, extra = []) =>
  execFileSync("/usr/bin/env", ["-i", path, ...extra], { stdio: "pipe" }).toString().trim();

const first = run(built);
if (first !== "Bundled true") {
  failures.push(`the built file printed ${JSON.stringify(first)}`);
}

const moved = run(elsewhere);
if (moved !== "Bundled true") {
  failures.push(`copied elsewhere it printed ${JSON.stringify(moved)}`);
}

// A bundle is the program, so the compiler's own words are the program's
// arguments and must not be acted on.
const withArguments = run(elsewhere, ["--help", "version"]);
if (withArguments !== "Bundled true") {
  failures.push(`given compiler-looking arguments it printed ${JSON.stringify(withArguments)}`);
}

// The compiler itself must still behave as a compiler.
const version = execFileSync(executable, ["version"], { stdio: "pipe" }).toString().trim();
if (!version.startsWith("pudu ")) {
  failures.push(`the compiler no longer answers version: ${JSON.stringify(version)}`);
}

// A build that cannot be written must say so and change nothing. The write is
// the size of the compiler, so it is the step most likely to fail for reasons
// the program has nothing to do with — and a partial one left at the target
// would be a file the right name and shape to look built, discovered only by
// whoever runs it.
const refused = join(directory, "missing-directory", "app");
let refusal = "";
try {
  execFileSync(executable, ["build", source, "-o", refused], { stdio: "pipe" });
  failures.push("a build into a directory that does not exist was not refused");
} catch (problem) {
  refusal = String(problem.stderr ?? "");
}
if (!refusal.includes("could not write")) {
  failures.push(`a refused build did not say it could not write: ${JSON.stringify(refusal.slice(0, 120))}`);
}
if (refusal.includes("CallStack") || refusal.includes("ghc-internal")) {
  failures.push("a refused build reported the failure as a crash rather than as a message");
}

// The target a failed build was aimed at keeps what it held. Aimed at the
// program built a moment ago, that program must still run afterwards.
const guarded = join(directory, "guarded");
copyFileSync(built, guarded);
try {
  execFileSync(executable, ["build", join(directory, "NotThere.pudu"), "-o", guarded], {
    stdio: "pipe"
  });
} catch {
  // Expected: the program named does not exist.
}
if (run(guarded) !== "Bundled true") {
  failures.push("a failed build left the program that was already there unrunnable");
}
if (existsSync(guarded + ".pending")) {
  failures.push("a failed build left its partial file behind");
}

// A bundle is the size of the compiler, so a run that leaves two behind costs
// a developer a gigabyte every few times they run the gates. Removed whatever
// the outcome, since a failing run leaks just as much as a passing one.
for (const scratch of [directory, join(elsewhere, "..")]) {
  try {
    rmSync(scratch, { recursive: true, force: true });
  } catch {
    // A directory that could not be removed is not a reason to fail the run.
  }
}

if (failures.length > 0) {
  console.error("build-bundle: a built program must run with nothing installed.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

console.log(JSON.stringify({ built: true, ranElsewhere: true, environment: "empty" }));
