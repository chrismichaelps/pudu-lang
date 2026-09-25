// How checking a program grows with the number of modules it is made of.
//
// A program of M modules used to cost more than M times one module: every
// module prepared every other module's interface for itself, so the work was
// M copies of something as large as the whole graph. The signal is the same as
// in scaling.mjs — a doubling of modules that costs more than twice as much —
// and allocation is reported beside time because it is what the collector pays
// for, and does not vary with how busy the machine is.
//
// The graph is sparse, as real ones are: each module imports the one before it
// and the one at half its index, and declares a record, a sum, a trait, an
// implementation and two functions that use what it imported.
//
// Usage: node bench/graph.mjs <path-to-pudu> [--sizes 25,50,100,200] [--json]

import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import process from "node:process";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node bench/graph.mjs <path-to-pudu> [--sizes a,b,c] [--json]");
  process.exit(2);
}
const asJson = process.argv.includes("--json");
const given = process.argv.indexOf("--sizes");
const sizes = given > 0 ? process.argv[given + 1].split(",").map(Number) : [25, 50, 100, 200];
const samples = 3;

const workspace = mkdtempSync(join(tmpdir(), "pudu-graph-"));

function moduleSource(index) {
  const imports = [...new Set([index - 1, Math.floor(index / 2)])].filter((other) => other >= 0 && other < index);
  const lines = [`module Graph.M${index}`, ""];
  for (const other of imports) lines.push(`import Graph.M${other}`);
  if (imports.length > 0) lines.push("");
  lines.push(`export type Item${index} = { value: Int, label: Str }`);
  lines.push("");
  lines.push(`export type Shape${index} = Dot${index} | Line${index}(Int) | Box${index}(Int, Int)`);
  lines.push("");
  lines.push(`export trait Measure${index} {`);
  lines.push(`  fn measure(self: &Self) -> Int`);
  lines.push(`  fn doubled(self: &Self) -> Int = self.measure() * 2`);
  lines.push("}");
  lines.push("");
  lines.push(`impl Measure${index} for Item${index} {`);
  lines.push(`  fn measure(self: &Self) -> Int { self.value }`);
  lines.push("}");
  lines.push("");
  lines.push(`export fn make${index}(value: Int) -> Item${index} { Item${index} { value, label: "m${index}" } }`);
  lines.push("");
  const reach = imports.map((other) => `M${other}.total${other}(value)`);
  const body = reach.length > 0 ? `value + ${reach.join(" + ")}` : "value";
  lines.push(`export fn total${index}(value: Int) -> Int { ${body} }`);
  lines.push("");
  lines.push(`export fn area${index}(shape: Shape${index}) -> Int {`);
  lines.push("  match shape {");
  lines.push(`    case Dot${index} => 0`);
  lines.push(`    case Line${index}(length) => length`);
  lines.push(`    case Box${index}(width, height) => width * height`);
  lines.push("  }");
  lines.push("}");
  return lines.join("\n") + "\n";
}

function buildGraph(size) {
  const root = join(workspace, `m${size}`);
  mkdirSync(join(root, "Graph"), { recursive: true });
  for (let index = 0; index < size; index += 1) {
    writeFileSync(join(root, "Graph", `M${index}.pudu`), moduleSource(index));
  }
  const last = size - 1;
  writeFileSync(
    join(root, "Main.pudu"),
    [
      "module Main",
      "",
      `import Graph.M${last}`,
      "",
      `fn main() -> Int { M${last}.total${last}(1) }`,
      "",
    ].join("\n"),
  );
  return join(root, "Main.pudu");
}

function measure(entry) {
  let best = null;
  for (let sample = 0; sample < samples; sample += 1) {
    const started = process.hrtime.bigint();
    const run = spawnSync(executable, ["check", entry, "+RTS", "-s", "-RTS"], { encoding: "utf8" });
    const elapsed = Number(process.hrtime.bigint() - started) / 1e6;
    if (run.status !== 0) return { failed: (run.stdout || run.stderr || "").split("\n")[0] };
    const allocated = Number((/([\d,]+) bytes allocated/.exec(run.stderr)?.[1] ?? "0").replaceAll(",", ""));
    if (best === null || elapsed < best.milliseconds) best = { milliseconds: elapsed, allocated };
  }
  return best;
}

const results = [];
for (const size of sizes) {
  results.push({ modules: size, ...measure(buildGraph(size)) });
}
rmSync(workspace, { recursive: true, force: true });

if (asJson) {
  console.log(JSON.stringify(results, null, 2));
} else {
  let previous = null;
  for (const result of results) {
    if (result.failed) {
      console.log(`${String(result.modules).padStart(5)} modules  did not check: ${result.failed}`);
      previous = null;
      continue;
    }
    const megabytes = (result.allocated / 1048576).toFixed(1);
    const ratio =
      previous && previous.milliseconds >= 20
        ? `  x${(result.milliseconds / previous.milliseconds).toFixed(2)} time  x${(result.allocated / previous.allocated).toFixed(2)} alloc`
        : "";
    console.log(
      `${String(result.modules).padStart(5)} modules  ${result.milliseconds.toFixed(1).padStart(8)} ms  ${megabytes.padStart(8)} MB${ratio}`,
    );
    previous = result;
  }
}
