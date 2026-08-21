---
type: moc
tags: [moc, module]
---

# Declaration Parser Modules

- [[Parser Import]] — absolute module imports, aliases, and explicit item selections.
- [[Parser Binding]] — module constants and scope-safe local `let`/`var`/`const` declarations.
- [[Parser Block]] — brace-delimited statement sequences, newline statement boundaries, and block results.
- [[Parser Function]] — `async`/`fn` signatures, parameters with defaults, return types, and bodies.
- One future bounded partition adds the declaration orchestrator and compilation unit.

The submodules accept narrow parser capabilities and never import the declaration orchestrator, preventing the recursive block/expression/declaration knot from becoming a Haskell module cycle.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Frontend]]
