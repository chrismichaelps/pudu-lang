---
type: moc
tags: [moc, module]
---

# Foreign Module Map

- [[Foreign Crossing]] — what may pass between this language and another, stated once for the checker and the runtime both.
- [[Foreign Call]] — opening a library the platform already has, finding a function in it, and calling through a signature assembled while the program runs.

The two are separate because one is a decision and the other is a mechanism: what is allowed to cross is settled where a declaration is read, and carrying it is settled where a call is made. [[ADR-0018 Calling a Library Written Elsewhere]] states the design.

## Referenced by

[[src/Pudu/_MOC]] · [[Runtime]]
