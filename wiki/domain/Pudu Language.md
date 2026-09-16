---
type: domain
tags: [domain]
aliases: [Pudu]
---

# Pudu Language

- **Definition:** A statically typed native systems language for predictable performance and explicit control without unchecked memory access in ordinary code.
- **Target users:** Systems, CLI, service, and performance-sensitive application developers.
- **Runtime:** Native executables with a small explicit runtime; an interpreter supports development and conformance.
- **Adoption path:** Standalone CLI and C ABI interoperability.
- **Killer capability:** Ownership-checked native code with concise algebraic data modeling, typed recoverable failures, and structured concurrency.
- **Not:** A C++ syntax clone, a garbage-collected application language, or a research vehicle for maximum type-system expressiveness.

## Non-goals for v1

- C++ source or ABI compatibility.
- Higher-kinded, dependent, or implicit-evidence types.
- Arbitrary compile-time execution or user-defined procedural macros.
- Detached tasks by default.
- Reflection, runtime code loading, or ambient null.
- Multiple native backends before semantics stabilize.

## Referenced by

[[00-INDEX]] · [[architecture/_MOC]] · [[Pudu Program]] · [[Standard Library]] · [[ADR-0001-language-purpose-and-v1-scope]]
