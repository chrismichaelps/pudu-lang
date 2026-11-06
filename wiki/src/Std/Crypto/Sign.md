---
type: module
path: "@root/lib/Std/Crypto/Sign.pudu"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, crypto, signatures]
aliases: [Std Crypto Sign]
---

# Std Crypto Sign

## Purpose and interface

Ed25519 signatures and the text forms they are stored in. `generate` makes a `KeyPair` from the
secure random source; `fromSeed` rebuilds one; `sign` and `verify` work over bytes; `keyId` names a
public key; `encodeSecret`/`decodeSecret`, `encodePublic`/`decodePublic` and
`encodeSignature`/`decodeSignature` read and write key and signature files.

## Semantics

- A secret file is `pudu-secret-key v1` then the base64 seed; a signature file is
  `pudu-signature v1`, `key <id>`, then the base64 signature. Each is newline-separated with an
  optional trailing newline, and any other shape is `Malformed`.
- `keyId` is the first eight bytes of the public key's SHA-256 in hexadecimal: enough to tell keys
  apart in a file, never used as proof.
- `verify` answers `false` for a key or signature of the wrong length.

## Grill Log

- **Q:** Why name the key in the signature file? **A:** An application that rotates its update key
  embeds both public keys for a while; the id says which to try first and makes a mismatch an
  explainable error rather than a bare `false`.

## Dependencies and consumers

Uses the prelude `ed25519*` builtins ([[Eval Sign]]), `secureRandomBytes`, `sha256Of` and
[[Std Bytes]]. Consumed by [[Std Desktop Update]] and [[Std Desktop Cli]].

## Referenced by

[[src/Std/_MOC]] · [[architecture/DESKTOP-WEBVIEW]]
