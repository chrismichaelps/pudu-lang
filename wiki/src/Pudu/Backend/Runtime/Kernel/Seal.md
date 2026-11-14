---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Seal.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Sealing Kernels]
---
# Native Sealing Kernels

Export the family's runtime parts and their prerequisites.

ChaCha20-Poly1305 with a 32-byte key and 12-byte nonce: seal appends the 16-byte tag; open checks the tag in constant time before decrypting.

## Resolved Grill Log

The validity test and the transform are separate kernels so lowering builds the Option; the tag check costs one pass.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
