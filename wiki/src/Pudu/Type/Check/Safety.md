---
type: module
path: "@root/src/Pudu/Type/Check/Safety.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.45
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium, semantics]
aliases: [Type Check Safety]
---

# Type Check Safety

## Purpose

Check the two questions the language asks about *what code may do*: whether a compile-time function
stays pure, and whether an unsafe call has the capabilities it needs.

## Interface

```haskell
requireComptimePurity    :: Function -> Checker ()
checkComptimeCall        :: Span -> Located Expression -> Checker ()
comptimeBuiltins         :: [Text]
checkUnsafeCall          :: Span -> Located Expression -> Checker ()
reportUnusedCapabilities :: Span -> Checker ()
```

### Governance

- Compile-time purity is **transitive**. A `comptime` body may call only other `comptime` functions,
  against a closed allowlist of prelude names, because a pure-looking function that reached an
  arbitrary one would let the evaluator meet it while the compiler is running.
- A `comptime` function may be neither `async` nor `unsafe`, refused at the declaration rather than
  discovered when it runs.
- An unsafe call propagates its requirement to the caller: a callee's declared capabilities must be
  granted by an enclosing region or by the caller's own declaration (`E3023`).
- A function's unsafety is a contract its callers uphold, not a use its body must justify, so
  leaving a function's implied region reports nothing. Only an explicit `unsafe { ... }` that grants
  more than it uses earns a warning.

### A note on this module's shape

These are **two implementations of one idea** — transitive checking of what a body may reach — with
two vocabularies and two diagnostic families. Effects are a third, checked only at run time.
[[ADR-0009]] proposes collapsing all three into one capability set carried in the type; putting them
in one module is the first step toward being able to see that.

### Linkage

- **Requires:** [[Type Env]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]].

## Algorithm

Direct inspection of a declaration's modifiers, and of a callee's name against the checker's record
of comptime and unsafe functions. No expression recursion, which is why this can be a separate
module.

## Negative Logic (Prohibited Paths)

- No inference, unification, or expression walking.
- No open capability vocabulary: a name outside the closed set is a diagnostic, not a new capability.

## Referenced by

[[src/Pudu/Type/Check/_MOC]] · [[Type Check]] · [[ADR-0009]] · [[grammar/pudu]]
