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
import { mkdtempSync, mkdirSync, existsSync, readFileSync, writeFileSync, rmSync } from "node:fs";
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
for (const expected of [
  "pudu.toml",
  ".gitignore",
  "README.md",
  "src/Main.pudu",
  "src/App/Greeting.pudu",
  "src/Domain/Greeting.pudu",
  "test/App/GreetingTest.pudu",
]) {
  if (!existsSync(join(project, expected))) failures.push(`init did not write ${expected}`);
}

const mainSource = readFileSync(join(project, "src/Main.pudu"), "utf8");
const applicationSource = readFileSync(join(project, "src/App/Greeting.pudu"), "utf8");
const domainSource = readFileSync(join(project, "src/Domain/Greeting.pudu"), "utf8");
if (!mainSource.includes("import App.Greeting")) failures.push("Main does not depend on the application layer");
if (!applicationSource.includes("import Domain.Greeting")) failures.push("App does not depend on the domain layer");
if (domainSource.includes("import App.") || domainSource.includes("import Main")) {
  failures.push("the domain layer depends outward");
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
inProject("fmt --check", ["fmt", "--check", "src", "test"]);

// The project begins without lint debt, so enabling the release policy later
// does not start by suppressing generated code.
inProject("lint", ["lint", "src", "test"]);

// Declaration search over the project's own sources is not a package search.
const found = inProject("declaration search", ["search", "forName", "src/Domain/Greeting.pudu"]);
if (!found.includes("forName")) failures.push(`declaration search did not find forName: ${JSON.stringify(found.slice(0, 160))}`);

// A file under src/ searches src once; a suite under test/ searches itself,
// then src. The same holds for a manifest that still names src as a path
// dependency of itself.
const lookedIn = (file) => {
  writeFileSync(join(project, file), "module Probe\n\nimport Nowhere\n");
  try {
    execFileSync(executable, ["check", file], { cwd: project, stdio: "pipe" });
    return "";
  } catch (problem) {
    return (String(problem.stderr ?? "") + String(problem.stdout ?? "")).match(/looked in ([^\n]*)/)?.[1] ?? "";
  } finally {
    rmSync(join(project, file));
  }
};
const generatedManifest = readFileSync(join(project, "pudu.toml"), "utf8");
for (const [label, manifest] of [
  ["generated", generatedManifest],
  ["self dependency", `${generatedManifest}src = "src"\nslashed = "./src/"\n`],
]) {
  writeFileSync(join(project, "pudu.toml"), manifest);
  const fromSource = lookedIn("src/Probe.pudu");
  const fromTest = lookedIn("test/Probe.pudu");
  if (fromSource !== "src") failures.push(`${label}: a file under src looked in ${JSON.stringify(fromSource)}`);
  if (fromTest !== "test, src") failures.push(`${label}: a suite under test looked in ${JSON.stringify(fromTest)}`);
  inProject(`${label}: test imports project modules`, ["test"]);
}
writeFileSync(join(project, "pudu.toml"), generatedManifest);

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
const suite = join(project, "test", "App", "GreetingTest.pudu");
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

// A distributable library owns the module root its manifest announces. A
// local Git dependency exercises the actual lock writer without a network.
const workspace = join(project, "..");
const library = join(workspace, "package");
const helper = join(workspace, "helper");
const packageHome = join(workspace, "pudu-home");
const libraryRun = (label, args) => {
  try {
    return execFileSync(executable, args, {
      cwd: library, stdio: "pipe", env: { ...process.env, PUDU_HOME: packageHome },
    }).toString();
  } catch (problem) {
    failures.push(`${label} failed: ${String(problem.stderr ?? problem).trim().slice(0, 200)}`);
    return "";
  }
};

try {
  execFileSync(executable, ["init", library, "--lib", "--name", "@alice/package"], { stdio: "pipe" });
  const manifestPath = join(library, "pudu.toml");
  const manifest = readFileSync(manifestPath, "utf8");
  for (const field of [
    'name = "@alice/package"', 'version = "0.1.0"', 'root = "Package"',
    'source = "src"', 'description = ""', 'license = ""', 'keywords = []',
  ]) {
    if (!manifest.includes(field)) failures.push(`library manifest omitted ${field}`);
  }
  if (!existsSync(join(library, "src/Package.pudu")) || !existsSync(join(library, "test/PackageTest.pudu"))) {
    failures.push("library source or test does not follow its package root");
  }
  libraryRun("library check", ["check", "src/Package.pudu"]);
  libraryRun("library test", ["test"]);
  libraryRun("library format", ["fmt", "--check", "src", "test"]);
  libraryRun("library lint", ["lint", "src", "test"]);

  mkdirSync(join(helper, "src"), { recursive: true });
  writeFileSync(join(helper, "pudu.toml"), '[package]\nname = "helper"\nversion = "0.1.0"\nsource = "src"\nroot = "Helper"\n');
  writeFileSync(join(helper, "src/Helper.pudu"), 'module Helper\nexport fn answer() -> Int { 42 }\n');
  execFileSync("git", ["init", "-q"], { cwd: helper });
  execFileSync("git", ["add", "."], { cwd: helper });
  execFileSync("git", ["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-qm", "init"], { cwd: helper });
  writeFileSync(manifestPath, manifest + `helper = { git = "file://${helper}" }\n`);
  libraryRun("library install", ["install"]);
  const lockPath = join(library, "pudu.lock");
  const firstLock = existsSync(lockPath) ? readFileSync(lockPath, "utf8") : "";
  if (!firstLock.includes('name = "helper"')) failures.push("library install did not lock its Git dependency");
  libraryRun("library locked install", ["install", "--locked"]);
  if (firstLock !== readFileSync(lockPath, "utf8")) failures.push("locked install changed pudu.lock");
  libraryRun("library check with dependency", ["check", "src/Package.pudu"]);
  libraryRun("library test with dependency", ["test"]);

  // Publication validates the generated manifest, sources, tests, clean tree,
  // and tag path against a bare local remote.
  const remote = join(workspace, "package-remote.git");
  execFileSync("git", ["init", "-q", "--bare", remote]);
  execFileSync("git", ["init", "-q"], { cwd: library });
  execFileSync("git", ["config", "user.name", "Test"], { cwd: library });
  execFileSync("git", ["config", "user.email", "test@example.com"], { cwd: library });
  execFileSync("git", ["add", "."], { cwd: library });
  execFileSync("git", ["commit", "-qm", "publishable"], { cwd: library });
  execFileSync("git", ["remote", "add", "origin", remote], { cwd: library });
  const released = libraryRun("library release", ["release", "0.1.0"]);
  if (!released.includes("released @alice/package 0.1.0")) failures.push("generated library was not accepted by the release command");
  const tagged = execFileSync("git", ["show-ref", "--tags"], { cwd: remote }).toString();
  if (!tagged.includes("refs/tags/v0.1.0")) failures.push("release did not push its package tag");

  const consumer = join(workspace, "consumer");
  execFileSync(executable, ["init", consumer], { stdio: "pipe" });
  const consumerRun = (label, args) => {
    try {
      return execFileSync(executable, args, {
        cwd: consumer, stdio: "pipe", env: { ...process.env, PUDU_HOME: packageHome },
      }).toString();
    } catch (problem) {
      failures.push(`${label} failed: ${String(problem.stderr ?? problem).trim().slice(0, 200)}`);
      return "";
    }
  };
  consumerRun("install released library", ["install", `git+file://${remote}#v0.1.0`]);
  writeFileSync(join(consumer, "src/UsePackage.pudu"),
    "module UsePackage\n\nimport Package as Package\n\nexport fn message() -> Str { Package.greeting(\"Ada\") }\n");
  consumerRun("check released library import", ["check", "src/UsePackage.pudu"]);
  const installedManifest = join(consumer, "deps/package/pudu.toml");
  if (!existsSync(installedManifest)) failures.push("the released library was not materialized in the consumer");
} catch (problem) {
  failures.push(`library workflow failed: ${String(problem.stderr ?? problem).trim().slice(0, 200)}`);
}

// The project built a bundle, which is the size of the compiler. Removed
// whatever the outcome: a failing run leaks as much as a passing one.
try {
  rmSync(join(project, ".."), { recursive: true, force: true });
} catch {
  // A directory that could not be removed is not a reason to fail the run.
}

if (failures.length > 0) {
  console.error("scaffold: a new project must work from the moment it is made.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

console.log(JSON.stringify({
  initialized: true,
  layered: true,
  ran: true,
  tested: true,
  formatted: true,
  linted: true,
  built: true,
  packageReady: true,
  lockStable: true,
  sourceRootOnce: true,
  declarationSearch: true,
}));
