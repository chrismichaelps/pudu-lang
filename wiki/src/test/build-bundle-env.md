---
type: module
path: "@root/test/build-bundle-env.mjs"
fidelity: Active
tags: [test, bundle, environment]
aliases: [Bundle Environment Gate]
---
# Bundle Environment Gate

## Purpose and interface

`testBundleEnvironment(executable, runtime)` builds a nested Pudu entry and returns named
failures, including termination signals and launch errors. [[Bundle End-to-End Gate]] calls it for the current runtime and a source-only runtime.
The program reports `PUDU_LIB` and reads a relative marker from the caller's working directory.

## Algorithm and resolved Grill Log

Run with the variable absent, empty, pointing at an unavailable directory and containing spaces.
Compare exact option values, status and marker contents. Use an empty inherited environment and
an unrelated run directory; release every temporary artifact in a finalizer.
Resolved Grill Log: asserting restoration after exit misses the bug; assert what Pudu sees while
it is running, through both cached and source-only bundle paths.

## Referenced by

[[Bundle End-to-End Gate]] · [[Pudu CLI]] · [[src/_MOC]]
