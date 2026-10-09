import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const executable = resolve(process.argv[2]);
const library = resolve("packages/pudu/v0.1/lib");
const root = mkdtempSync(join(tmpdir(), "pudu-derive-index-"));
const source = `module Probe
import Std.Show

export trait Named { fn named(self: &Self) -> Str }
/// Record "guide".
export derive Named for T: Record {
  /// Member guide.
  fn named(self: &T) -> Str { "record" }
}
/// Sum guide.
export derive Named for T: Sum { fn named(self: &T) -> Str { "sum" } }
trait Hidden { fn hidden(self: &Self) -> Str }
derive Hidden for T: Record { fn hidden(self: &T) -> Str { "hidden" } }
export trait Typed[A] { fn tag(self: &Self) -> Str }
export derive Typed[Int] for U: Record { fn tag(self: &U) -> Str { "typed" } }
export fn ordinary(value: Int) -> Int { value }
`;
const call = (command, path) => {
  const result = spawnSync(executable, [command, "--json", path], {
    encoding: "utf8", env: { ...process.env, PUDU_LIB: library }, timeout: 120000,
  });
  assert.ifError(result.error);
  assert.equal(result.signal, null, result.stderr);
  return result;
};
const successful = (command, path) => {
  const result = call(command, path);
  assert.equal(result.status, 0, result.stderr);
  return JSON.parse(result.stdout);
};
const strategies = (entries, module) => entries.filter(entry => entry.kind === "derive" && entry.module === module);
try {
  const path = join(root, "Probe.pudu");
  writeFileSync(path, source);
  const docs = successful("doc", path).entries;
  const headers = strategies(docs, "Probe");
  assert.deepEqual(headers.map(entry => entry.signature), [
    "derive Named for T: Record", "derive Named for T: Sum",
    "derive Hidden for T: Record", "derive Typed[Int] for U: Record",
  ]);
  assert.deepEqual(headers.map(entry => entry.doc), [['Record "guide".'], ["Sum guide."], [], []]);
  assert.deepEqual(headers.map(entry => entry.derive), [
    {trait: "Named", parameter: "T", shape: "Record", exported: true},
    {trait: "Named", parameter: "T", shape: "Sum", exported: true},
    {trait: "Hidden", parameter: "T", shape: "Record", exported: false},
    {trait: "Typed[Int]", parameter: "U", shape: "Record", exported: true},
  ]);
  for (const entry of headers) {
    assert.equal(entry.shape, null);
    assert.match(source.slice(...entry.span), /^(?:export )?derive /);
    assert.ok(entry.span[1] > entry.span[0]);
  }
  assert.equal(new Set(headers.map(entry => entry.span[0])).size, 4);
  assert.ok(docs.some(entry => entry.doc.includes("Member guide.")));
  assert.ok(strategies(docs, "Std.Show").length > 0);
  const api = successful("api", path).exports;
  assert.deepEqual(api.filter(entry => entry.kind === "derive"), headers.filter(entry => entry.derive.exported));
  assert.deepEqual(api.filter(entry => entry.kind !== "derive"), [
    {module: "Probe", name: "Named"}, {module: "Probe", name: "Typed"}, {module: "Probe", name: "ordinary"},
  ]);
  assert.ok(api.every(entry => entry.module === "Probe"));
  writeFileSync(path, source + '\nexport fn broken() -> Int { "bad" }\n');
  const invalidApi = call("api", path);
  assert.notEqual(invalidApi.status, 0);
  assert.equal(invalidApi.stdout, "");
  assert.match(invalidApi.stderr, /compilation failed/);
  const invalidDocs = call("doc", path);
  assert.notEqual(invalidDocs.status, 0);
  assert.match(invalidDocs.stderr, /: 1 error\n/);
  assert.deepEqual(strategies(JSON.parse(invalidDocs.stdout).entries, "Probe"), headers);
  for (const [module, expected] of [
    ["Std.Show", ["Show:Record", "Show:Sum"]],
    ["Std.Order", ["Eq:Record", "Eq:Sum", "Ord:Record", "Ord:Sum", "Hash:Record", "Hash:Sum"]],
    ["Std.Json", ["Encode:Record", "Encode:Sum", "Decode:Record", "Decode:Sum"]],
    ["Std.Db.Row", ["Row:Record"]],
  ]) {
    const file = join(library, ...module.split(".")) + ".pudu";
    const entries = strategies(successful("doc", file).entries, module);
    assert.deepEqual(entries.map(entry => `${entry.name}:${entry.derive.shape}`).sort(), expected.sort());
    assert.deepEqual(strategies(successful("api", file).exports, module), entries);
  }
  console.log("Pudu derive documentation and public API boundaries pass.");
} finally {
  rmSync(root, {recursive: true, force: true});
}
