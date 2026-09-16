import { cpSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node test/lint.mjs <pudu-executable>");
  process.exit(2);
}

const fixture = resolve("test-fixtures/lint/RedundantBool.pudu");
const first = spawnSync(executable, ["lint", "--json", fixture], { encoding: "utf8" });
if (first.status !== 1) fail(`lint finding status was ${first.status}: ${first.stderr}`);

let findings;
try {
  findings = JSON.parse(first.stdout);
} catch (problem) {
  fail(`lint output is not JSON: ${problem.message}\n${first.stdout}`);
}
if (findings.length !== 4) fail(`expected four findings, received ${findings.length}`);
for (const finding of findings) {
  if (finding.code !== "W7101") fail(`unexpected lint code ${finding.code}`);
  if (finding.rule !== "redundant-boolean-comparison") fail(`unexpected rule ${finding.rule}`);
  if (finding.fix?.applicability !== "safe") fail("finding did not carry a safe fix");
  if (finding.fix?.replacement !== "value") fail("finding replacement was not exact");
}

const temporary = mkdtempSync(join(tmpdir(), "pudu-lint-"));
try {
  const target = join(temporary, "RedundantBool.pudu");
  cpSync(fixture, target);
  run("fix", ["lint", "--json", "--fix", target]);
  run("check", ["check", target]);
  run("clean lint", ["lint", "--json", target]);
  const rewritten = readFileSync(target, "utf8");
  if (rewritten.includes("== true") || rewritten.includes("!= false")) {
    fail("safe Boolean comparisons remained after --fix");
  }
} finally {
  rmSync(temporary, { recursive: true, force: true });
}

console.log(JSON.stringify({ findings: 4, fixed: true, checked: true, clean: true }));

function run(label, arguments_) {
  const result = spawnSync(executable, arguments_, { encoding: "utf8" });
  if (result.status !== 0) fail(`${label} failed: ${result.stdout}${result.stderr}`);
  if (label === "fix" || label === "clean lint") {
    const parsed = JSON.parse(result.stdout);
    if (!Array.isArray(parsed) || parsed.length !== 0) fail(`${label} did not report clean JSON`);
  }
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
