---
type: moc
tags: [moc, module]
---

# Parser Internals Map

- [[Parser State]] — opaque token cursor, expectations, diagnostics, and bounded recovery.
- [[Parser Name]] — dotted module/name paths and identifiers.
- Future partitions add type, expression, declaration, and public-facade modules after these dependencies merge.

Dependency direction avoids import cycles: State → Name/Type → Expression; Declaration later injects block parsing into Expression.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
