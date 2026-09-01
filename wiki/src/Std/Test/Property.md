---
type: module
path: "@root/lib/Std/Test/Property.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.6
tags: [module, stdlib, medium]
aliases: [Std Test Property]
---

# Std Test Property

## Purpose

Check that a property holds over generated values, and report the smallest value that breaks it.

## Interface

8 exports: the `Gen` and `Shrink` types, the shrinks (`shrinkInt`, `shrinkArray`, `shrinkText`,
`shrinkNothing`), and `forAll` with the `forAllInts` shorthand.

### Governance

- **The seed is given, never taken from a clock.** A property check is therefore a pure function of
  it, a suite stays a value that answers the same thing twice, and a failure can be repeated exactly.
  A random test whose seed is not reported is one a reader can only run again and hope about.
- **A failure reports the seed beside the counterexample.** That is what makes the run reproducible
  rather than merely described.
- **A counterexample is reduced before it is reported**, and the report says in how many steps. The
  value found and the value reported are both useful: the first shows the property was tested at
  scale, the second is the one a reader can hold in their head.
- A `Gen` is the shape [[Std Random]] already uses — a generator in, a generator and a value out —
  so anything in that module is one without adapting.
- Shrinking is **bounded** in rounds. A `Shrink` that does not shrink would otherwise never finish,
  and a test that hangs is worse than one reporting a large counterexample.
- Shrinks halve rather than step, so a counterexample of a million reduces in about twenty tries.

### Linkage

- **Requires:** [[Std Fmt]], [[Std Random]], [[Std Test]].
- **Consumed by:** programs.

## Algorithm

Generate up to the run count, keeping the first value that breaks the property. Then reduce: each
round takes the first candidate that still breaks it and starts again from there, so the search
follows one path down rather than exploring every branch. Rounds are capped.

`shrinkInt` offers zero, the positive twin of a negative, and the value halfway back toward zero,
repeatedly — a binary search rather than a walk. `shrinkArray` and `shrinkText` remove chunks
first, halving, then single elements, because a counterexample is usually short and reaching it one
element at a time takes as many tries as the sequence is long.

## Negative Logic (Prohibited Paths)

- No seed from a clock, which would make a suite answer differently on two runs.
- No unbounded shrinking, which a `Shrink` that grows would turn into a hang.
- No reporting of the generated value in place of the reduced one.
- No exploration of every shrink branch; one path down is what keeps the work bounded.

## Edge Cases

- A property that holds reports the run count in its name, so a passing property says how hard it
  was tried.
- `shrinkInt(0)` and `shrinkArray` of an empty sequence answer nothing, since there is nothing
  simpler.
- A `Shrink` that answers nothing leaves the counterexample as found, reported in zero steps.
- A property whose first generated value already fails still reduces from it.

## Depth

DEPTH 0.50 (MEDIUM). One search, bounded, over generators that are ordinary functions.

## Grill Log

- **Q:** Why must the caller supply a seed? **A:** Because a test that cannot be repeated is a test
  a reader cannot act on. _Rationale:_ it also keeps a suite a pure value, which is what the whole of
  [[Std Test]] rests on; a clock inside here would make one check in a suite non-deterministic and
  the suite with it. _Rejected:_ seeding from the clock with the seed printed, which is what most
  libraries do and still leaves the default run irreproducible.
- **Q:** Why report the shrink step count? **A:** Because the reduced value alone does not say
  whether the property fails everywhere or only at a boundary reached after a long search.
  _Rationale:_ "shrunk in 3 steps" beside the value tells a reader how far the failure travelled.
  _Rejected:_ reporting only the minimum, which is what a reader acts on but not all they want.
- **Q:** Why no `Arbitrary`-style trait picking a generator by type? **A:** Because the generator is
  the interesting part of a property and hiding it makes a failing test hard to read. _Rationale:_
  passing it explicitly costs one argument and says exactly what was generated. _Deferred:_ a trait
  supplying a default generator per type, now that a parameter may stand for a constructor — worth
  revisiting once there is a second module wanting it.

## Referenced by

[[src/Std/_MOC]] · [[Std Test]] · [[architecture/STDLIB]]
