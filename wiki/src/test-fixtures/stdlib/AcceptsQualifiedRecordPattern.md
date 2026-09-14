---
type: module
path: "@root/test-fixtures/stdlib/AcceptsQualifiedRecordPattern.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Testing]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.40
depth_status: MEDIUM
coupling: 2.0
interface_stability: 1.0
tags: [module, fixture, diagnostic]
aliases: [Accepts Qualified Record Pattern]
---

# Accepts Qualified Record Pattern

## Purpose

Prove that a record type reached through a module qualifier is matched as a record pattern and is not
reported as a missing qualified constructor.

## Interface

Exports `main`, which returns `48002` when run; the spec compiles it and expects no diagnostics.

### Linkage

- **Requires:** [[Std Audio]], [[Type Check Pattern]].
- **Consumed by:** [[Standard Library Program Spec]].

## Algorithm

Build a real `Std.Audio.Format` and destructure it with `Audio.Format { sampleRate, channels }`.

## Negative Logic (Prohibited Paths)

- The pattern must not produce `E3033`: `Audio` exports the type `Format`, which is not a constructor.

## Edge Cases

- `Format` is a record type, so no variant table holds it; only its full qualified path names it.

## Depth

DEPTH 0.40 (MEDIUM). The companion of [[Rejects Missing Constructor Pattern]]: the same qualifier
lookup, on the path that must stay accepted.

## Grill Log

- **Q:** Check record types before reporting a missing qualified constructor? **A:** Yes. _Rationale:_
  the qualified-constructor diagnostic otherwise rejected every record pattern written through a
  module alias. _Rejected:_ requiring an unqualified import to destructure an imported record.

## Referenced by

[[Standard Library Program Spec]] · [[Type Check Pattern]]
