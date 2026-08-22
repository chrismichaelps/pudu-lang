---
type: moc
tags: [moc, module]
---

# Parser Internals Map

- [[Parser State]] — opaque token cursor, expectations, diagnostics, and bounded recovery.
- [[Parser Name]] — dotted module/name paths and identifiers.
- [[Parser Type]] — bounded reference, tuple/unit, named, and generic type syntax.
- [[Parser Expression]] — bounded precedence, the full postfix family, literals, block capability, and the `if`/`match`/`while`/`loop`/`for` control expressions.
- [[Parser Pattern]] — wildcard, binding, literal, range, tuple, constructor, record, and alternation patterns.
- [[src/Pudu/Frontend/Parser/Declaration/_MOC|Declaration modules]] — modular imports, bindings, blocks, functions, generics, type declarations, traits, and impls.
- [[Parser Declaration]] — compilation-unit orchestration, `export` ownership, import ordering, and module-scope recovery.
- [[Parser]] — the public façade returning a recovered module beside its diagnostics.

Dependency direction avoids import cycles: State → Name/Type/Pattern → Expression → Declaration submodules → orchestrator → façade. [[Parser Block]] is the recursion fixed point: it passes itself to Expression and Binding as their block capability, so no submodule imports the orchestrator.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Frontend]]
