---
type: module
path: "@root/src/Pudu/Eval/Sign.hs"
fidelity: Active
tags: [module, runtime, crypto]
aliases: [Eval Sign]
---

# Eval Sign

## Purpose and interface

Ed25519 signing and verification over bytes: `ed25519PublicOf seed`, `ed25519Sign seed message`, and
`ed25519Verify public message signature`.

## Semantics

- A seed is the 32-byte secret; anything else answers `Nothing`, which the prelude surfaces as
  `None`.
- Verification of a malformed key or a signature of the wrong length answers `False` rather than
  raising: keys and signatures arrive from outside.

## Grill Log

- **Q:** Why does the runtime sign at all, when [[Eval Verify]] deliberately only verifies? **A:** A
  desktop application's release tooling signs its own artifacts with its own key; verifying tokens
  from a provider is a different job. Generation of the seed stays in Pudu through `secureRandomBytes`.
- **Q:** Why Ed25519? **A:** Deterministic signatures, 32-byte keys and 64-byte signatures, and no
  parameter choices that can be gotten wrong.

## Dependencies and consumers

Called from [[Eval Builtin]]; consumed by [[Std Crypto Sign]].

## Referenced by

[[src/Pudu/Eval/_MOC]]
