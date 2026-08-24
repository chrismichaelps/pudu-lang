---
type: moc
tags: [moc, module]
---

# Semantic Module Map

- [[Semantic Boundary]] — stable resolution, symbol, tooling-name, and export-index facade.
- [[Symbol Model]] — identity, namespace, origin, and declaration facts for every named entity.
- [[Scope Model]] — pure lexical frames with innermost-first lookup and same-frame conflict reporting.
- [[Semantic Prelude]] — the builtin type names that exist without an import.
- [[Semantic Interface]] — namespace-aware module exports and validated import bindings.
- [[Name Resolution]] — two-pass resolution producing the symbol table, reference map, and `E2xxx` diagnostics.
  - [[Resolve Context]] — the `Resolver` state monad, scope frames, symbol introduction, duplicate/shadow classification, and value/type name resolution the facade walks.
- Future partitions add type formation and checking, ownership and borrow checking, exhaustiveness, and effect analysis.

Dependency direction: Symbol → Scope → Resolve Context → Resolve, with Prelude supplying only names. No semantic module imports a parser module other than [[Syntax Tree]].

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]]
