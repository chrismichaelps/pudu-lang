---
type: moc
tags: [moc, module]
---

# Foreign Module Map

- [[Foreign Crossing]] — what may pass between this language and another, stated once for the checker and the runtime both.
- [[Foreign Callback Signature]] — allowed trampoline values, typed failure results and native context pairing.
- [[Foreign Callback Native Adapter]] — C trampoline preparation, live context registration and inbound decoding.
- [[Foreign Callback Store]] — per-run invocation admission, leases, retirement and retained failures.
- [[Foreign Call]] — opening a library the platform already has, finding a function in it, and calling through a signature assembled while the program runs.
- [[Foreign Ownership]] — per-evaluation native-resource claims, atomic call leases, release coordination, and teardown cleanup.

The modules separate declaration policy, native invocation, and resource lifetime. [[ADR-0018 Calling a Library Written Elsewhere]] states the design.

## Referenced by

[[src/Pudu/_MOC]] · [[Runtime]]
