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

Check the two direct-name questions the current language implementation asks about *what code may
do*: whether a compile-time function directly names an admitted callee, and whether a direct named
unsafe call has the capabilities it needs.

## Interface

```haskell
requireComptimePurity    :: Function -> Checker ()
checkComptimeCall        :: Span -> Located Expression -> Checker ()
comptimeBuiltins         :: [Text]
checkUnsafeCall          :: Span -> Located Expression -> Checker ()
reportUnusedCapabilities :: Span -> Checker ()
```

### Governance

- A `comptime` body may directly call only another named `comptime` function or a closed allowlist
  of prelude names. The check recognizes an unqualified `NameExpression`; function values do not
  carry `comptime` metadata, so aliases and higher-order calls are not checked transitively.
- Constant folding still runs with effects denied at runtime. An indirect call cannot reach IO,
  environment, time, randomness, unsafe effects, or tasks successfully while the compiler is
  evaluating a constant, but the declaration-level higher-order restriction is incomplete.
- A `comptime` function may be neither `async` nor `unsafe`, refused at the declaration rather than
  discovered when it runs.
- A direct unqualified call to a named unsafe function requires its declared capabilities from an
  enclosing region or the caller's own declaration (`E3023`). Function types erase unsafety and
  capabilities, so aliased and higher-order unsafe calls are not enforced by this module.
- A function's unsafety is a contract its callers uphold, not a use its body must justify, so
  leaving a function's implied region reports nothing. Only an explicit `unsafe { ... }` that grants
  more than it uses earns a warning.

- **A callee is judged by the whole path it was written as.** `Bindings.open` and `open` are the
  same function, and what it may do cannot depend on which spelling reached it. Matching only an
  undotted name was how an unsafe function stopped being unsafe the moment it was reached through
  its module — which is exactly the arrangement [[ADR-0018 Calling a Library Written Elsewhere]]
  recommends for bindings, so the boundary dissolved precisely where it was meant to hold.
- **A dotted callee is judged for compile-time purity only when the whole path binds something.**
  `Health.flagOf` is bound under that spelling and is a call this rule is about; `reading.counts` is
  a field of a value, and a built-in method on one is not a declaration at all. Asking whether the
  path binds tells the two apart without inventing a second notion of what a module is.

- **A compile-time body is refused only for a callee known not to fold.** The question is three-way,
  not two: a declared compile-time function may be called, a declared ordinary one may not and is
  refused here where the diagnostic is best, and a parameter or a local is something this pass knows
  nothing about. Refusing the third case made a compile-time function unable to call anything it was
  handed — higher-order compile-time code could not be written at all — and bought no guarantee,
  because what a fold may reach is decided when it folds: an effect reached there is refused at the
  point it happens, naming the effect rather than the indirection that arrived at it.

### A note on this module's shape

These are **two direct-name implementations of one intended idea** — checking what a body may reach
— with two vocabularies and two diagnostic families. Effects are a third, checked at run time.
[[ADR-0009]] proposes collapsing all three into one capability set carried in function types; until
that exists, this module must not claim transitive higher-order enforcement.

### Linkage

- **Requires:** [[Type Env]], [[Syntax Tree]], [[Diagnostic Model]].
- **Consumed by:** [[Type Check]].

## Algorithm

Direct inspection of a declaration's modifiers and an unqualified callee name against the
checker's record of comptime and unsafe functions. Qualified, aliased, and other expression-shaped
callees return without a capability decision. No expression recursion, which is why this can be a
separate module.

## Negative Logic (Prohibited Paths)

- No inference, unification, or expression walking.
- No open capability vocabulary: a name outside the closed set is a diagnostic, not a new capability.
- No claim that ordinary function types preserve `comptime`, unsafety, or named capabilities.

## Referenced by

[[src/Pudu/Type/Check/_MOC]] · [[Type Check]] · [[ADR-0009]] · [[grammar/pudu]]
