---
type: domain
tags: [domain]
aliases: [Compiler Diagnostic]
---

# Diagnostic

- **Definition:** Stable structured feedback with a code, severity, primary span, concise message, optional help, and related spans.
- **Canonical name:** Diagnostic.
- **Not:** A thrown host exception, debug log, or backend stderr blob.
- **Ordering:** Source identifier, primary start offset, severity, then diagnostic code.
- **Stability:** Codes are durable once published; messages may improve without changing meaning.

## Referenced by

[[architecture/OVERVIEW]] · [[Source Text]] · [[Frontend]] · [[Semantics]] · [[Tooling]]
