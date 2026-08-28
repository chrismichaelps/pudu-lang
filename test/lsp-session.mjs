// Drive a real language-server session and check what an editor would rely on.
//
// The CI check this replaces asserted only that `initialize` answered with
// `hoverProvider: true`. That is true of a server that then returns nothing
// useful, publishes no diagnostics, and frames its replies wrongly — none of
// which an editor would tolerate and none of which the old check could see.
//
// Usage: node test/lsp-session.mjs <path-to-pudu-executable>

import { spawn } from "node:child_process";
import process from "node:process";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node test/lsp-session.mjs <path-to-pudu>");
  process.exit(2);
}

const source = [
  "module Session",
  "fn double(n: Int) -> Int { n * 2 }",
  "trait Sized { fn area(self: &Self) -> Int }",
  "type Box = { side: Int }",
  "impl Sized for Box { fn area(self: &Box) -> Int { self.side * self.side } }",
  "export fn main() -> Str {",
  '  let text = "hi"',
  "  let size = text.length()",
  "  let box = Box{side: 2}",
  "  let room = box.area()",
  "  double(21)",
  "}",
  "",
].join("\n");

const uri = "file:///tmp/session.pudu";

const messages = [
  { id: 1, method: "initialize", params: { processId: null, rootUri: null, capabilities: {} } },
  { method: "initialized", params: {} },
  {
    method: "textDocument/didOpen",
    params: { textDocument: { uri, languageId: "pudu", version: 1, text: source } },
  },
  {
    id: 2,
    method: "textDocument/hover",
    params: { textDocument: { uri }, position: { line: 1, character: 4 } },
  },
  {
    id: 3,
    method: "textDocument/definition",
    params: { textDocument: { uri }, position: { line: 10, character: 4 } },
  },
  { id: 4, method: "textDocument/documentSymbol", params: { textDocument: { uri } } },
  // Hover over the binding `text`, which is a name a reader points at as often
  // as a use of one. Asking the documentation index alone could only ever name
  // the function containing it, which is true everywhere in the body.
  {
    id: 6,
    method: "textDocument/hover",
    params: { textDocument: { uri }, position: { line: 6, character: 7 } },
  },
  // Completion straight after `text.` offers what text carries, not what the
  // module declares.
  {
    id: 7,
    method: "textDocument/completion",
    params: { textDocument: { uri }, position: { line: 7, character: 18 } },
  },
  // After `box.`, where `Box` is a type this program declared and implemented.
  {
    id: 8,
    method: "textDocument/completion",
    params: { textDocument: { uri }, position: { line: 9, character: 17 } },
  },
  { id: 5, method: "shutdown", params: null },
  { method: "exit", params: null },
];

const encode = message => {
  const body = Buffer.from(JSON.stringify({ jsonrpc: "2.0", ...message }), "utf8");
  return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "ascii"), body]);
};

const server = spawn(executable, ["lsp"], { stdio: ["pipe", "pipe", "inherit"] });
const chunks = [];
server.stdout.on("data", chunk => chunks.push(chunk));

let closed = null;
server.on("close", code => {
  closed = code;
});

server.stdin.write(Buffer.concat(messages.map(encode)));

// Stdin stays open, as a real client's does. Ending it would let a server that
// ignores `exit` still stop — on end of input — and the check could not tell
// the two apart. An editor holds the pipe open and waits, and reports that
// stopping the server timed out when nothing happens.
const stoppedWithin = async milliseconds => {
  const deadline = Date.now() + milliseconds;
  while (closed === null && Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, 25));
  }
  return closed !== null;
};

const stopped = await stoppedWithin(5000);
if (!stopped) {
  server.kill("SIGKILL");
}
const code = closed;
const output = Buffer.concat(chunks);

const assert = (condition, message) => {
  if (!condition) {
    console.error(`lsp-session: ${message}`);
    process.exit(1);
  }
};

assert(stopped, "the server did not stop when told to; stdin was still open, as an editor keeps it");
assert(code === 0, `server exited with ${code}`);

// Framing is checked on raw bytes. A harness reading the stream as text with
// universal newlines silently rewrites CRLF to LF and reports a protocol
// violation that is its own.
assert(output.includes(Buffer.from("\r\n\r\n", "ascii")), "replies are not framed with CRLF");

const frames = [];
let offset = 0;
while (true) {
  const header = output.indexOf("Content-Length:", offset);
  if (header < 0) break;
  const separator = output.indexOf("\r\n\r\n", header);
  assert(separator > 0, "a header block was never terminated");
  const length = Number(output.subarray(header + 15, separator).toString("ascii").trim());
  assert(Number.isInteger(length) && length > 0, "a Content-Length was not a positive integer");
  const body = output.subarray(separator + 4, separator + 4 + length);
  assert(body.length === length, "a message was shorter than its declared length");
  frames.push(JSON.parse(body.toString("utf8")));
  offset = separator + 4 + length;
}

const replyTo = id => frames.find(frame => frame.id === id);
const notifications = method => frames.filter(frame => frame.method === method);

const capabilities = replyTo(1)?.result?.capabilities;
assert(capabilities, "initialize returned no capabilities");
for (const provider of ["hoverProvider", "definitionProvider", "documentSymbolProvider"]) {
  assert(capabilities[provider], `${provider} was not advertised`);
}

// Diagnostics: the source declares `-> Str` and returns an `Int`, so a working
// server reports it on the line that is wrong.
const published = notifications("textDocument/publishDiagnostics");
assert(published.length > 0, "no diagnostics were published for an open document");
const diagnostics = published.at(-1).params.diagnostics;
assert(diagnostics.length > 0, "the type error in the document was not reported");
assert(
  diagnostics.some(entry => entry.range.start.line >= 2),
  "the diagnostic did not point at the line that is wrong",
);

// Hover: a signature, not just a name.
const hover = replyTo(2)?.result;
assert(hover, "hover returned nothing over a declared function");
const hoverText = JSON.stringify(hover);
assert(hoverText.includes("double"), "hover did not name the function");
assert(hoverText.includes("Int -> Int"), "hover did not carry the inferred signature");

// Definition: a call jumps to the declaration, not to itself.
const definition = replyTo(3)?.result;
assert(definition, "definition returned nothing for a call");
const target = Array.isArray(definition) ? definition[0] : definition;
assert(target.uri === uri, "definition pointed outside the document");
assert(target.range.start.line === 1, "definition did not point at the declaration");

// Symbols: every declaration, with its type.
const symbols = replyTo(4)?.result;
assert(Array.isArray(symbols) && symbols.length >= 2, "document symbols were missing declarations");
assert(
  symbols.some(entry => entry.name === "double" && String(entry.detail).includes("Int")),
  "a symbol was reported without its type",
);

// Hover names the thing under the cursor, not the declaration around it.
const binding = replyTo(6)?.result;
assert(binding, "hover returned nothing over a binding");
const bindingText = JSON.stringify(binding);
assert(bindingText.includes("text"), "hover did not name the binding");
assert(bindingText.includes("Str"), "hover did not give the binding's type");
assert(
  !bindingText.includes("main"),
  "hover answered with the enclosing declaration instead of the binding",
);

// Completion after a dot offers the receiver's methods.
const offered = replyTo(7)?.result;
const items = Array.isArray(offered) ? offered : (offered?.items ?? []);
const labels = items.map(entry => entry.label);
assert(labels.length > 0, "completion after a dot offered nothing");
for (const expected of ["length", "toUpper", "trim"]) {
  assert(labels.includes(expected), `completion after a dot did not offer ${expected}`);
}
assert(
  !labels.includes("double"),
  "completion after a dot offered a module name rather than what the value carries",
);

// A type a reader wrote carries what they gave it, not only the built-in sets.
const written = replyTo(8)?.result;
const writtenItems = Array.isArray(written) ? written : (written?.items ?? []);
const writtenLabels = writtenItems.map(entry => entry.label);
assert(
  writtenLabels.includes("area"),
  "completion did not offer a method the program implemented",
);

console.log(
  JSON.stringify({ frames: frames.length, diagnostics: diagnostics.length, methods: labels.length }),
);
