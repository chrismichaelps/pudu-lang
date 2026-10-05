---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/ComptimeDependencies.hs"
fidelity: Active
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, derive, cache, graph]
aliases: [Compile-Time Dependency Closure]
---

# Compile-Time Dependency Closure

## Purpose and interface

`compiletimeDependencies :: Map ModuleName Module -> Set ModuleName` identifies
the conservative source-content closure required by expansion and folding.
Its seeds are modules with constant initializers, derive definitions, inline
requests or external derive requests. The result includes each seed and every
loaded module reachable through its imports.

## Algorithm and invariants

Inventory declaration headers without walking ordinary bodies. Traverse import
edges using one visited set and deterministic module order. Each loaded module
enters the result once; cycles terminate, diamonds share visits and missing
modules are excluded. [[Compiler Program]] selects full source fingerprints for
this closure and ordinary position-free interface keys for all other modules.
The closure is invocation-local and performs no IO, checking or expansion.

## Negative logic and edge cases

Pure ordinary functions may run during folding, so a comptime-marker-only
dependency inventory is unsound. Imported helpers may call other imported
helpers or values indirectly. Until exact closed compiler dependencies are
recorded, import reachability is a conservative proof of every possible source
input. Relocation inside this closure may cause an additional safe miss;
ordinary runtime-only modules retain their existing body-free interface keys.
Do not hash only named direct callees, trust timestamps or reuse stale constants
to preserve a cache hit. No cache latency guarantee is made for invalidated graphs.

## Grill Log

- **Q:** Only fingerprint marked compile-time function bodies? **A:** Include
  the source closure of actual expansion/folding roots. _Rationale:_ ordinary
  pure calls already fold. _Rejected:_ stale frozen consumers or hashing every
  runtime body in every graph regardless of compile-time work.
- **Q:** Restrict closure to direct imports? **A:** Follow transitive edges.
  _Rejected:_ missing helper-to-helper dependencies or unbounded cycle recursion.
- **Q:** Re-run resolution to find possible callees? **A:** Use conservative
  imports at this boundary. _Rejected:_ a second partial name resolver that
  misses higher-order/private calls. Exact dependencies can refine misses later.

## Linkage and references

Requires [[Syntax Tree]] and [[Syntax Name]]. Referenced by [[Compiler Program]],
[[Compiler Cache]] · [[src/Pudu/Compiler/_MOC]].
