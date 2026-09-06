---
type: module
path: "@root/src/Pudu/Eval/Hash.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, hashing, crypto]
aliases: [Eval Hash]
---
# Eval Hash
## Purpose
Provide runtime-speed SHA-256, HMAC-SHA-256, PBKDF2-SHA-256, and non-cryptographic value mixing.
## Interface
Exports byte/value hashing, SHA-256, keyed SHA-256, and PBKDF2 derivation.
## Governance and algorithm
Digest primitives must match the Pudu implementation and published vectors. `hashOfValue` is a
collection mixer, not a digest or cross-run identity; iteration/length validation occurs at the
typed built-in boundary. PBKDF2 refuses more than ten million rounds or one mebibyte of output
before converting arbitrary-precision values to host `Int`; the bounds prevent overflow and
unbounded work/allocation while admitting deployed password-hashing parameters.
## Grill Log
- **Q:** Present the fast mixer as cryptography? **A:** No. _Rationale:_ it promises neither secrecy
  nor stable cross-run output. _Rejected:_ PBKDF2 in the tree-walking interpreter's hot loop; trusting
  two implementations merely because they round-trip with themselves.
- **Q:** Convert an arbitrary Pudu count directly to host `Int`? **A:** No. _Rationale:_ conversion
  can wrap and a hostile peer can otherwise demand unbounded CPU or memory. _Rejected:_ relying on
  eventual allocation failure; an unbounded iteration count.
- **Q:** Import `Data.List (foldl')` under GHC 9.10? **A:** No; `foldl'` is in Prelude; omit redundant import for -Werror compliance.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Builtin]] · [[Std Db]] · [[architecture/STDLIB]]

## Word-specialized integer hashing

Magnitudes fitting Word64 are mixed directly from their most-significant nonzero byte through the
least-significant byte, followed by the sign byte. Zero contributes one zero magnitude byte. This
preserves the prior FNV byte stream exactly while avoiding byte-list and ByteString construction
for machine-word keys. Larger magnitudes retain the general byte extraction and fold that list
directly, without packing it or appending a singleton sign list. Width admission compares the full
Integer before conversion; no high bits are discarded.

### Resolved Grill Log
- **Q:** Truncate large integers to enter the fast path? **A:** No; only proven Word64 magnitudes enter it.
- **Q:** Reverse byte order to simplify traversal? **A:** No; preserve the existing stream and resulting hash.
- **Q:** Allocate a buffer only to fold its bytes? **A:** No; mix the proven scalar representation directly.

## Direct scalar-to-hash text path

Text hashing folds Unicode scalars and feeds each scalar's UTF-8 bytes directly into the existing
mixer. ASCII contributes one byte; larger scalars contribute the canonical two-, three-, or
four-byte encoding. No intermediate encoded ByteString is requested by this path. Pudu text
already contains valid Unicode scalars, so this does not introduce a decoding or replacement rule.
Rendered fallback values use the same text mixer after rendering. Hash values remain those of the
canonical UTF-8 stream. This removes an explicit representation conversion; throughput relative
to the text library's optimized encoder is not measured and may vary by character distribution.

### Resolved Grill Log
- **Q:** Hash scalar numbers instead of encoded bytes? **A:** No; feed the original UTF-8 byte stream to preserve hashes.
- **Q:** Normalize Unicode while hashing? **A:** No; normalization would change identity-related behavior.
