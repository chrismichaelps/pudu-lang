---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Mac.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Keyed Digest Kernels]
---
# Native Keyed Digest Kernels

Export the family's runtime parts and their prerequisites.

HMAC over SHA-256 and SHA-512, PBKDF2 over HMAC-SHA-256, and equality of two byte views in time that depends only on their lengths.

## Resolved Grill Log

Key derivation reuses the padded key states across iterations.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
