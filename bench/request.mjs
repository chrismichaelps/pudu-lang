// What one request costs, end to end, over a real socket.
//
// The compiler's own speed is measured by `bench/scaling.mjs`. This measures
// the other thing anyone evaluating the language asks about first: a request
// arriving at a service written in Pudu, and an answer going back.
//
// Three routes rather than one, because the cost divides between three things
// and a single figure says nothing about which to improve:
//
//   /plain      a fixed string — the floor: socket, request parse, router, reply
//   /json       a small document built and encoded — what an API endpoint does
//   /page/:name a template rendered — what a server rendering HTML does
//
// Requests are issued one after another on separate connections, which is the
// least flattering shape and the easiest to reason about: no pipelining hides a
// slow parse, and no concurrency hides a slow handler behind another's wait.
//
// Reported as the median rather than the mean, because a single pause while
// something else on the machine runs moves a mean and not a median. The
// slowest tenth is reported beside it, since a tail is what a person actually
// notices.
//
// Latency and throughput are measured separately, because one does not follow
// from the other and quoting either alone misleads. Requests issued one at a
// time say what one request costs; requests issued several at once say what
// the server gets through, and the server hands each connection to one of a
// pool of workers, so the second is not the first multiplied by anything a
// reader could guess.
//
// Usage: node bench/request.mjs <path-to-pudu> [--requests 300] [--at-once 16] [--json]

import { spawn } from "node:child_process";
import { connect } from "node:net";
import process from "node:process";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node bench/request.mjs <path-to-pudu> [--requests n] [--json]");
  process.exit(2);
}

const argumentFor = (name, fallback) => {
  const at = process.argv.indexOf(name);
  return at < 0 ? fallback : Number(process.argv[at + 1]);
};

const asJson = process.argv.includes("--json");
// HTTP/1.1 keeps a connection open by default, and a client that closes after
// every request pays a handshake and a teardown for each one. Both are worth
// measuring: the first is what a load generator does, the second is what a
// browser and every service client actually do.
const keepAlive = process.argv.includes("--keep-alive");
const perRoute = argumentFor("--requests", 300);
const atOnce = argumentFor("--at-once", 16);
const routes = ["/plain", "/json", "/page/pudu"];
// Enough for the sequential pass, the warm-up before it, and the concurrent
// pass after it.
const budget = perRoute * routes.length * (keepAlive ? 4 : 3) + 128;

const service = spawn(executable, ["run", "bench/service/Service.pudu", String(budget)], {
  stdio: ["ignore", "pipe", "pipe"]
});

let said = "";
const port = await new Promise((resolve, reject) => {
  const give = setTimeout(() => reject(new Error("the service never announced a port")), 60000);
  service.stdout.on("data", chunk => {
    said += chunk;
    const found = /port (\d+)/.exec(said);
    if (found) {
      clearTimeout(give);
      resolve(Number(found[1]));
    }
  });
  service.stderr.on("data", chunk => (said += chunk));
  service.on("close", () => {
    clearTimeout(give);
    reject(new Error(`the service stopped before serving: ${said.trim()}`));
  });
});

/// One request on its own connection, answered in full.
const ask = (path) =>
  new Promise((resolve, reject) => {
    const started = process.hrtime.bigint();
    const socket = connect(port, "127.0.0.1", () => {
      socket.write(`GET ${path} HTTP/1.1\r\nHost: bench\r\nConnection: close\r\n\r\n`);
    });
    let answer = "";
    socket.setTimeout(30000, () => {
      socket.destroy();
      reject(new Error(`no answer for ${path}`));
    });
    socket.on("data", chunk => (answer += chunk));
    socket.on("error", reject);
    socket.on("close", () => {
      const took = Number(process.hrtime.bigint() - started) / 1e6;
      resolve({ took, answer });
    });
  });

/// A run of requests down one connection, the way HTTP/1.1 is meant to be used.
///
/// Answers how long the whole run took, because what a kept connection changes
/// is the cost of getting to the request rather than the cost of the request.
const askRepeatedly = (path, count) =>
  new Promise((resolve, reject) => {
    const started = process.hrtime.bigint();
    let answered = 0;
    let held = "";
    const socket = connect(port, "127.0.0.1", () => socket.write(request(path)));
    const request = (target) =>
      `GET ${target} HTTP/1.1\r\nHost: bench\r\nConnection: keep-alive\r\n\r\n`;
    socket.setTimeout(60000, () => {
      socket.destroy();
      reject(new Error(`no answer for ${path} after ${answered}`));
    });
    socket.on("data", chunk => {
      held += chunk;
      // Each answer states its own length, so the end of one is countable
      // without waiting for the connection to close to mark it.
      let boundary = held.indexOf("\r\n\r\n");
      while (boundary >= 0) {
        const length = Number(/content-length: *(\d+)/i.exec(held.slice(0, boundary))?.[1] ?? 0);
        const whole = boundary + 4 + length;
        if (held.length < whole) break;
        held = held.slice(whole);
        answered += 1;
        if (answered >= count) {
          socket.end();
          resolve(Number(process.hrtime.bigint() - started) / 1e9);
          return;
        }
        socket.write(request(path));
        boundary = held.indexOf("\r\n\r\n");
      }
    });
    socket.on("error", reject);
  });

const at = (sorted, proportion) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * proportion))];

const measured = {};
const failures = [];

for (const path of routes) {
  // A warm-up run that is measured and discarded: the first requests pay for
  // whatever the runtime does once, and reporting that as the cost of a
  // request would be reporting the wrong thing.
  for (let index = 0; index < Math.min(20, perRoute); index += 1) {
    await ask(path);
  }

  const taken = [];
  let firstAnswer = "";
  for (let index = 0; index < perRoute; index += 1) {
    const { took, answer } = await ask(path);
    if (index === 0) firstAnswer = answer;
    taken.push(took);
  }

  if (!firstAnswer.includes("200")) {
    failures.push(`${path} did not answer 200: ${firstAnswer.slice(0, 120)}`);
    continue;
  }

  taken.sort((left, right) => left - right);
  measured[path] = {
    medianMs: Number(at(taken, 0.5).toFixed(3)),
    slowestTenthMs: Number(at(taken, 0.9).toFixed(3)),
    perSecond: Math.round(1000 / at(taken, 0.5)),
    bytes: firstAnswer.length
  };
}

// What the server gets through when more than one client is waiting. The
// same requests, issued `atOnce` at a time rather than one after another.
const throughput = {};
for (const path of routes) {
  const started = process.hrtime.bigint();
  let issued = 0;
  while (issued < perRoute) {
    const batch = Math.min(atOnce, perRoute - issued);
    await Promise.all(Array.from({ length: batch }, () => ask(path)));
    issued += batch;
  }
  const seconds = Number(process.hrtime.bigint() - started) / 1e9;
  throughput[path] = Math.round(perRoute / seconds);
}

// The same requests down one kept connection, which is what HTTP/1.1 does by
// default and what every service client does.
const kept = {};
if (keepAlive) {
  for (const path of routes) {
    const seconds = await askRepeatedly(path, perRoute);
    kept[path] = Math.round(perRoute / seconds);
  }
}

service.kill();

if (failures.length > 0) {
  console.error("request: the service did not answer as a service.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

if (asJson) {
  console.log(JSON.stringify({ requests: perRoute, atOnce, routes: measured, throughput, kept }, null, 2));
} else {
  console.log(`${perRoute} requests a route, each on its own connection\n`);
  console.log(
    "route          median    slowest 10%   alone/s   " +
      String(atOnce) +
      " at once/s" +
      (keepAlive ? "   kept open/s" : "")
  );
  for (const [path, held] of Object.entries(measured)) {
    console.log(
      path.padEnd(14) +
        `${held.medianMs}ms`.padEnd(10) +
        `${held.slowestTenthMs}ms`.padEnd(14) +
        String(held.perSecond).padEnd(10) +
        String(throughput[path]).padEnd(13) +
        (keepAlive ? String(kept[path]) : "")
    );
  }
}
