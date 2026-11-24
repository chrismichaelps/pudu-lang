---
type: module
path: "@root/test/Pudu/Compiler/Program/GraphSpec.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: DEEP
coupling: 4.0
interface_stability: 0.85
tags: [module, test, deep]
aliases: [Program Graph Spec]
---

# Program Graph Spec

`testIsolatedResolution` verifies exact root-only searches, zero setup metrics, ignored unrelated
manifest failures and E2014 for a bundled import absent from its root even when available locally.
Resolved Grill Log: assert resolution ownership directly and register the compiled refusal.

## Purpose

Verify module discovery, graph edges, interface preparation, manifest-declared dependency roots, and
per-invocation resolution setup.

## Interface

Exports the graph properties that [[Program Spec]] registers, including `testPathDependencies`,
`testResolutionContext`, and `testSourceRootOnce`.

### Linkage

- **Requires:** [[Compiler Library]], [[Compiler Manifest]], [[Compiler Program]].
- **Consumed by:** [[Program Spec]].

## Algorithm

Build temporary projects or read committed fixtures, construct fresh resolution contexts, and compare
exact search-root lists, setup metrics, and diagnostic codes.

## Negative Logic (Prohibited Paths)

- No assertion on a root list after sorting: order is resolution precedence.
- No shared context between the invocations a property compares.

## Edge Cases

- `testSourceRootOnce`: a file under `src/` sees `src` once, whether the manifest's `source`, a
  `src = "src"` self dependency, or `./src/` names it; a trailing separator on the compile root is
  the same directory; `test/` searches itself, then `src`, then external dependencies; the default
  `source` is implicit; a suite under `test/` compiles against a module in `src/`.

## Depth

DEPTH 0.6 (DEEP). It crosses manifest reading, root resolution, and whole-program compilation.

## Grill Log

- **Q:** Why compare search roots rather than only compiling? **A:** A duplicated root still
  compiles; it shows up as a repeated probe and a repeated entry in the `looked in` help.
  _Rationale:_ the regression is in the root list itself. _Rejected:_ compile-only assertions.

## Referenced by

[[src/Pudu/Compiler/Program/_MOC]] · [[Compiler Manifest]]

## Type-only module qualifiers (#993)

Use temporary modules to check missing constructor calls, value reads,
and positional and named patterns against a module exporting only a
type alias. Assert the diagnostic codes and the missing qualified
exports.

Resolved Grill Log. A call, a constructor value, and a pattern can take
separate admission paths. Cover all three and check the selected import
alias in the message. [[Type Check Rule]] · [[Type Check Pattern]]
