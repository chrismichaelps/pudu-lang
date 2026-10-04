---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Product.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, compiler, performance]
aliases: [Compiler Product Publication]
---

# Compiler Product Publication

## Purpose and interface

Own per-module frontend/checked cache admission and the lifetime of published
products. Export `ProductUse = AnalysisProducts | ExecutionProducts`,
`frontendFor`, `checkedFor` and `publishProduct`. The filesystem graph chooses
the product use before compilation; this module never discovers dependencies.

## Algorithm and invariants

Restore a frontend only under its existing exact-source key; otherwise run the
canonical frontend and store only a diagnostic-free admitted module. Restore
checked syntax, integer kinds and frozen constants under the existing graph
key. A miss runs the supplied canonical compile action and stores the same
diagnostic-free executable product as before.

Analysis publication retains every compiler product for editor, documentation,
lint and REPL consumers; checked-product reuse is bypassed in this mode because
stored executable products do not contain those facts. Execution publication keeps executable syntax, integer
kinds, frozen constants and diagnostics, with that same syntax in compileSyntax.
It drops tokens, resolution, expression types, documentation and declared-method
tooling lists. This is the existing warm-product contract applied also to cold
and cache-disabled executable callers. Source snapshots and graph context remain
owned by [[Compiler Program]]. Never cache a rejected or warning-bearing check.

## Negative logic and edge cases

No phase is skipped, cache identity changed, diagnostic suppressed or inference
fact re-derived. Analysis callers use the uncached entry points and still receive
all facts after errors. Execution errors keep diagnostics but no executable tree.
Constant-fold inputs remain checked modules and retain their exact widths and
frozen values. Cache corruption remains a miss; a frontend cache hit supplies no
tokens and cannot be used as proof that no expansion exists.

## Grill Log

- **Q:** Keep analysis products until process exit on a cold executable check?
  **A:** Publish the same execution products as a warm hit after each module.
  _Rationale:_ unused doc/type closures retain tokens and checker state across
  the graph, where all-Std checking retains about 228 MB live heap. _Rejected:_
  dropping editor facts, changing full-analysis APIs, or weakening checking.
- **Q:** Put cache admission into filesystem discovery? **A:** Keep this bounded
  per-module boundary separate. _Rationale:_ graph orchestration stays below its
  source-size limit and product lifetime is independently specified. _Rejected:_
  an unbounded Program module or boolean flags with unclear result guarantees.

## Linkage and referenced by

Requires [[Compiler Pipeline]] and [[Compiler Cache]]. Consumed by
[[Compiler Program]]; registered in [[Pudu Cabal Manifest]].
[[src/Pudu/Compiler/_MOC]] · [[Program Cache Spec]]
