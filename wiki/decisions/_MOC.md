---
type: moc
tags: [moc, adr]
---

# Decision Map

- [[ADR-0015-hash-contract-and-hash-map]] — coherent equality/hashing and deterministic persistent hash maps.
- [[ADR-0018-calling-a-library-written-elsewhere]] — accepted: a foreign block declares a library once, ownership is named in the declaration, and calling one needs the capability the language already reserved.
- [[ADR-0017-what-the-web-layer-refuses]] — accepted: framing ambiguity, header injection, cross-site changes, off-site redirects, escaping paths, and self-disclosure are refused by default.
- [[ADR-0016-an-application-is-a-value]] — accepted: wiring is a graph the programmer wrote, lifecycle is a list, and the program is a value that can be read without being run.

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
- [[decisions/ADR-0010-refutable-pattern-conditions|ADR-0010 Refutable Pattern Conditions]] — accepted: `if let` binds one successful pattern without introducing a second pattern semantics.
- [[decisions/ADR-0011-propagation-over-re-matching|ADR-0011 Propagation Over Re-Matching]] — accepted: an arm that rebuilds its own failure is punctuation, not a decision; `?` carries both `Result` and `Option`, and `let … else` binds past a fallback that cannot fall through.
- [[decisions/ADR-0012-diverging-blocks-preserve-never|ADR-0012 Diverging Blocks Preserve Never]] — accepted: a resultless block ending in a direct control transfer preserves `Never` instead of fabricating unit.
- [[decisions/ADR-0013-ordered-set-literals-and-membership|ADR-0013 Ordered Set Literals and Membership]] — accepted: `#{...}` constructs the existing ordered Set and `in` performs Set-only membership at comparison precedence.
- [[decisions/ADR-0014-parameters-of-higher-kind|ADR-0014 Parameters of Higher Kind]] — accepted: a type parameter states its arity and may stand for a constructor, so a trait can abstract over the container.
