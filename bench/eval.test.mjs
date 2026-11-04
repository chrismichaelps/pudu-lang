import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { rtsStatistics, summarize } from "./eval.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const harness = join(root, "bench/eval.mjs");
const outputs = { Arrays: "249999500000\n", Calls: "196418\n", Iterate: "2399960\n", Loop: "26999982\n", Maps: "68749875000\n", MultiMap: "640000\n", Records: "0\n" };
const stats = "1,234,567 bytes allocated in the heap\n42,123 bytes maximum residency (2 sample(s))\nTotal time 0.125s (0.250s elapsed)\n";
const digest = (path) => createHash("sha256").update(readFileSync(path)).digest("hex");

function fake(t, behavior = "") {
  const directory = mkdtempSync(join(tmpdir(), "pudu-eval-test-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const binary = join(directory, "fake pudu");
  writeFileSync(binary, `#!/usr/bin/env node\nconst path = require('node:path');
if (process.argv[2] === 'version') { console.log('fixture-pudu'); process.exit(0); }
if (process.env.PUDU_CACHE !== 'off' || !path.isAbsolute(process.env.PUDU_LIB) || process.env.GHCRTS) process.exit(90);
if (!['tree', 'compiled'].includes(process.env.PUDU_EVAL)) process.exit(91);
if (JSON.stringify(process.argv.slice(4)) !== JSON.stringify(['+RTS', '-s', '-RTS'])) process.exit(92);
const name = path.basename(process.argv[3], '.pudu');
${behavior}
process.stdout.write(${JSON.stringify(outputs)}[name]);
process.stderr.write(${JSON.stringify(stats)});\n`);
  chmodSync(binary, 0o755);
  return binary;
}
function invoke(binary, args = [], wrapper = false) {
  return spawnSync(wrapper ? "bash" : process.execPath, [wrapper ? join(root, "bench/eval.sh") : harness, binary, "--json", ...args], {
    encoding: "utf8", timeout: 120000, env: { ...process.env, PUDU_CACHE: "/ambient/cache", GHCRTS: "-N31" },
  });
}

test("all fixed workload outputs retain five samples, milliseconds and identities", (t) => {
  const binary = fake(t);
  const result = invoke(binary);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.cases.length, 14);
  assert.deepEqual(report.fixtures.map((f) => f.name), Object.keys(outputs));
  assert.equal(report.metadata.samples, 5);
  assert.equal(report.metadata.cache, "off");
  assert.equal(report.metadata.units, "milliseconds");
  assert.equal(report.metadata.binarySha256, digest(binary));
  assert.ok(isAbsolute(report.metadata.library));
  assert.ok(report.metadata.cpu);
  assert.ok(report.metadata.node);
  for (const fixture of report.fixtures) {
    assert.equal(fixture.expectedOutput, outputs[fixture.name]);
    assert.equal(fixture.sha256, digest(fixture.path));
  }
  for (const row of report.cases) {
    assert.equal(row.samples.length, 5);
    assert.ok(row.samples.every((s) => s.wallMs > 0 && s.allocatedBytes === 1234567 && s.residencyBytes === 42123));
    assert.ok(row.samples.every((s) => s.rtsCpuMs === 125 && s.rtsElapsedMs === 250));
    const sorted = row.samples.map((s) => s.wallMs).sort((a, b) => a - b);
    assert.equal(row.minimumMs, sorted[0]);
    assert.equal(row.medianMs, sorted[2]);
  }
});

test("wrapper preserves spaced paths and selected case arguments", (t) => {
  const result = invoke(fake(t), ["--samples", "2", "--benchmarks", "Loop", "--modes", "compiled"], true);
  assert.equal(result.status, 0, result.stderr);
  const [row] = JSON.parse(result.stdout).cases;
  assert.equal(row.name, "Loop");
  assert.equal(row.mode, "compiled");
  assert.equal(row.samples.length, 2);
  assert.equal(row.medianMs, (row.samples[0].wallMs + row.samples[1].wallMs) / 2);
});

for (const [name, behavior, diagnostic] of [
  ["nonzero exit", "process.exit(7);", "exit 7"],
  ["wrong output", "process.stdout.write('999\\n'); process.exit(0);", "unexpected result"],
  ["missing output", "process.exit(0);", "unexpected result"],
  ["missing final newline", "process.stdout.write('249999500000'); process.exit(0);", "unexpected result"],
  ["unexpected warning", "process.stderr.write('warning[W3003] unexpected\\n');", "unexpected diagnostic"],
  ["missing statistics", `process.stdout.write(${JSON.stringify(outputs.Arrays)}); process.exit(0);`, "missing RTS"],
]) test(`refuses ${name} without a completed report`, (t) => {
  const result = invoke(fake(t, behavior), ["--samples", "1", "--benchmarks", "Arrays", "--modes", "tree"]);
  assert.equal(result.status, 1);
  assert.equal(result.stdout, "");
  assert.ok(result.stderr.includes(diagnostic), result.stderr);
});

for (const args of [["--samples", "0"], ["--modes", "native"], ["--benchmarks", "Unknown"], ["--json"], ["--timeout-ms", "0"]]) {
  test(`refuses invalid options ${args.join(" ")}`, (t) => {
    const result = invoke(fake(t), args);
    assert.equal(result.status, 1);
    assert.equal(result.stdout, "");
  });
}

test("statistics and even medians use independent numerical expectations", () => {
  assert.deepEqual(rtsStatistics(stats), { allocatedBytes: 1234567, residencyBytes: 42123, rtsCpuMs: 125, rtsElapsedMs: 250 });
  assert.equal(summarize([{ wallMs: 9 }, { wallMs: 1 }, { wallMs: 4 }, { wallMs: 2 }]).medianMs, 3);
  assert.throws(() => rtsStatistics(""), /missing RTS/);
});
