---
type: module
path: "@root/test/cc-cache/cc"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, test, cache, toolchain]
aliases: [Test Compile Cache]
---

# Test Compile Cache

Content-addressed compiler cache for the test suite.

## Purpose and interface

Placed first on `PATH` as `cc`, `clang` and `gcc` (the latter two link to the same script), it runs the
real compiler of the same name once per distinct compile and serves every repeat from the store.

## Contract

- The key covers the real compiler and its modification time, the arguments, and the contents of
  every input file. Each `-I` directory contributes its headers, and each source file contributes the
  headers beside it. Temporary paths do not enter the key.
- A repeat links the stored output to the requested path and replays the compiler's exit status,
  stdout and stderr exactly.
- The store is `PUDU_CC_CACHE`, or `~/.cache/pudu-test-cc` when unset.

## Grill Log

- **Q:** Why cache the binary rather than only the object code? **A:** A linked binary is one the
  system has already scanned, so a repeat skips both the compile and the first-launch scan macOS gives
  a new executable. _Rejected:_ caching intermediate objects only.
- **Q:** Does clearing the store break anything? **A:** No. Removing the store only costs the next run
  its warm start.

Resolved Grill Log: the key is the compiler identity plus every input, and replay is exact, so a
cache hit is indistinguishable from a fresh compile to the tests.

## Referenced by

[[Test Parallel Runner]] · [[Repository Test Runner]] · [[architecture/DELIVERY]]
