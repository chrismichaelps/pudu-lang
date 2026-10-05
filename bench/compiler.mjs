import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { arch, cpus, platform, release, tmpdir } from "node:os";
import { dirname, join, relative, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const usage = "usage: node bench/compiler.mjs <pudu> [--sizes 1000,2000,4000] [--samples 3] [--lib root] [--rts N2,A8m] [--json]";
const args = process.argv.slice(2);
const options = new Map();
const boolean = new Set(["--json"]);
const valued = new Set(["--sizes", "--samples", "--lib", "--rts"]);
const scriptRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
let executable;
try {
  if (!args[0] || args[0].startsWith("--")) throw new Error(usage);
  executable = realpathSync(args.shift());
  while (args.length) {
    const flag = args.shift();
    if (options.has(flag)) throw new Error(`duplicate option ${flag}`);
    if (boolean.has(flag)) options.set(flag, true);
    else if (valued.has(flag) && args.length && !args[0].startsWith("--")) options.set(flag, args.shift());
    else throw new Error(`unknown or incomplete option ${flag}`);
  }
} catch (error) {
  console.error(error.message);
  process.exit(2);
}
const positive = (value) => /^\d+$/.test(value) && Number.isSafeInteger(Number(value)) && Number(value) > 0;
const sizes = (options.get("--sizes") ?? "1000,2000,4000").split(",");
const sampleOption = options.get("--samples") ?? "3";
const library = resolve(options.get("--lib") ?? join(scriptRoot, "packages/pudu/v0.1/lib"));
if (!sizes.every(positive) || !positive(sampleOption) || !existsSync(join(library, "Std"))) {
  console.error("sizes and samples must be positive integers, and --lib must contain Std");
  process.exit(2);
}
const samples = Number(sampleOption);
const rts = (options.get("--rts") ?? "").split(",").filter(Boolean).map((flag) => flag.startsWith("-") ? flag : `-${flag}`);
const workspace = mkdtempSync(join(tmpdir(), "pudu-compiler-"));
const environment = { ...process.env, PUDU_LIB: library, NO_COLOR: "1" };

function source(name, text) {
  const directory = join(workspace, name);
  mkdirSync(directory, { recursive: true });
  const entry = join(directory, `${name}.pudu`);
  writeFileSync(entry, `module ${name}\n${text}\n`);
  return entry;
}
function standardModules(directory) {
  return readdirSync(directory, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name)).flatMap((entry) => {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) return standardModules(path);
    if (!entry.isFile() || !entry.name.endsWith(".pudu")) return [];
    return [relative(library, path).slice(0, -5).split(/[\\/]/).join(".")];
  });
}
function graph(size) {
  const name = `Graph${size}`;
  const directory = join(workspace, name);
  mkdirSync(join(directory, "Graph"), { recursive: true });
  for (let i = 0; i < size; i += 1) {
    const imports = [...new Set([i - 1, Math.floor(i / 2)])].filter((other) => other >= 0 && other < i);
    writeFileSync(join(directory, "Graph", `M${i}.pudu`), [
      `module Graph.M${i}`,
      ...imports.map((other) => `import Graph.M${other}`),
      `export type Item${i} = { value: Int, label: Str }`,
      `export type Shape${i} = Dot${i} | Line${i}(Int) | Box${i}(Int, Int)`,
      `export trait Measure${i} { fn measure(self: &Self) -> Int }`,
      `impl Measure${i} for Item${i} { fn measure(self: &Self) -> Int { self.value } }`,
      `export fn total${i}(value: Int) -> Int { value${imports.map((other) => ` + M${other}.total${other}(value)`).join("")} }`,
    ].join("\n") + "\n");
  }
  return source(name, `import Graph.M${size - 1}\nfn main() -> Int { M${size - 1}.total${size - 1}(1) }`);
}
function stats(stderr) {
  const bytes = (name) => {
    const found = new RegExp(`([\\d,]+) bytes ${name}`).exec(stderr);
    if (!found) throw new Error(`missing RTS ${name}`);
    return Number(found[1].replaceAll(",", ""));
  };
  const times = (name) => {
    const found = new RegExp(`${name}\\s+time\\s+([\\d.]+)s\\s+\\(\\s*([\\d.]+)s elapsed`).exec(stderr);
    if (!found) throw new Error(`missing RTS ${name} time`);
    return [Number(found[1]) * 1000, Number(found[2]) * 1000];
  };
  const [cpuMs, rtsElapsedMs] = times("Total");
  return { cpuMs, rtsElapsedMs, mutatorCpuMs: times("MUT")[0], gcCpuMs: times("GC")[0],
    allocatedBytes: bytes("allocated"), residencyBytes: bytes("maximum residency") };
}
function measure(testCase, cache) {
  const started = process.hrtime.bigint();
  const result = spawnSync(executable, ["check", testCase.entry, "+RTS", "-s", ...rts, "-RTS"], {
    encoding: "utf8", env: { ...environment, PUDU_CACHE: cache }, timeout: 120000, maxBuffer: 16 * 1024 * 1024,
  });
  const wallMs = Number(process.hrtime.bigint() - started) / 1e6;
  if (result.error) throw new Error(`${testCase.name}: ${result.error.message}`);
  const output = `${result.stdout}\n${result.stderr}`;
  const codes = [...output.matchAll(/^(?:error|warning)\[([^\]]+)\]/gm)].map((match) => match[1]).sort();
  const expected = testCase.diagnostics ?? [];
  const expectedStatus = expected.length ? 1 : 0;
  if (result.status !== expectedStatus || JSON.stringify(codes) !== JSON.stringify(expected) || !result.stdout.includes(`${testCase.entry}: `)) {
    throw new Error(`${testCase.name}: unexpected check result (exit ${result.status})\n${output}`);
  }
  return { wallMs, ...stats(result.stderr) };
}
function summarize(points) {
  const sorted = points.map((point) => point.wallMs).sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return { minimumMs: sorted[0], medianMs: sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2, samples: points };
}

try {
  const cases = [
    { name: "startup", units: 1, entry: source("Baseline", "fn main() -> Int { 0 }") },
    { name: "invalid type", units: 1, entry: source("Invalid", "fn main() -> Int { \"wrong\" }"), diagnostics: ["E3001"] },
  ];
  for (const count of sizes.map(Number)) {
    cases.push({ name: "declarations", units: count, entry: source(`Declarations${count}`,
      Array.from({ length: count }, (_, i) => `fn f${i}(x: Int) -> Int { x + ${i} }`).join("\n")) });
    cases.push({ name: "statements", units: count, entry: source(`Statements${count}`,
      `fn main() -> Int {\nvar total = 0\n${Array.from({ length: count }, (_, i) => `total = total + ${i % 97}`).join("\n")}\ntotal\n}`) });
    cases.push({ name: "branch statements", units: count, entry: source(`Branches${count}`,
      `fn main() -> Int {\nvar total = 0\n${Array.from({ length: count }, () => "total = total + if true { 1 } else { 2 }").join("\n")}\ntotal\n}`) });
    cases.push({ name: "negative statements", units: count, entry: source(`Negatives${count}`,
      `fn main() -> Int {\nvar total = 0\n${Array.from({ length: count }, () => "total = total + -1").join("\n")}\ntotal\n}`) });
    cases.push({ name: "generic evidence", units: count, entry: source(`Generics${count}`,
      "trait Compare { fn same(self: &Self, other: &Self) -> Bool }\n" +
      Array.from({ length: count }, (_, i) => `fn g${i}[T: Compare](x: &T) -> Bool { x.same(x) }`).join("\n")) });
    cases.push({ name: "constants", units: count, entry: source(`Constants${count}`,
      Array.from({ length: count }, (_, i) => `const C${i}: Int = ${i ? `C${i - 1} + 1` : "0"}`).join("\n")) });
  }
  for (const count of [25, 50, 100, 200]) cases.push({ name: "module graph", units: count, entry: graph(count) });
  const std = standardModules(join(library, "Std"));
  for (const [name, modules] of [["library composition", ["Std.Json", "Std.Html", "Std.Http", "Std.Db", "Std.Log", "Std.Iter", "Std.Yaml"]], ["all standard library", std]]) {
    cases.push({ name, units: modules.length, entry: source(name === "library composition" ? "Composition" : "AllStd",
      modules.map((module, i) => `import ${module} as Library${i}`).join("\n") + "\nfn main() -> Int { 0 }") });
  }
  const version = spawnSync(executable, ["version"], { encoding: "utf8", env: environment });
  if (version.error || version.status !== 0) throw new Error("cannot read compiler version");
  const report = {
    metadata: { timestamp: new Date().toISOString(), executable, binarySha256: createHash("sha256").update(readFileSync(executable)).digest("hex"),
      compilerVersion: version.stdout.trim(), library, platform: platform(), architecture: arch(), release: release(),
      cpu: cpus()[0]?.model, logicalCpus: cpus().length, node: process.version, rts, samples, sizes: sizes.map(Number) },
    cases: [],
  };
  for (const [index, testCase] of cases.entries()) {
    const cold = Array.from({ length: samples }, () => measure(testCase, "off"));
    const cache = join(workspace, `cache${index}`);
    const firstCached = measure(testCase, cache);
    const warm = Array.from({ length: samples }, () => measure(testCase, cache));
    const row = { name: testCase.name, units: testCase.units, expectedDiagnostics: testCase.diagnostics ?? [],
      cold: summarize(cold), firstCached, warm: summarize(warm) };
    report.cases.push(row);
    if (!options.has("--json")) {
      const allocation = Math.min(...cold.map((point) => point.allocatedBytes)) / 1048576;
      console.log(`${row.name.padEnd(22)} ${String(row.units).padStart(5)}  cold ${row.cold.minimumMs.toFixed(1).padStart(8)} ms  warm ${row.warm.minimumMs.toFixed(1).padStart(8)} ms  ${allocation.toFixed(1).padStart(8)} MiB`);
    }
  }
  if (options.has("--json")) console.log(JSON.stringify(report, null, 2));
} catch (error) {
  console.error(`compiler benchmark failed: ${error.message}`);
  process.exitCode = 1;
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
