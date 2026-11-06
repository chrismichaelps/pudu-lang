---
type: module
path: "@root/lib/Std/Desktop/Delta.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, desktop, updates, performance]
aliases: [Std Desktop Delta]
---

# Std Desktop Delta

## Purpose and interface

Differential updates. `diff(old, new)` writes a patch that rebuilds `new` from `old`; `apply(old,
patch)` rebuilds it and verifies the result. Patches are computed over uncompressed archives, where
unchanged files are byte-identical runs.

## Semantics

- Format: a text header — `PUDU-DELTA 1`, `base <sha256 of old>`, `size <length of new>`,
  `target <sha256 of new>` — then operations, each a line: `c <offset> <length>` copies from the old
  bytes, `l <length>` is followed by that many literal bytes.
- `apply` refuses a patch for another base (`BaseMismatch`), an operation outside the old bytes or the
  patch (`Corrupt`), and a result whose length or SHA-256 differs from the header (`TargetMismatch`).
  A caller falls back to the full download on any refusal.
- Matching indexes every 512-byte-aligned 4 KiB window of the old bytes by SHA-256, scans the new
  bytes in 512-byte steps, confirms a candidate by comparing bytes, and extends each match 512 bytes at
  a time. Archive members are 512-byte aligned, so a file that moved still matches.

## Grill Log

- **Q:** Why not a rolling checksum at every byte offset? **A:** It finds matches at any alignment,
  but costs work per byte of the new artifact in the interpreter. Archive alignment makes a 512-byte
  step find the same matches with a native hash per step, a few thousand hashes for a typical
  application.
- **Q:** Why a text header? **A:** It is a few dozen bytes, readable when a patch is debugged, and the
  binary payload follows each literal line by length, so nothing is escaped.

## Dependencies and consumers

Uses the prelude `sha256Of` and [[Std Hex]]. Consumed by [[Std Desktop Update]] and
[[Std Desktop Cli]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
