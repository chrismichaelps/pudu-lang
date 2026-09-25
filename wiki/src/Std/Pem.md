---
type: module
path: "@root/lib/Std/Pem.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, encoding, security]
aliases: [Std Pem]
---

# Std Pem

## Purpose and interface

The textual armor certificates, keys, and bundles are stored in (RFC 7468).

- `type Block = { label: Str, content: Bytes }`.
- `type PemError = NoBlock | BadLabel(Str) | Unterminated(Str) | MismatchedEnd(Str, Str) |
  BadBody(Str)`; `explain(problem) -> Str`.
- `encode(block) -> Result[Str, PemError]`, `decodeAll(text) -> Result[Array[Block], PemError]`,
  `decode(text) -> Result[Block, PemError]`, `withLabel(blocks, label) -> Array[Bytes]`.

## Semantics

- A label is printable ASCII with no hyphen at either end and no leading, trailing, or doubled
  space; `encode` refuses one `decodeAll` would reject.
- `encode` writes the BEGIN line, the base64 body in 64-column lines, the END line, each ending in
  `\n`.
- `decodeAll` trims lines, ignores text outside blocks, strips whitespace within a body, requires the
  END label to equal the BEGIN label, and decodes with [[Std Bytes]] `decodeBase64`. A body line
  containing `:` is refused: that is the legacy encrypted-header form, which must not be returned as
  plain key bytes. An unclosed block and a text with no block are refused.

## Grill Log

- **Q:** Parse and return encapsulated headers? **A:** No. _Rationale:_ RFC 7468 forbids them; they
  exist for the legacy encrypted form, and returning its ciphertext as a key invites misuse.
- **Q:** Return the first block only? **A:** Both. _Rationale:_ bundles hold many; `withLabel`
  selects by what the caller expects rather than by position.
- **Q:** Parse certificates here? **A:** No. _Rationale:_ armor is transport; structure belongs to the
  consumer.

## Dependencies and consumers

- Depends on [[Std Bytes]] base64. Reached by [[Uses Base32 Pem All]]; intended for TLS
  configuration and key loading.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[Uses Base32 Pem All]]
