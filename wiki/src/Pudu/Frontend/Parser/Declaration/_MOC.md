---
type: moc
tags: [moc, module]
---

# Declaration Parser Modules

- [[Parser Import]] — absolute module imports, aliases, and explicit item selections.
- [[Parser Binding]] — module constants and scope-safe local `let`/`var`/`const` declarations.
- [[Parser Block]] — brace-delimited statement sequences, newline statement boundaries, and block results.
- [[Parser Function]] — `async`/`fn` signatures, parameters with defaults, return types, and bodies.
- [[Parser Generic]] — bracketed type parameters, bounds, and `where` constraint clauses shared by every generic construct.
- [[Parser Type Declaration]] — record, sum, and alias `type` declarations.
- [[Parser Trait]] — trait contracts and `impl` blocks.
- [[Parser Macro]] — typed syntax transformers, whose parameters declare the syntax each accepts.
- [[Parser Declaration Foreign]] — a block declaring a library written elsewhere, the functions it exports, and what releases an owned result.

The submodules accept narrow parser capabilities and never import the declaration orchestrator, preventing the recursive block/expression/declaration knot from becoming a Haskell module cycle.

## Referenced by

[[src/Pudu/Frontend/Parser/_MOC]] · [[Frontend]]
