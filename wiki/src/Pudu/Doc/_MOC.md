---
type: moc
tags: [moc]
aliases: [Doc Module Map]
---

# Documentation Module Map

- [[Doc Index]] — what a module declares, with the type the checker inferred for it.
- [[Doc Signature]] — the searchable shape of an inferred type.
- [[Doc Query]] — parses a search query into a name or a type shape.
- [[Doc Search]] — ranks index entries against a query.
- [[Doc Json]] — the encoding editors and a search server consume.

Dependency direction: Signature → Index → Query/Search/Json. Nothing here performs IO, and
nothing re-derives a type from written syntax.

## Referenced by

[[src/Pudu/_MOC]] · [[Tooling]]
