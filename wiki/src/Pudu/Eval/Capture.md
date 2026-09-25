---
type: module
path: "@root/src/Pudu/Eval/Capture.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 0.4
interface_stability: 0.9
tags: [module, medium]
aliases: [Eval Capture]
---

# Eval Capture

## Purpose

Say which names a function literal's body can reach out to, so the environment it captures holds
those and not everything that happened to be in scope beside them.

## Interface

### Signatures

```haskell
reachableNames :: Function -> Set Text
```

### Governance

- **The answer is an over-approximation, deliberately.** A name collected here that the literal
  cannot use costs one entry in a map; a name missed is a binding that vanished, reported far from
  where it was dropped. So nothing is subtracted — not parameters, not names the body itself declares
  — and every spelling that reaches a binding at run time is collected.
- **The keys are the evaluator's own keys.** A path is looked up whole and by each of its prefixes,
  because `Std.Char.toUpper` may be one binding or a module reached by two steps, so every prefix is
  collected. A record field written without a value takes the binding of its own name, so that name
  is collected too. This module's `flatten` mirrors [[Eval Call Path]]'s, and the two have to keep
  agreeing.
- **Names that are not in the syntax are not this module's problem.** An implementation's method is
  found from the type of a value the program is holding — `Owner.advance` for a `for` over a user
  type — and no analysis of the body could know it. Those live in module scope, which [[Eval Env]]
  keeps whole; this module only narrows the frames a call pushed, and those hold nothing but names
  somebody wrote.
- **This is about what a capture keeps alive, not what it costs to take.** Capturing the frame list
  was already a pointer copy. What it was not was cheap afterwards: two hundred literals made in a
  loop beside a twenty-thousand element array held 416MB, and hold 76MB now — the same as the loop
  that makes no literals at all.

### Linkage

- **Requires:** [[Program Syntax Tree]].
- **Consumed by:** [[Evaluator]], through [[Eval Env]]'s `capturedFrames`.

## Algorithm

One structural walk of the function, collecting a `Set Text`. Paths contribute every dotted prefix;
everything else contributes what it names.

## Negative Logic (Prohibited Paths)

- No subtracting bound names, which would turn a shadowed capture into a missing one.
- No narrowing module scope, which holds names no syntax spells.
- No assuming a member access is a field read: a chain of members may be one dotted binding.

## Edge Cases

- A literal written while a module's own declarations are still loading is captured whole, because
  the line between module scope and a call has not been drawn yet.

## Depth

DEPTH 0.50 (MEDIUM). One walk, and one rule about which direction to be wrong in.

## Grill Log

- **Q:** Why not compute true free variables, subtracting what the body binds? **A:** Because the
  gain is a few map entries and the cost of being wrong is a program that cannot find a name it can
  see. _Rejected:_ a scope-tracking walk, which would have to model every binding form correctly to
  be as safe as doing nothing does.
- **Q:** Why is module scope kept whole rather than narrowed the same way? **A:** Because names in it
  are looked up by keys built from runtime values — an implementation's method found from the type
  of a value in hand — and no syntactic analysis can predict them. It is also alive for the length
  of the program, so keeping it costs nothing. _Rejected:_ collecting method names too, which would
  be a guess that happened to work until a program implemented a trait this module had not thought
  of.
- **Q:** Should the walk be cached per literal? **A:** Not yet. _Rationale:_ a literal's body is
  small and the measured cost of the walk is inside the noise of the calls around it. _Deferred:_
  revisit if a profile ever shows it.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Eval Env]] · [[Evaluator]]
