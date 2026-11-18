import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { swiftExpected, swiftProgram, swiftSource } from "./swift-counter.mjs";

// Swift reaches Pudu through C entry points: the interpreter and the native
// build call one Swift library and must answer, and refuse, identically.

const repository = resolve(dirname(fileURLToPath(import.meta.url)), "..");
process.env.PUDU_LIB ??= join(repository, "packages", "pudu", "v0.1", "lib");

const [, , compiler] = process.argv;
if (!compiler) throw new Error("Usage: node test/swift-entry-points.mjs <pudu>");

function execute(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", timeout: 300_000 });
  if (result.error) throw result.error;
  return { status: result.status, stdout: result.stdout.trim(), stderr: result.stderr.trim() };
}

if (process.platform !== "darwin" || execute("xcrun", ["--find", "swiftc"]).status !== 0) {
  console.log("SKIP Swift entry points: macOS with swiftc required");
  process.exit(0);
}

const root = mkdtempSync(join(tmpdir(), "pudu-swift-"));
try {
  const library = join(root, "libPuduSwiftCounter.dylib");
  writeFileSync(join(root, "Counter.swift"), swiftSource);
  const built = execute("xcrun", ["swiftc", "-emit-library", "-module-name", "PuduSwiftCounter",
    join(root, "Counter.swift"), "-o", library]);
  assert.equal(built.status, 0, built.stderr);

  const both = (name, releases) => {
    const directory = join(root, name);
    mkdirSync(directory);
    const source = join(directory, "Main.pudu");
    writeFileSync(source, swiftProgram(library, "", releases));
    const interpreted = execute(resolve(compiler), ["run", source]);
    const binary = join(directory, "main");
    const compiled = execute(resolve(compiler), ["build", source, "--native", "-o", binary]);
    assert.equal(compiled.status, 0, compiled.stderr);
    return { interpreted, native: execute(binary, []) };
  };

  const success = both("success", 1);
  assert.deepEqual(success.interpreted, { status: 0, stdout: swiftExpected, stderr: "" });
  assert.deepEqual(success.native, success.interpreted);
  console.log("PASS Swift owned object, callback and text match natively");

  const twice = both("twice", 2);
  assert.equal(twice.interpreted.status, 1);
  assert.match(twice.interpreted.stderr, /E7022.*swift_counter_release is no longer owned/u);
  assert.deepEqual(twice.native, twice.interpreted);
  console.log("PASS Swift object released twice is refused identically");
} finally {
  rmSync(root, { recursive: true, force: true });
}
