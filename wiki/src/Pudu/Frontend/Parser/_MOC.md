---
type: moc
tags: [moc, module]
---

# Parser Internals Map

- [[Parser State]] — opaque token cursor, expectations, diagnostics, and bounded recovery.
- [[Parser Name]] — dotted module/name paths and identifiers.
- [[Parser Type]] — bounded reference, tuple/unit, named, and generic type syntax.
- [[Parser Expression]] — bounded precedence, postfix, literal, block-capability, and conditional expression grammar.
- [[src/Pudu/Frontend/Parser/Declaration/_MOC|Declaration modules]] — modular imports first, followed by bindings, functions, blocks, and orchestration.
- Future partitions add declaration and public-facade modules after these dependencies merge.

Dependency direction avoids import cycles: State → Name/Type/Expression → Declaration submodules; declaration orchestration later injects block parsing into Expression.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
