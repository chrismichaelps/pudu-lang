import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export function testBundleEnvironment(executable, runtime) {
  const root = mkdtempSync(join(tmpdir(), "pudu-bundle-env-"));
  const failures = [];
  try {
    const sourceRoot = join(root, "source", "App");
    const runRoot = join(root, "execution");
    mkdirSync(sourceRoot, { recursive: true });
    mkdirSync(runRoot);
    writeFileSync(join(runRoot, "marker.txt"), "caller-directory");
    const source = join(sourceRoot, "Probe.pudu");
    writeFileSync(source, `module App.Probe

import Std.Env as Env

fn main() -> Int {
  print(show(Env.variable("PUDU_LIB")))
  match readFile("marker.txt") {
    case Ok(marker) => { print(marker) }
    case Err(_) => { return 1 }
  }
  0
}
`);
    const built = join(root, "application");
    const arguments_ = ["build", source, "-o", built];
    if (runtime) arguments_.push("--runtime", runtime);
    execFileSync(executable, arguments_, { stdio: "pipe" });
    for (const value of [undefined, "", "/pudu-unavailable-library", "/pudu library with spaces"]) {
      const environment = value === undefined ? {} : { PUDU_LIB: value };
      const expected = value === undefined ? "None" : `Some(${JSON.stringify(value)})`;
      const outcome = spawnSync(built, [], { cwd: runRoot, env: environment, encoding: "utf8" });
      if (outcome.status !== 0 || outcome.stdout !== `${expected}\ncaller-directory\n`) {
        failures.push(`bundle environment ${expected}: status ${outcome.status}, signal ${outcome.signal}, error ${outcome.error?.message ?? "none"}, output ${JSON.stringify(outcome.stdout)}, diagnostic ${JSON.stringify(outcome.stderr)}`);
      }
    }
  } catch (problem) {
    failures.push(`bundle environment check failed: ${String(problem.stdout ?? "")}${String(problem.stderr ?? problem.message)}`);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
  return failures;
}
