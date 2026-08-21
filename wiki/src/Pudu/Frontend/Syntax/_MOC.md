---
type: moc
tags: [moc, module]
---

# Syntax Internals Map

- [[Syntax Located]] — uniform source locations and safe span composition.
- [[Syntax Name]] — dotted module/name paths.
- [[Syntax Tree]] — mutually recursive untyped declarations, blocks, statements, types, and expressions.

The mutually recursive tree remains one data-only file; behavior belongs to parser and semantic modules.

## Referenced by

[[Syntax]] · [[src/Pudu/Frontend/_MOC]]
