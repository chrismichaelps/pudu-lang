---
type: module
path: "@root/test-fixtures/stdlib/UsesCryptoAll.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, crypto]
aliases: [Uses Crypto All]
---

# Uses Crypto All

## Purpose and interface

Executable Pudu fixture for every export of `Std.Crypto`. Its `main` returns 59 held assertions.

Digests: SHA-256 and SHA-1 written in Pudu against their published vectors and against the runtime's
digests; SHA-512; SHA3-256 and SHA3-512 of empty input, `abc`, and a million bytes; and BLAKE2b at 256 and
512 bits of the same inputs. Every value was taken from an independent implementation, never from this
library.

Keyed digests and keys: HMAC-SHA256; HMAC-SHA512 against RFC 4231 with a short key, a text key, and a key
longer than a block; password derivation; constant-time equality for equal, last-byte-different,
different-length, and empty inputs; and fresh keys and nonces of the required lengths that differ from each
other.

Sealing: messages sealed and opened, a changed byte, wrong key, wrong nonce, and mismatched associated data
refused alike, wrong-length keys and nonces refused, an empty payload sealed with a tag, and a message
sealed with freshly drawn key material.

## Grill Log

- **Q:** Take expected digests from the library under test? **A:** No. _Rationale:_ a value computed by
  the code being checked cannot catch its mistakes. _Rejected:_ self-derived vectors.

## Referenced by

[[Std Crypto]] · [[Runtime Evaluation Spec]]
