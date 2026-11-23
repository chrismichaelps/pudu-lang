---
type: module
path: "@root/test-fixtures/stdlib/UsesMobileStorage.pudu"
fidelity: Active
tags: [module, fixture, stdlib, mobile, native, storage]
aliases: [Uses Mobile Storage]
---

# Uses Mobile Storage

## Purpose and interface

Stdlib fixture for storage: the words of its requests in [[Std Mobile Storage]] and [[Std Mobile Stream]], and the answer decoded by [[Std Mobile Events]]. Its entry `main` builds the instruction words for STORE_READ, STORE_WRITE and STORE_REMOVE, decodes the STORED event in its present, absent and unknown forms, and answers the number of checks that held. The data spec `test/Pudu/Compiler/Program/Eval/DataSpec.hs` asserts that count, which is `6`.

Checks, one per `if` of `main`:
1. STORE_READ with tag 4, place Secure and key `k` is 17 bytes; its words are 55, 4, 1 and the key length 1, and its last byte is `k`.
2. STORE_WRITE with place Plain, key `k` and value `vv` is 19 bytes; its words are 56, 0 and 1, and the value length word is 2.
3. STORE_REMOVE with place Secure and key `k` is 13 bytes; its words are 57, 1 and 1.
4. STORED with tag 4, detail 1 and text `x` decodes to `Stored(4, Some("x"))`. `carriesText` and `carriesDetail` are true for kind 31, and the place code of Secure is 1.
5. STORED with tag 4, detail 0 and empty text decodes to `Stored(4, None)`.
6. STORED with detail 2 decodes to `Stopped`.

## Invariants

- Each check compares an exact word or byte sequence, so a wrong code, place, tag or length fails the check.
- The fixture makes no foreign call and starts no host. It runs interpreted and as native C11 code, and both must agree.

## Negative Logic

- No keychain or preferences access. Whether a value is kept across launches is checked by the simulator and device run of [[Vault Example]], not here.
- No refusal is checked here. A place code past 1 is refused by the host in [[pudu-ios-storage]] and [[PuduStore]].

## Dependencies and consumers

Depends on [[Std Mobile Storage]], [[Std Mobile Stream]] and [[Std Mobile Events]], and on the byte reader of `Std.ByteOrder`. Its checks mirror the contract that [[pudu-ios-storage]] and [[PuduStore]] rely on.

## Resolved Grill Log

- **Q:** Why check the bytes of each request rather than only that it runs? **A:** A wrong code or a swapped place keeps the shape of the stream. Only the exact words catch it, as in [[Uses Mobile System]].
- **Q:** Why is an absent value a separate check? **A:** The host answers a missing key with an empty text and detail 0, not with a missing event. The decoder must read that as `None`, not as a refusal.
- **Q:** Why is an unknown detail word left to `Stopped`? **A:** The host writes only 0 and 1 for this answer. A third word would be a host defect, and the decoder reads it as one rather than inventing a meaning.

## Referenced by

[[src/_MOC]] · [[Std Mobile Storage]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Vault Example]] · [[NATIVE-MOBILE]]
