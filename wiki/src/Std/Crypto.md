---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Crypto.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, crypto, security]
aliases: [Std Crypto]
---

# Std Crypto

## Purpose and interface

Digests, keyed digests, constant-time comparison, password-derived keys, and authenticated encryption.
SHA-256 and SHA-1 are written in Pudu as readable references (`sha256`, `sha1`) with `digestsMatch` and
`secretsMatch` for their digests and text secrets. The runtime-backed calls are `sha512`, `sha3_256`,
`sha3_512`, `blake2b256`, `blake2b512`, `hmacSha256`, `hmacSha512`, `bytesMatch`, `derive`, `seal`, and
`open`; `keyLength`, `nonceLength`, `newKey`, and `newNonce` state and produce the key material sealing
needs.

## Governance and algorithm

**Readable references beside fast implementations.** The SHA-256 written in Pudu is evidence that the
language's bit work is exact, and the fixtures check it against the runtime's digest. Anything run in a
loop—key derivation, keyed digests, and every other family—uses the runtime's audited implementations,
because the interpreted reference costs milliseconds per digest.

**Families are named, never substituted.** SHA-2, SHA-3, and BLAKE2b are separate calls because a
protocol names the digest it is defined over, and a value computed with a different family is simply a
different value.

**Comparisons that touch secrets take constant time.** `bytesMatch`, `digestsMatch`, and `secretsMatch`
examine every byte whichever way the answer goes, so the time taken says nothing about how much of a
guessed tag or token was right. Only the length may be observed.

**Keys and nonces come from the secure source.** `newKey` and `newNonce` draw from the operating system's
cryptographic randomness, never from `Std.Random`'s deterministic generators, so a program does not have
to choose a source to get one that is safe.

**Sealing refuses silently and uniformly.** `open` answers nothing for a wrong key, a changed byte, a
truncated message, or mismatched associated data alike, because telling them apart tells an attacker
which change got closer.

## Grill Log

- **Q:** Ship BLAKE3 now? **A:** Not yet. _Rationale:_ the runtime's audited library does not provide it,
  and a Pudu implementation cannot be released without checking it against the reference implementation's
  published vectors. _Rejected:_ an unverified implementation. BLAKE2b covers the fast-hash use today.
- **Q:** Offer a generic digest taking an algorithm name? **A:** No. _Rationale:_ a string selecting the
  algorithm moves a protocol choice out of the type a reader sees. _Rejected:_ `digest("sha3-256", …)`.
- **Q:** Let `newNonce` count instead of draw? **A:** No. _Rationale:_ a counter must be persisted and
  never reset, which is a bookkeeping obligation most callers fail silently. _Rejected:_ implicit counters.

Resolved Grill Log: named families, constant-time secret comparison, secure-source key material, uniform
refusal, and BLAKE3 deferred until verifiable.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[First Release Readiness]]
