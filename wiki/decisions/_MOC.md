---
type: moc
tags: [moc, adr]
---

# Decision Map

- [[ADR-0001-language-purpose-and-v1-scope]] — coherent native systems-language purpose and staged feature admission.
- [[ADR-0002-compiler-pipeline]] — explicit Haskell phases, checked Core IR, interpreter oracle, and C11 backend.
- [[ADR-0003-ownership-and-resource-safety]] — moves, non-lexical borrows, deterministic destruction, and safe/unsafe boundary.
- [[ADR-0004-team-delivery-and-agent-review]] — issue branches, independent agent review, integration, and release flow.
- [[ADR-0005-performance-and-low-level-optimization]] — compiler throughput and proof-preserving native optimization.
- [[decisions/ADR-0006-integer-widths-and-std-numerics|ADR-0006 Integer Widths and Std Numerics]] — integers carry their width at run time; what `Std` promises about numbers.
- [[decisions/ADR-0007-decimal-precision-and-rounding|ADR-0007 Decimal Precision and Rounding]] — `Decimal` is exact, and division is exact or an error rather than silently rounded.

## Referenced by

[[00-INDEX]] · [[architecture/_MOC]]

- [[decisions/ADR-0008-protocol-oriented-typestate|ADR-0008 Protocol Oriented Typestate]] — withdrawn.
- [[decisions/ADR-0009-effects-in-the-type|ADR-0009 Effects in the Type]] — proposed: one capability set in the signature, replacing `comptime`, `unsafe`, and the runtime effect gate.
