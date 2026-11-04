---
type: module
path: "@root/test/Pudu/Backend/ToolchainSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, toolchain]
aliases: [Backend Toolchain Tests]
---

# Backend Toolchain Tests

## Purpose and interface

`backendToolchainProperties :: [(String, IO Property)]` exercises hostile
compiler lifetimes through the real [[Backend Toolchain]] boundary. It uses
scripted compilers, so these regressions do not require a C compiler.

## Algorithm and invariants

- An executable shell script writes a staged output and then ignores TERM.
  With a one-second compiler deadline, the call must finish inside an
  eight-second independent watchdog and return exactly `ToolchainTimedOut 1`.
- Another script writes staged output, starts a child retaining the capture
  pipes, then exits successfully. The same deadline must still expire;
  compiler exit alone must never permit publication or an unbounded drain.
- Cancellation waits for the script's readiness marker, sends `ThreadKilled`
  to the compiler worker, and checks that the original async exception
  propagates inside an eight-second watchdog.
- Every scenario starts with an existing target and asserts its contents are
  preserved. No `.pudu-tmp` source or staged executable may remain afterward.
- Each test owns a temporary directory and restores the environment with a
  bracket. The suite runs these environment-mutating checks sequentially.
- Platforms without `/bin/sh` report an explicit skip, matching the host
  shell fixture policy of [[Backend Native Tests]].

## Dependencies and consumers

Uses [[Backend Toolchain]], `base`, `directory`, `filepath`, `temporary`,
`text`, and `QuickCheck`. Consumed by [[Repository Test Runner]].

## Negative logic

No real compiler dependency, no unconditional sleep before cancellation, no
successful timeout assertion without an outer watchdog, and no swallowed
cancellation. The watchdog exceeds the documented cleanup allowance while
remaining short enough to expose the original indefinite wait regression.

## Resolved Grill Log

- **Q:** Why does the compiler-exits test expect a timeout? **A:** Its child
  still owns stdout/stderr, so capture has not finished. Only process exit
  plus both drains satisfies the toolchain completion contract.
- **Q:** Can cancellation be sent before a process exists? **A:** The test
  waits for a marker written by the child after it starts and stages output.
  That makes cancellation cover live process ownership and temporary cleanup.
- **Q:** Why check an existing target? **A:** A timeout must preserve the
  previous executable even if the failed compiler wrote a staged artifact.

## Referenced by

[[Repository Test Runner]] · [[src/Pudu/Backend/_MOC]] · [[src/_MOC]] ·
[[Backend Toolchain]] · [[Backend Native Tests]]
