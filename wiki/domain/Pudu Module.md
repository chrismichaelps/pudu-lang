---
type: domain
tags: [domain]
aliases: [Source Module]
---

# Pudu Module

- **Definition:** A named compilation and visibility unit containing imports and declarations, normally backed by one `.pudu` source file.
- **Canonical name:** Pudu Module.
- **Not:** An FMCF implementation module.
- **Invariant:** A module name is PascalCase segments and must match its manifest-relative path.
- **Visibility:** Declarations are private unless explicitly `export`.
- **Side effects:** Module loading never runs user code.

## Referenced by

[[Pudu Program]] · [[grammar/pudu]] · [[Name Resolution]]
