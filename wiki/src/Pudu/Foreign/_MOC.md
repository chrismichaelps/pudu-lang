---
type: moc
tags: [moc, module]
---

# Foreign Module Map

- [[Foreign Extent]] — checked integer lengths and their ordered buffer targets.
- [[Foreign Run Storage]] — ABI stride and aligned storage for fixed-width array elements.
- [[Foreign Crossing]] — what may pass between this language and another, stated once for the checker and the runtime both.
- [[Foreign Callback Signature]] — allowed trampoline values, typed failure results, checked byte extents and native context placement.
- [[Foreign Callback Native Adapter]] — C trampoline preparation, live context registration and inbound decoding.
- [[Foreign Callback Store]] — per-run invocation admission, leases, retirement and retained failures.
- [[Foreign Call]] — opening or closing a scoped library reference, resolving symbols and calling through an assembled signature, including copied scalar and record loans.
- [[Foreign Ownership]] — per-evaluation native-resource claims, atomic call leases, release coordination, and teardown cleanup.

The modules separate declaration policy, native invocation, and resource lifetime. [[ADR-0018 Calling a Library Written Elsewhere]] states the design.

## Referenced by

[[src/Pudu/_MOC]] · [[Runtime]]
