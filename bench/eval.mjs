import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { accessSync, constants, readFileSync, realpathSync, statSync } from "node:fs";
import { arch, cpus, platform, release } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const expected = new Map([
  ["Arrays", "249999500000\n"], ["Calls", "196418\n"], ["Iterate", "2399960\n"],
  ["Loop", "26999982\n"], ["Maps", "68749875000\n"], ["MultiMap", "640000\n"], ["Records", "0\n"],
]);
const usage = "usage: node bench/eval.mjs <pudu> [--samples 5] [--lib root] [--benchmarks Arrays,Calls,Iterate,Loop,Maps,MultiMap,Records] [--modes tree,compiled] [--timeout-ms 300000] [--json]";
const sha256 = (file) => createHash("sha256").update(readFileSync(file)).digest("hex");
const positive = (value) => /^\d+$/.test(value) && Number.isSafeInteger(Number(value)) && Number(value) > 0;

export function summarize(samples) {
  const sorted = samples.map((sample) => sample.wallMs).sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return { minimumMs: sorted[0], medianMs: sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2, samples };
}

export function rtsStatistics(stderr) {
  const bytes = (name) => {
    const match = new RegExp(`([\\d,]+) bytes ${name}`).exec(stderr);
    if (!match) throw new Error(`missing RTS ${name}`);
    return Number(match[1].replaceAll(",", ""));
  };
  const time = /Total\s+time\s+([\d.]+)s\s+\(\s*([\d.]+)s elapsed/.exec(stderr);
  if (!time) throw new Error("missing RTS Total time");
  return { allocatedBytes: bytes("allocated"), residencyBytes: bytes("maximum residency"),
    rtsCpuMs: Number(time[1]) * 1000, rtsElapsedMs: Number(time[2]) * 1000 };
}

function options(argv) {
  const args = [...argv];
  if (!args[0] || args[0].startsWith("--")) throw new Error(usage);
  const executable = realpathSync(args.shift());
  if (!statSync(executable).isFile()) throw new Error("binary must be a regular file");
  accessSync(executable, constants.X_OK);
  const opts = new Map();
  const valued = new Set(["--samples", "--lib", "--benchmarks", "--modes", "--timeout-ms"]);
  while (args.length) {
    const flag = args.shift();
    if (opts.has(flag)) throw new Error(`duplicate option ${flag}`);
    if (flag === "--json") opts.set(flag, true);
    else if (valued.has(flag) && args.length && !args[0].startsWith("--")) opts.set(flag, args.shift());
    else throw new Error(`unknown or incomplete option ${flag}`);
  }
  const count = opts.get("--samples") ?? "5";
  const limit = opts.get("--timeout-ms") ?? "300000";
  if (!positive(count) || !positive(limit)) throw new Error("samples and timeout must be positive integers");
  const select = (flag, fallback, allowed) => {
    const names = (opts.get(flag) ?? fallback).split(",");
    if (new Set(names).size !== names.length || !names.every((name) => allowed.includes(name))) {
      throw new Error(`invalid ${flag}: ${names.join(",")}`);
    }
    return names;
  };
  const names = select("--benchmarks", [...expected.keys()].join(","), [...expected.keys()]);
  const modes = select("--modes", "tree,compiled", ["tree", "compiled"]);
  const library = realpathSync(opts.get("--lib") ?? process.env.PUDU_LIB ?? join(root, "packages/pudu/v0.1/lib"));
  if (!statSync(join(library, "Std")).isDirectory()) throw new Error("library must contain Std");
  return { executable, library, names, modes, samples: Number(count), timeout: Number(limit), json: opts.has("--json") };
}

function toolVersion(command) {
  const result = spawnSync(command, ["--numeric-version"], { encoding: "utf8", timeout: 10000 });
  return !result.error && result.status === 0 ? result.stdout.trim() : null;
}

function measure(config, fixture, mode, environment) {
  const started = process.hrtime.bigint();
  const result = spawnSync(config.executable, ["run", fixture.path, "+RTS", "-s", "-RTS"], {
    encoding: "utf8", env: { ...environment, PUDU_EVAL: mode }, timeout: config.timeout, maxBuffer: 16 * 1024 * 1024,
  });
  const wallMs = Number(process.hrtime.bigint() - started) / 1e6;
  if (result.error) throw new Error(`${fixture.name}/${mode}: ${result.error.message}`);
  if (result.status !== 0 || result.signal || result.stdout !== fixture.expectedOutput) {
    throw new Error(`${fixture.name}/${mode}: unexpected result (exit ${result.status}, signal ${result.signal}, stdout ${JSON.stringify(result.stdout)})\n${result.stderr}`);
  }
  if (/(?:error|warning)\[[^\]]+\]/.test(result.stderr)) throw new Error(`${fixture.name}/${mode}: unexpected diagnostic\n${result.stderr}`);
  return { wallMs, ...rtsStatistics(result.stderr) };
}

export function run(argv) {
  const config = options(argv);
  // Remove ambient RTS tuning so every sample uses the recorded invocation.
  const environment = { ...process.env, PUDU_CACHE: "off", PUDU_LIB: config.library, NO_COLOR: "1" };
  delete environment.GHCRTS;
  const fixtures = config.names.map((name) => {
    const path = realpathSync(join(root, "bench/eval", `${name}.pudu`));
    return { name, path, sha256: sha256(path), expectedOutput: expected.get(name) };
  });
  const version = spawnSync(config.executable, ["version"], { encoding: "utf8", env: environment, timeout: 10000 });
  if (version.error || version.status !== 0) throw new Error("cannot read compiler version");
  const report = {
    metadata: { timestamp: new Date().toISOString(), scope: "process startup + checking + runtime", units: "milliseconds",
      cache: "off", executable: config.executable, binarySha256: sha256(config.executable), binaryBytes: statSync(config.executable).size,
      compilerVersion: version.stdout.trim(), library: config.library, platform: platform(), architecture: arch(), release: release(),
      cpu: cpus()[0]?.model, logicalCpus: cpus().length, node: process.version,
      availableToolchain: { ghc: toolVersion("ghc"), cabal: toolVersion("cabal") },
      rtsFlags: ["-s"], ambientRtsRemoved: true, samples: config.samples, modes: config.modes, timeoutMs: config.timeout },
    fixtures, cases: [],
  };
  for (const fixture of fixtures) {
    for (const mode of config.modes) {
      const samples = Array.from({ length: config.samples }, () => measure(config, fixture, mode, environment));
      report.cases.push({ name: fixture.name, mode, ...summarize(samples) });
    }
  }
  return report;
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const report = run(process.argv.slice(2));
    if (process.argv.includes("--json")) console.log(JSON.stringify(report, null, 2));
    else {
      console.log("Cache off; process startup + checking + runtime; all durations in milliseconds");
      console.log("benchmark  evaluator      min ms   median ms");
      for (const row of report.cases) console.log(`${row.name.padEnd(10)} ${row.mode.padEnd(10)} ${row.minimumMs.toFixed(3).padStart(10)} ${row.medianMs.toFixed(3).padStart(11)}`);
    }
  } catch (error) {
    console.error(`runtime benchmark failed: ${error.message}`);
    process.exitCode = 1;
  }
}
