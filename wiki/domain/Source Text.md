---
type: domain
tags: [domain]
aliases: [Source, Source File]
---

# Source Text

- **Definition:** Immutable UTF-8 Pudu input paired with a stable source identifier and byte/line/column mapping.
- **Canonical name:** Source Text.
- **Not:** Host-language `String` without identity or validated encoding.
- **Invariant:** Compiler spans are half-open byte offsets; user-facing columns count Unicode scalar values.

## Referenced by

[[architecture/OVERVIEW]] · [[Lexer]] · [[Parser]] · [[Diagnostic]]
