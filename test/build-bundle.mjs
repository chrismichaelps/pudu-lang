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
import { mkdtempSync, writeFileSync, copyFileSync, existsSync } from "node:fs";
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

if (failures.length > 0) {
  console.error("build-bundle: a built program must run with nothing installed.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

console.log(JSON.stringify({ built: true, ranElsewhere: true, environment: "empty" }));
