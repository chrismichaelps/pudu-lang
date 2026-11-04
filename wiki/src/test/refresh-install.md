---
type: module
path: "@root/test/refresh-install.py"
fidelity: Active
aliases: [Refresh Installation Test]
tags: [module, test, installation]
---

# Refresh Installation Test

## Purpose and interface

Execute the real refresh shell script in temporary directories with recording Cabal, Pudu and
Node executables. Require optimization level 2 for build and install, correct install destination,
and version/check/REPL/LSP verification of the resolved executable. A shadowing executable with
different bytes must fail before verification. Build and installation failures must stop the
script and preserve their exit status. No compiler build, package download or real installation
occurs. Run with `python3 test/refresh-install.py`.

## Resolved Grill Log

- **Q:** Match command text only? **A:** Execute the shell orchestration; a mock records exact
  arguments, so quoting, control flow and error propagation are exercised.
- **Q:** Repeat the full compiler gate? **A:** No; this change controls configuration, not language
  semantics. Existing render conformance checks cover the optimized engine runtime separately.

## Referenced by

[[Refresh Pudu Installation]] · [[src/_MOC]] · [[Optimized Refresh Delivery]]
