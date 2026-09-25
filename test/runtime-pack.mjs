// Building for another host from a published runtime pack, against a
// stand-in release server.
//
// A real pack is a musl runtime, which this machine may not be able to run.
// What is checked here is everything around it: the manifest and each file
// fetched (through a redirect, as a release asset is), every file verified,
// the pack kept so the next build asks the network nothing, both targets
// written, and each way a pack can be wrong refused with a sentence. The
// "runtime" served is this compiler itself, which carries the same source
// digest as any runtime built from its sources.
//
// Usage: node test/runtime-pack.mjs <path-to-pudu>

import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import process from "node:process";
import { gzipSync } from "node:zlib";

const executable = process.argv[2];
if (!executable) {
  console.error("usage: node test/runtime-pack.mjs <pudu-executable>");
  process.exit(2);
}

const directory = mkdtempSync(join(tmpdir(), "pudu-runtime-pack-"));
const failures = [];
const compiler = readFileSync(executable);
const libraries = ["ld-musl-x86_64.so.1", "libffi.so.8", "libz.so.1", "libncursesw.so.6", "libgmp.so.10"];

// A copy of the compiler with one digit of its source digest changed, which is
// what a runtime built from other sources is to the check.
const otherSources = (() => {
  const bytes = Buffer.from(compiler);
  const needle = Buffer.from("PUDU-SOURCE-DIGEST:");
  let at = bytes.indexOf(needle);
  while (at >= 0 && !/^[0-9a-f]{64};$/.test(bytes.subarray(at + needle.length, at + needle.length + 65).toString("latin1"))) {
    at = bytes.indexOf(needle, at + 1);
  }
  const digit = at + needle.length;
  bytes[digit] = bytes[digit] === 0x30 ? 0x31 : 0x30;
  return bytes;
})();

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

// A pack as a release publishes it: each file gzipped, and a manifest of the
// uncompressed files' digests.
const packOf = ({ runtime = compiler, tamper = null, omit = null, notGzip = null } = {}) => {
  const files = new Map([
    ["pudu-musl-x86_64", runtime],
    ["pudu-musl-lambda-x86_64", runtime],
    ...libraries.map((name) => [name, Buffer.from(`library ${name}`)]),
  ]);
  const assets = new Map();
  const lines = [];
  for (const [name, bytes] of files) {
    if (name !== omit) lines.push(`${sha256(bytes)}  ${name}`);
    const served = name === tamper ? Buffer.concat([bytes, Buffer.from("!")]) : bytes;
    assets.set(`/${name}.gz`, name === notGzip ? served : gzipSync(served));
  }
  assets.set("/pudu-runtime-linux-musl-x86_64.sha256", Buffer.from(lines.join("\n") + "\n"));
  return assets;
};

// Serves a pack under /release, redirecting every asset to /assets the way a
// release host sends a download to its storage.
const serve = (assets) =>
  new Promise((resolve) => {
    let requests = 0;
    const server = createServer((request, response) => {
      requests += 1;
      if (request.url.startsWith("/release/")) {
        response.writeHead(302, { location: request.url.replace("/release/", "/assets/") });
        response.end();
        return;
      }
      const body = assets.get(request.url.replace("/assets", ""));
      if (!body) {
        response.writeHead(404);
        response.end();
        return;
      }
      response.writeHead(200, { "content-length": body.length });
      response.end(body);
    });
    server.listen(0, "127.0.0.1", () =>
      resolve({ url: `http://127.0.0.1:${server.address().port}/release`, count: () => requests, close: () => server.close() })
    );
  });

const program = join(directory, "Hello.pudu");
writeFileSync(program, 'module Hello\n\nimport Std.Io as Io\n\nfn main() -> Int {\n  let _said = Io.writeLine("hello from the pack")\n  0\n}\n');

// Asynchronous, because the stand-in server answers from this same process:
// a synchronous child would hold the event loop the server needs.
const build = (url, cache, target, output) =>
  new Promise((resolve) => {
    const child = spawn(executable, ["build", program, "--target", target, "-o", output], {
      env: { ...process.env, PUDU_RUNTIME_URL: url, PUDU_RUNTIME_CACHE: cache },
    });
    let stderr = "";
    child.stderr.on("data", (chunk) => (stderr += chunk));
    child.stdout.resume();
    child.on("close", (status) => resolve({ status, stderr }));
  });

const ranSays = (path) => spawnSync(path, [], { encoding: "utf8", env: {} }).stdout.trim();

const refusedWith = async (label, assets, expected) => {
  const server = await serve(assets);
  const result = await build(server.url, join(directory, `cache-${label}`), "linux-musl-x86_64", join(directory, `out-${label}`));
  server.close();
  if (result.status === 0) {
    failures.push(`${label}: the build succeeded`);
  } else if (!result.stderr.includes(expected)) {
    failures.push(`${label}: said ${JSON.stringify(result.stderr.trim())}`);
  }
  if (existsSync(join(directory, `out-${label}`))) failures.push(`${label}: wrote an output anyway`);
};

try {
  // Fetched, verified, and attached.
  const cache = join(directory, "cache");
  const server = await serve(packOf());
  const portable = join(directory, "portable");
  const first = await build(server.url, cache, "linux-musl-x86_64", portable);
  if (first.status !== 0) failures.push(`the portable build failed: ${first.stderr}`);
  else if (ranSays(portable) !== "hello from the pack") failures.push("the portable build did not run");
  if (first.stderr.includes("other sources")) failures.push("a same-source pack was treated as foreign");
  const fetchedOnce = server.count();

  // A function directory: bootstrap and its loader and libraries beside it.
  const lambda = join(directory, "function");
  const second = await build(server.url, cache, "lambda-x86_64", lambda);
  if (second.status !== 0) failures.push(`the function build failed: ${second.stderr}`);
  if (server.count() !== fetchedOnce) failures.push("a kept pack was fetched again");
  if (!existsSync(join(lambda, "bootstrap")) || ranSays(join(lambda, "bootstrap")) !== "hello from the pack") {
    failures.push("the function directory has no runnable bootstrap");
  }
  for (const name of libraries) {
    const path = join(lambda, name);
    if (!existsSync(path) || readFileSync(path, "utf8") !== `library ${name}`) failures.push(`the function directory lacks ${name}`);
  }
  server.close();

  // Kept: a third build needs no server at all.
  const offline = await build("http://127.0.0.1:9/release", cache, "linux-musl-x86_64", join(directory, "offline"));
  if (offline.status !== 0) failures.push(`a build from the kept pack failed: ${offline.stderr}`);

  // Every way a pack can be wrong.
  await refusedWith("tampered", packOf({ tamper: "libz.so.1" }), "does not have the SHA-256 the pack's manifest names");
  await refusedWith("unlisted", packOf({ omit: "libgmp.so.10" }), "names no libgmp.so.10");
  await refusedWith("foreign", packOf({ runtime: otherSources }), "built from other sources than this compiler");
  await refusedWith("plain", packOf({ notGzip: "libffi.so.8" }), "libffi.so.8 is not a gzip file");
  await refusedWith("unpublished", new Map(), "no runtime pack is published");
  const unreachable = await build("http://127.0.0.1:9/release", join(directory, "cache-unreachable"), "linux-musl-x86_64", join(directory, "out-unreachable"));
  if (unreachable.status === 0 || !unreachable.stderr.includes("could not be fetched")) {
    failures.push(`an unreachable server said ${JSON.stringify(unreachable.stderr.trim())}`);
  }
  const plainRemote = await build("http://example.com/release", join(directory, "cache-remote"), "linux-musl-x86_64", join(directory, "out-remote"));
  if (plainRemote.status === 0 || !plainRemote.stderr.includes("plain HTTP")) {
    failures.push(`plain HTTP to another machine said ${JSON.stringify(plainRemote.stderr.trim())}`);
  }

  // The arguments are checked before anything is fetched.
  const unknown = spawnSync(executable, ["build", program, "--target", "windows"], { encoding: "utf8" });
  if (unknown.status === 0 || !unknown.stderr.includes("linux-musl-x86_64, lambda-x86_64")) failures.push("an unknown target was not refused with the list");
  const both = spawnSync(executable, ["build", program, "--target", "lambda-x86_64", "--runtime", executable], { encoding: "utf8" });
  if (both.status === 0 || !both.stderr.includes("give one")) failures.push("--runtime with --target was not refused");
} finally {
  rmSync(directory, { recursive: true, force: true });
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(JSON.stringify({ fetched: true, verified: true, kept: true, refusals: 8 }));
