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
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Eval Builtin]] · [[Std Db]] · [[architecture/STDLIB]]
