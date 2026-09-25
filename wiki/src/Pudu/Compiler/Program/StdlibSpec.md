---
type: module
path: "@root/test/Pudu/Compiler/Program/StdlibSpec.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.62
depth_status: DEEP
coupling: 3.0
interface_stability: 0.9
tags: [module, test, deep]
aliases: [Standard Library Program Spec]
---

# Standard Library Program Spec

## Purpose

Verify standard-library discovery, graph participation, namespace shadowing, and diagnostics that require loaded module interfaces.

## Interface

`stdlibProperties` contributes `testStandardLibrary` to the package test runner.

### Linkage

- **Requires:** [[Pudu Program]], [[Type Check Pattern]], [[Semantic Interface]].
- **Consumed by:** the package test runner.

## Algorithm

Compile complete fixture programs against the distributed standard library, then compare diagnostic codes, messages, help text, and discovered module names exactly.

## Negative Logic (Prohibited Paths)

- No isolated-module substitutes for behavior that depends on imported interfaces.

## Edge Cases

- A qualified constructor-pattern typo is checked with the imported module loaded and must produce exactly one `E3033`.

## Depth

DEPTH 0.62 (DEEP). It crosses source discovery, interfaces, resolution, and type checking.

## Grill Log

- **Q:** Why test the constructor typo here as well as in isolated type tests? **A:** A module qualifier is recognizable only when its interface has been loaded. _Rationale:_ isolated compilation intentionally treats imports opaquely. _Rejected:_ a local type as a stand-in for module export behavior.

## Referenced by

[[src/Pudu/Compiler/Program/_MOC]] · [[Type Check Pattern]]

## Reading-number refusals (#349)

`RejectsTextToNumberMisuse` asserts `["E3001", "E3003"]`: the result is an `Option`, and the
methods take no arguments.

## Universal `toText` refusals (#347)

`RejectsToTextMisuse` asserts `["E3001", "E3003"]`: the result is text, and the method takes no
arguments.
