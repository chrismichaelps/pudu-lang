// A session survives what an editor really sends it.
//
// The server used to stop on anything it could not decode, and stop with a
// success status, so an editor saw a clean shutdown instead of a fault. The
// rows below are the traffic that did it. Two of them should still end the
// session, and they are checked for that rather than for surviving.
//
// Usage: node test/lsp-robustness.mjs <path-to-pudu>

import { spawn } from "node:child_process";
import process from "node:process";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node test/lsp-robustness.mjs <path-to-pudu>");
  process.exit(2);
}

const frame = value => {
  const body = Buffer.from(JSON.stringify(value), "utf8");
  return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`), body]);
};
const rawFrame = text => Buffer.from(text, "utf8");

// Each case sends initialize, then one middle frame, then shutdown and exit.
// A session that survived answers both requests.
const cases = [
  { name: "a baseline session with nothing unusual", middle: null, survives: true },
  {
    name: "a client's reply to a server request",
    middle: frame({ jsonrpc: "2.0", id: 99, result: null }),
    survives: true,
  },
  {
    name: "a client's error reply",
    middle: frame({ jsonrpc: "2.0", id: 98, error: { code: -32601, message: "no" } }),
    survives: true,
  },
  {
    name: "a frame carrying an empty object",
    middle: frame({}),
    survives: true,
  },
  {
    name: "a frame whose body is not JSON",
    middle: Buffer.concat([rawFrame("Content-Length: 7\r\n\r\n"), rawFrame("{not js")]),
    survives: true,
  },
  {
    name: "a notification the server does not implement",
    middle: frame({ jsonrpc: "2.0", method: "$/setTrace", params: null }),
    survives: true,
  },
  {
    name: "a request for a method the server does not implement",
    middle: frame({ jsonrpc: "2.0", id: 5, method: "textDocument/nonsense", params: {} }),
    survives: true,
  },
  // Framing faults leave the reader mid-stream with nothing to resynchronise
  // on, so these end the session — and must say so in the exit status.
  {
    name: "a frame with no Content-Length",
    middle: rawFrame("X-Header: 1\r\n\r\n{}"),
    survives: false,
  },
  {
    name: "a frame that stops short of its Content-Length",
    middle: Buffer.concat([rawFrame("Content-Length: 5000\r\n\r\n"), rawFrame('{"jsonrpc":"2.0"}')]),
    survives: false,
  },
];

const run = middle =>
  new Promise(resolve => {
    const server = spawn(executable, ["lsp"], { stdio: ["pipe", "pipe", "pipe"] });
    let out = "";
    let errors = "";
    server.stdout.on("data", chunk => (out += chunk.toString()));
    server.stderr.on("data", chunk => (errors += chunk.toString()));
    server.on("close", code => {
      const answered = [...out.matchAll(/"id":(\d+)/g)].map(match => Number(match[1]));
      resolve({ answered, code, errors });
    });
    server.stdin.write(frame({ jsonrpc: "2.0", id: 1, method: "initialize", params: {} }));
    if (middle) server.stdin.write(middle);
    server.stdin.write(frame({ jsonrpc: "2.0", id: 2, method: "shutdown", params: {} }));
    server.stdin.write(frame({ jsonrpc: "2.0", method: "exit", params: {} }));
    server.stdin.end();
    setTimeout(() => {
      try {
        server.kill();
      } catch {}
    }, 20000);
  });

const failures = [];
let survived = 0;
let ended = 0;

for (const testCase of cases) {
  const { answered, code } = await run(testCase.middle);
  const answeredBoth = answered.includes(1) && answered.includes(2);
  if (testCase.survives) {
    if (!answeredBoth) {
      failures.push(`${testCase.name}: the session stopped answering (exit ${code})`);
    } else if (code !== 0) {
      failures.push(`${testCase.name}: survived but exited ${code}`);
    } else {
      survived += 1;
    }
  } else {
    if (answeredBoth) {
      failures.push(`${testCase.name}: the session carried on through a framing fault`);
    } else if (code === 0) {
      // Exiting zero here is the part that misled an editor into reporting a
      // clean shutdown for a session that had actually broken.
      failures.push(`${testCase.name}: ended the session but reported success`);
    } else {
      ended += 1;
    }
  }
}

if (failures.length > 0) {
  console.error("lsp robustness:\n  " + failures.join("\n  "));
  process.exit(1);
}

console.log(JSON.stringify({ cases: cases.length, survived, endedWithFailure: ended }));
