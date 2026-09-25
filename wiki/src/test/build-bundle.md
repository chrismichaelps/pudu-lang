---
type: module
path: "@root/test/build-bundle.mjs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
tags: [module, test, bundle, deployment]
aliases: [Bundle End-to-End Gate]
---

# Bundle End-to-End Gate

## Purpose

Verify that a built program runs after being copied away from the build directory with an empty
environment, while the executable still answers compiler commands when no program is attached.

## Interface

`node test/build-bundle.mjs [path-to-pudu]` builds temporary programs, runs their bundles, and exits
nonzero with collected failures. The optional executable path defaults to `pudu`.

## Contract

- The first program imports shipped modules. The gate checks that the build reports at least the
  application and its imports, then runs the bundle from both its original and copied paths with
  no inherited environment.
- A bundled run under a separate cache home must produce the same answer, create no cache directory,
  and leave another program's existing cache entry intact. This checks the isolation half of
  [[Compiler Cache]] and [[Pudu Bundle]].
- A second program checks character counts and file contents under a minimal locale. The gate also
  checks the compiler version command and reports write failures without a crash or partial target.
- Building onto a named runtime, rebuilding onto an already bundled runtime, refusing a missing
  runtime, and refusing an unknown option each preserve the documented target behavior. Rebuilding
  the same program onto an existing bundle must produce byte-identical output. A default build
  carries at least one product; a build onto a runtime built from the same sources carries them too,
  while a runtime whose source digest differs (the compiler with one digest digit changed) carries
  none, still runs, and the build says it will be checked at every start.
- Temporary executables are removed after use so the gate does not retain several compiler-sized
  artifacts.

## Negative Logic

- A successful run in the source directory alone is insufficient evidence of deployment isolation.
- Timing is not asserted: this gate checks behavior and cache ownership; the performance evidence
  is recorded separately in [[Compiler Cache]].

## Grill Log

- **Q:** How does the gate detect dependence on the build machine? **A:** It copies the artifact to
  another temporary directory and starts it with an empty environment. _Rationale:_ inherited paths
  could hide a missing bundled module. _Rejected:_ running only beside the source tree.
- **Q:** Should the cache test assert a fixed start time? **A:** No. _Rationale:_ host load varies, while
  the observable isolation contract is deterministic. _Rejected:_ a wall-clock threshold in CI.

## Referenced by

[[src/_MOC]] · [[Pudu Bundle]] · [[Compiler Cache]]
