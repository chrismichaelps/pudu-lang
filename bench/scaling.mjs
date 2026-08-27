// How the compiler's cost grows with the size of what it is given.
//
// "Where should this be faster" is answered by measuring, and the answer is
// almost never the machine code. Every large win so far was a growth rate:
// character access cost what it skipped, so a scan of n characters cost n
// squared, and no amount of instruction selection would have shown that. A
// doubling that costs more than twice as much is the signal.
//
// Usage: node bench/scaling.mjs <path-to-pudu> [--sizes 2000,4000,8000] [--json]

import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import process from "node:process";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node bench/scaling.mjs <path-to-pudu> [--sizes a,b,c] [--json]");
  process.exit(2);
}
const asJson = process.argv.includes("--json");
const given = process.argv.indexOf("--sizes");
const sizes =
  given > 0 ? process.argv[given + 1].split(",").map(Number) : [4000, 8000, 16000, 32000];

const workspace = mkdtempSync(join(tmpdir(), "pudu-bench-"));

const cases = [
  {
    name: "parse and check declarations",
    module: "Big",
    unit: "declarations",
    command: "check",
    build: n =>
      ["module Big"]
        .concat(Array.from({ length: n }, (_, i) => `fn f${i}(x: Int) -> Int { x + ${i} }`))
        .concat(["export fn main() -> Int { 0 }"])
        .join("\n"),
  },
  {
    name: "parse and check statements in one body",
    module: "Body",
    unit: "statements",
    command: "check",
    build: n =>
      ["module Body", "export fn main() -> Int {", "  var total = 0"]
        .concat(Array.from({ length: n }, (_, i) => `  total = total + ${i % 97}`))
        .concat(["  total", "}"])
        .join("\n"),
  },
  {
    name: "evaluate a counting loop",
    module: "Loop",
    unit: "iterations",
    scale: 40,
    command: "run",
    build: n =>
      [
        "module Loop",
        "export fn main() -> Int {",
        "  var total = 0",
        "  var index = 0",
        `  while index < ${n} {`,
        "    total = total + index",
        "    index = index + 1",
        "  }",
        "  total / 1000000",
        "}",
      ].join("\n"),
  },
  {
    name: "scan text through a cursor",
    module: "Scan",
    unit: "characters",
    scale: 20,
    command: "run",
    build: n =>
      [
        "module Scan",
        "export fn main() -> Int {",
        `  var rest = "a".repeat(${n})`,
        "  var seen = 0",
        "  while !rest.isEmpty() {",
        "    seen = seen + 1",
        "    rest = rest.drop(1)",
        "  }",
        "  seen / 1000",
        "}",
      ].join("\n"),
  },
];

// A run that failed is not a run that was fast, and the difference is invisible
// in a duration: a program that does not compile exits sooner than one that
// does. Anything the compiler wrote to its error stream means the figure
// measures a failure, and the harness says so rather than reporting a number.
// Diagnostics are written where a reader sees them, which is the output stream,
// not the error stream. A harness that watched only the error stream called a
// program that never compiled the fastest one it measured.
const diagnosticsIn = said =>
  String(said)
    .split("\n")
    .filter(line => /^(error|warning)\[/.test(line))
    .join("\n");

const timeOnce = (command, path) => {
  const started = process.hrtime.bigint();
  let complaint = "";
  try {
    const said = execFileSync(executable, [command, path], {
      stdio: ["ignore", "pipe", "pipe"],
      encoding: "utf8",
    });
    complaint = diagnosticsIn(said);
  } catch (error) {
    // A non-zero exit is the program's own answer: `run` reports its result as
    // the exit status. Only a failure to launch is a failure to measure.
    if (error.status === undefined) throw error;
    complaint = diagnosticsIn(String(error.stdout ?? "") + String(error.stderr ?? ""));
  }
  const milliseconds = Number(process.hrtime.bigint() - started) / 1e6;
  if (complaint.trim().length > 0) {
    console.error(`\nbench: ${command} ${path} did not run:\n${complaint.trim()}\n`);
    process.exit(1);
  }
  return milliseconds;
};

// Three samples and the smallest of them, because a machine doing something
// else adds time and never takes it away. One sample per point once reported a
// front end growing at x3.60 that a careful measure put at x2.27.
const timeBest = (command, path) =>
  Math.min(timeOnce(command, path), timeOnce(command, path), timeOnce(command, path));

// Launching the process costs the same whatever it is asked to do, and at small
// sizes it is most of what a run costs. Taking it off is what makes a growth
// ratio mean the work rather than the launch.
const baselinePath = join(workspace, "Baseline.pudu");
writeFileSync(baselinePath, "module Baseline\nexport fn main() -> Int { 0 }\n");
timeOnce("run", baselinePath);
const baseline = timeBest("run", baselinePath);

// Anything this small is the machine, not the program.
const noiseFloor = Math.max(5, baseline * 0.25);

const results = [];
for (const testCase of cases) {
  const row = { name: testCase.name, unit: testCase.unit, points: [] };
  let previous = null;
  for (const given of sizes) {
    // Each case needs enough work to rise above the noise; a loop iteration is
    // far cheaper than a declaration to check, so the sizes are not the same.
    const size = given * (testCase.scale ?? 1);
    // The file is named for the module it holds, because Pudu requires them to
    // agree. Naming it for the case instead made every program fail to compile,
    // and a program that fails exits sooner than one that runs.
    const directory = join(workspace, `${testCase.module}_${size}`);
    mkdirSync(directory, { recursive: true });
    const path = join(directory, `${testCase.module}.pudu`);
    writeFileSync(path, testCase.build(size) + "\n");
    timeOnce(testCase.command, path);
    const milliseconds = Math.max(0.1, timeBest(testCase.command, path) - baseline);
    // Below the floor the figure is scheduling, not work, and a ratio of two
    // such figures says nothing. Reporting one anyway is how a tool learns to
    // cry wolf: an earlier version called a linear loop superlinear at x12.
    const measurable = milliseconds >= noiseFloor && previous >= noiseFloor;
    row.points.push({
      size,
      milliseconds: Number(milliseconds.toFixed(1)),
      growth: previous === null || !measurable ? null : milliseconds / previous,
      belowFloor: milliseconds < noiseFloor,
    });
    previous = milliseconds;
  }
  results.push(row);
}

rmSync(workspace, { recursive: true, force: true });

if (asJson) {
  console.log(JSON.stringify({ sizes, baseline: Number(baseline.toFixed(1)), results }, null, 1));
} else {
  for (const row of results) {
    console.log(`\n${row.name}  (${row.unit})`);
    for (const point of row.points) {
      const ratio = point.growth === null ? "" : ` x${point.growth.toFixed(2)}`;
      const flag =
        point.belowFloor
          ? "   (below the noise floor)"
          : point.growth !== null && point.growth > 2.4
            ? "   <- superlinear"
            : "";
      const size = String(point.size).padStart(8);
      const ms = String(point.milliseconds).padStart(9);
      console.log(`  ${size}  ${ms}ms${ratio}${flag}`);
    }
  }
  console.log(`\nProcess start (${baseline.toFixed(1)}ms) is subtracted, so each figure is work.`);
  console.log(
    `Each size doubles. A ratio near 2 is linear; sustained above ~2.4 is not.`,
  );
  console.log(
    `Figures under ${noiseFloor.toFixed(1)}ms are scheduling rather than work, and carry no ratio.`,
  );
}
