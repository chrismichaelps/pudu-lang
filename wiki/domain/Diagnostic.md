---
type: domain
tags: [domain]
aliases: [Compiler Diagnostic]
---

# Diagnostic

- **Definition:** Stable structured feedback with a code, severity, primary span, concise message, optional help, and related spans.
- **Canonical name:** Diagnostic.
- **Not:** A thrown host exception, debug log, or backend stderr blob.
- **Ordering:** Source display name, primary start/end offsets, severity, code, message, help, then ordered related display locations/messages. This canonically orders render-distinct diagnostics; display-equivalent values from separate opaque snapshots may retain producer order because their output is identical.
- **Stability:** Codes are durable once published; messages may improve without changing meaning.

## Referenced by

[[architecture/OVERVIEW]] · [[Source Text]] · [[Frontend]] · [[Semantics]] · [[Tooling]] · [[Diagnostic Model]]
