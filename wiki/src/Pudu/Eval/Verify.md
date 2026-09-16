---
type: module
path: "@root/src/Pudu/Eval/Verify.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
tags: [module, runtime, crypto, verification]
aliases: [Eval Verify]
---
# Eval Verify
## Purpose
Cryptographic signature verification for RSA-SHA256 and ECDSA P-256 (ES256) algorithms.
## Interface
- `verifyRsaSha256 :: ByteString -> ByteString -> ByteString -> ByteString -> Bool`
- `verifyEcdsaP256Sha256 :: ByteString -> ByteString -> ByteString -> ByteString -> Bool`
## Governance and algorithm
Cryptographic verification uses constant-time validation primitives where provided by `crypton`.
Malformed keys and invalid length signatures answer `False` rather than raising runtime exceptions.
Parameters are named cleanly without shadowing Prelude identifiers (`pubExp` / `modulus`).
## Grill Log
- **Q:** Shadow Prelude's `exponent` identifier in parameter bindings? **A:** No. _Rationale:_ Violates `-Wall -Werror` compiler cleanliness. Name public exponent `pubExp`.
- **Q:** Throw on malformed keys during verification? **A:** No. _Rationale:_ Keys come from untrusted input (e.g. JWT tokens); refusal is a boolean decision, not a process panic.
## Referenced by
[[src/Pudu/Eval/_MOC]] · [[Std Crypto]]
