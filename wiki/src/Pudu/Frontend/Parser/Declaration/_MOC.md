---
type: moc
tags: [moc, module]
---

# Declaration Parser Modules

- [[Parser Import]] — absolute module imports, aliases, and explicit item selections.
- [[Parser Binding]] — module constants and scope-safe local `let`/`var`/`const` declarations.
- [[Parser Block]] — brace-delimited statement sequences, newline statement boundaries, and block results.
- Future bounded partitions add function and declaration-orchestration modules.

The submodules accept narrow parser capabilities and never import the declaration orchestrator, preventing the recursive block/expression/declaration knot from becoming a Haskell module cycle.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Frontend]]
