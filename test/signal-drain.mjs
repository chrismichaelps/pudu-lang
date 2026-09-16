// A program asked to stop finishes what it was doing.
//
// This cannot be checked from inside the language: the request arrives from
// another process, and the thing being tested is what happens to a program
// that is already running. So the test runs one, sends it the signal a
// supervisor sends, and reads what it did with the moment it was given.
//
// Usage: node test/signal-drain.mjs [path-to-pudu]

import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import process from "node:process";

const executable = process.argv[2] ?? "pudu";

const program = `module Draining

import Std.Io as Io
import Std.Signal as Signal

fn say(line: Str) -> () {
  match Io.writeLine(line) {
    case Ok(_) => {}
    case Err(_) => {}
  }
}

fn main() -> Int {
  if !Signal.listen() {
    say("unheard")
    return 1
  }
  say("ready")
  var spins = 0
  while Signal.running() && spins < 100000000 {
    spins = spins + 1
  }
  if Signal.requested() {
    say("drained")
    0
  } else {
    say("timeout")
    2
  }
}
`;

const directory = mkdtempSync(join(tmpdir(), "pudu-signal-"));
const source = join(directory, "Draining.pudu");
writeFileSync(source, program);

const failures = [];

const run = signal =>
  new Promise((resolve, reject) => {
    const child = spawn(executable, ["run", source], { stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    let sent = false;
    const give = setTimeout(() => reject(new Error("the program never said it was ready")), 30000);

    child.stdout.on("data", chunk => {
      out += chunk;
      // Only once it is running does the signal test what it is meant to.
      if (!sent && out.includes("ready")) {
        sent = true;
        child.kill(signal);
      }
    });
    child.stderr.on("data", chunk => (out += chunk));
    child.on("error", reject);
    child.on("close", (code, killedBy) => {
      clearTimeout(give);
      resolve({ code, killedBy, out });
    });
  });

for (const signal of ["SIGTERM", "SIGINT"]) {
  const { code, killedBy, out } = await run(signal);
  const lines = out.split("\n").map(line => line.trim()).filter(Boolean);

  if (killedBy) {
    failures.push(`${signal}: the program was killed by ${killedBy} instead of stopping on its own`);
    continue;
  }
  if (!lines.includes("drained")) {
    failures.push(`${signal}: the program did not drain; it said ${JSON.stringify(lines)}`);
  }
  if (code !== 0) {
    failures.push(`${signal}: exited ${code}, so it did not treat the request as an orderly stop`);
  }
}

if (failures.length > 0) {
  console.error("signal-drain: a request to stop must reach the program.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

console.log(JSON.stringify({ signals: 2, drained: 2 }));
