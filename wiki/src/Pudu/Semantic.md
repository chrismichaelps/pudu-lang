---
type: module
path: "@root/src/Pudu/Semantic.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 3.0
interface_stability: 0.9
tags: [module, shallow]
aliases: [Semantic Boundary]
---

# Semantic Boundary

## Purpose

Expose name-resolution products, symbol facts, tooling projections, and the pure cross-module export index without re-exporting semantic implementation internals.

## Interface

### Signatures

```haskell
resolveModule :: Module -> (Resolution, [Diagnostic])
resolveModuleWith :: ExportIndex -> Module -> (Resolution, [Diagnostic])
moduleSymbolNames :: Resolution -> [Text]
boundSymbolNames :: Resolution -> [Text]
emptyExportIndex :: ExportIndex
exportIndex :: Map ModuleName Module -> ExportIndex
```

### Governance

- The facade re-exports stable semantic values and entry points only. Scope and resolver state representations stay private.
- Tooling name projections filter by symbol origin rather than guessing from spelling.
- `ExportIndex` is pure loaded-module data from [[Semantic Interface]]; the facade exposes construction but no filesystem lookup.
- Existing isolated `resolveModule` behavior remains stable while [[Compiler Pipeline]] may consume the indexed resolver directly.

### Linkage

- **Requires:** [[Name Resolution]], [[Semantic Interface]], [[Symbol Model]], [[grammar/haskell]].
- **Consumed by:** [[Compiler Pipeline]], [[Compiler Program]], [[Repl Session]], tests, and later semantic phases.

## Algorithm

Delegate resolution and export-index construction, and filter completed resolution symbols by their declared origins for tooling views.

## Negative Logic (Prohibited Paths)

- No scopes, diagnostics policy, filesystem access, type checking, evaluation, or wildcard re-export of implementation modules.

## Edge Cases

- Tooling omits the REPL's synthetic function separately; this facade reports every matching semantic origin it is asked to project.
- An empty export index is a real value used by isolated compilation, not a missing global singleton.

## Depth

DEPTH 0.30 (SHALLOW by intent). This is a curated stable facade whose deletion would couple tools to several semantic implementation modules.

## Grill Log

- **Q:** Re-export every semantic module? **A:** No; expose only stable products and constructors consumers require. _Rationale:_ callers should not depend on scope/resolver representation. _Rejected:_ umbrella wildcard exports; callers importing implementation modules directly.
- **Q:** Should the export index live in compiler tooling? **A:** No; its meaning is semantic visibility and namespace identity, while loading it is tooling. _Rationale:_ [[Compiler Program]] owns IO and [[Semantic Interface]] owns what a module exports. _Rejected:_ filesystem-aware semantic facade; duplicating export projection in compiler and resolver.

## Referenced by

[[src/Pudu/_MOC]] · [[src/Pudu/Semantic/_MOC]] · [[Compiler Pipeline]] · [[Compiler Program]] · [[Repl Session]]
