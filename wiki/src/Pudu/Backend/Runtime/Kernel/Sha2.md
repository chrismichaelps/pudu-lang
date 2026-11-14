---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Sha2.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native SHA-2 Kernels]
---
# Native SHA-2 Kernels

Export the family's runtime parts and their prerequisites.

SHA-256 and SHA-512 over a byte view with an incremental state, and the digest kernel that selects an algorithm by number.

## Resolved Grill Log

The incremental state serves the keyed digest and key derivation without copying messages.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
