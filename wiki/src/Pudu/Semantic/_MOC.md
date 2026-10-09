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
  - [[Resolve Canonical]] — scoped recognition of formed generated paths.
  - [[Scope Index]] — the frames resolution opened, kept with their extents so visibility at a position can be asked afterwards.
  - [[Resolve Context]] — the `Resolver` state monad, scope frames, symbol introduction, duplicate/shadow classification, and value/type name resolution the facade walks.
- Future partitions add type formation and checking, ownership and borrow checking, exhaustiveness, and effect analysis.

Dependency direction: Symbol → Scope → Resolve Context → Resolve, with Prelude supplying only names. No semantic module imports a parser module other than [[Syntax Tree]].

## Referenced by

[[src/Pudu/_MOC]] · [[Semantics]]

- [[Resolve Reflection]] — namespace-aware compile-time import classification.
- [[Resolve Bindings]] — pattern introduction and constructor references.

- [[Reflection Resolution Spec]] — import and namespace refusal regression checks.

- [[Name Resolution Spec]] — compiler and lexical-only phase evidence.

- [[Resolve State]] — invocation-owned pure state and action mechanics.
- [[Module Qualifier Spec]] — namespace/value identity and loaded execution evidence.

- [[Qualified Shadow Spec]] — exact loaded lexical precedence and evaluator agreement.
