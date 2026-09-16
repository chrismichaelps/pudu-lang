---
type: domain
tags: [domain]
aliases: [Source, Source File]
---

# Source Text

- **Definition:** Immutable decoded Pudu input paired with a stable source identifier and scalar/line/column mapping; UTF-8 validation occurs before this value exists.
- **Canonical name:** Source Text.
- **Not:** Host-language `String` without identity or validated encoding.
- **Invariant:** Compiler spans are half-open Unicode-scalar offsets in v0.1; user-facing columns also count Unicode scalar values. A future immutable source index may map these offsets to UTF-8 bytes without changing span identity.

## Referenced by

[[architecture/OVERVIEW]] · [[Frontend]] · [[Diagnostic]]
