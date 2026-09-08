// The foreign boundary reaches libraries nobody here wrote.
//
// Every other foreign fixture calls a shim built from this repository's own
// `cbits`, which proves the bridge and proves nothing about the shapes real
// libraries actually use. A shim can be given whatever signature the boundary
// happens to admit; SQLite cannot.
//
// So this runs against two libraries that are simply on the machine, in the
// shapes their headers declare:
//
//   - SQLite hands its handle back through a slot the caller provides
//     (`int sqlite3_open(const char*, sqlite3**)`), and releases with a
//     function that answers `int`. Both are the ordinary C way, and either one
//     being refused means the library cannot be bound at all.
//   - zlib takes a run of bytes it only reads, with the length beside it —
//     the commonest foreign shape there is — and its answer for a known input
//     is published, so a run that crossed short or misaligned is caught rather
//     than looking plausible.
//
// A machine without one of these libraries skips that half rather than
// failing: what is under test is the boundary, not the machine's packages.
//
// Usage: node test/foreign-third-party.mjs [path-to-pudu]

import { execFileSync } from "node:child_process";
import process from "node:process";

const executable = process.argv[2] ?? "pudu";

const run = source => {
  try {
    return { ok: true, out: execFileSync(executable, ["run", source], { stdio: "pipe" }).toString() };
  } catch (failure) {
    const said = (failure.stdout?.toString() ?? "") + (failure.stderr?.toString() ?? "");
    return { ok: false, out: said };
  }
};

// A library that is not installed says so in a way worth telling apart from a
// boundary that could not carry a shape.
const unavailable = said => /no candidate name opened|cannot open|image not found|E7014/i.test(said);

const failures = [];
const skipped = [];
const proved = [];

const sqlite = run("test-fixtures/thirdparty/Sqlite.pudu");
if (!sqlite.ok && unavailable(sqlite.out)) {
  skipped.push("sqlite3 is not on this machine");
} else if (!sqlite.ok) {
  failures.push(`sqlite3: ${sqlite.out.trim()}`);
} else {
  const said = sqlite.out.trim();
  // 41 + 1, and the later of two texts: values SQLite computed, not this file.
  if (said !== "sum=42 max=b") {
    failures.push(`sqlite3 answered ${JSON.stringify(said)}`);
  } else {
    proved.push("sqlite3: opened through an out-slot, queried, released");
  }
}

const zlib = run("test-fixtures/thirdparty/Zlib.pudu");
if (!zlib.ok && unavailable(zlib.out)) {
  skipped.push("zlib is not on this machine");
} else if (!zlib.ok) {
  failures.push(`zlib: ${zlib.out.trim()}`);
} else {
  const said = Object.fromEntries(
    zlib.out.trim().split("\n").map(line => line.split("="))
  );
  // The published CRC-32 of "hello" is 0x3610A686.
  if (said.hello !== "907060870") {
    failures.push(`zlib crc32 of "hello" was ${said.hello}, not the published 907060870`);
  }
  if (said.empty !== "0") {
    failures.push(`zlib crc32 of an empty run was ${said.empty}, not 0`);
  }
  if (said.embedded === said.hello || said.embedded === "0") {
    failures.push(`a nought inside the run was not counted: ${said.embedded}`);
  }
  if (said.unchanged !== "true") {
    failures.push("the run of bytes did not survive being lent");
  }
  if (failures.length === 0) {
    proved.push("zlib: a run of bytes crossed, read whole, and was unchanged");
  }
}

if (failures.length > 0) {
  console.error("foreign-third-party: the boundary must reach libraries nobody here wrote.\n");
  for (const failure of failures) console.error("  " + failure + "\n");
  process.exit(1);
}

console.log(JSON.stringify({ proved, skipped }));
