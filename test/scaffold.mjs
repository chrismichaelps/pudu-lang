// What somebody meets in their first five minutes.
//
// `pudu init` writes a project, and every command the project's own README
// names is then run against it. The failure this exists to stop is the one
// nobody in the repository can see: every command here works in a checkout,
// where the compiler finds its standard library beside its own sources, and
// the first thing a new project does is fail to import `Std.Io` from
// somewhere else on the disk.
//
// So the project is made outside the repository and the commands are run from
// inside it, which is where a person would be standing.
//
// Usage: node test/scaffold.mjs <path-to-pudu>

import { execFileSync } from "node:child_process";
import { mkdtempSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import process from "node:process";

const executable = process.argv[2] ?? "pudu";
const project = join(mkdtempSync(join(tmpdir(), "pudu-scaffold-")), "greeter");

const failures = [];

/// Run a command in the project and answer what it printed, or record why it
/// could not be run at all.
const inProject = (label, args) => {
  try {
    return execFileSync(executable, args, { cwd: project, stdio: "pipe" }).toString();
  } catch (problem) {
    const said = String(problem.stderr ?? "") + String(problem.stdout ?? "");
    failures.push(`${label} failed: ${said.trim().slice(0, 200)}`);
    return "";
  }
};

execFileSync(executable, ["init", project], { stdio: "pipe" });

// A project is the files somebody expects to find, and one that leaves out the
// suite leaves `pudu test` with nothing to find in a project that has just
// been told to run it.
for (const expected of ["pudu.toml", ".gitignore", "README.md", "src/Main.pudu", "test/MainTest.pudu"]) {
  if (!existsSync(join(project, expected))) failures.push(`init did not write ${expected}`);
}

// Running it says something. A program that prints nothing has not told the
// person who just made it whether any of this works.
const ran = inProject("run", ["run", "src/Main.pudu"]);
if (!ran.includes("Hello")) {
  failures.push(`run printed nothing recognisable: ${JSON.stringify(ran.slice(0, 80))}`);
}

// The suite the project starts with passes, and counts what it checked.
const tested = inProject("test", ["test"]);
if (!tested.includes("1/1 suites passed")) {
  failures.push(`test did not pass: ${JSON.stringify(tested.slice(0, 200))}`);
}

// The project is formatted the way the formatter formats. A new project that
// fails its own `fmt --check` teaches that the check is noise.
inProject("fmt --check", ["fmt", "--check", "src/Main.pudu", "test/MainTest.pudu"]);

// It compiles to one file that runs.
inProject("build", ["build", "src/Main.pudu", "-o", "app"]);
if (existsSync(join(project, "app"))) {
  try {
    const built = execFileSync(join(project, "app"), { stdio: "pipe" }).toString();
    if (!built.includes("Hello")) failures.push("the built file printed nothing recognisable");
  } catch (problem) {
    failures.push(`the built file did not run: ${String(problem.stderr ?? "").slice(0, 120)}`);
  }
}

// A suite that stops holding must say so. A starting project whose test cannot
// fail has given the person a test that means nothing.
const suite = join(project, "test", "MainTest.pudu");
writeFileSync(suite, readFileSync(suite, "utf8").replace("Hello, Ada.", "Hello, Grace."));
let broke = "";
try {
  execFileSync(executable, ["test"], { cwd: project, stdio: "pipe" });
  failures.push("a suite with a check that does not hold was reported as passing");
} catch (problem) {
  broke = String(problem.stdout ?? "");
}
if (!broke.includes("FAIL")) {
  failures.push(`a broken suite did not report FAIL: ${JSON.stringify(broke.slice(0, 160))}`);
}

if (failures.length > 0) {
  console.error("scaffold: a new project must work from the moment it is made.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

console.log(JSON.stringify({ initialized: true, ran: true, tested: true, formatted: true, built: true }));
