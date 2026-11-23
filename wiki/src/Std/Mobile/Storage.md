---
type: module
path: "@root/lib/Std/Mobile/Storage.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
subsystem: "[[Standard Library]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, mobile, native, storage]
aliases: [Std Mobile Storage]
---

# Std Mobile Storage

## Purpose and interface

Pure description of key-value storage on the device: a read, a write and a removal. Each request is a commit, like the system requests of [[Std Mobile System]]. The module builds the instructions through [[Std Mobile Stream]] and performs no I/O. A read answers with `Stored(tag, value)` as decoded by [[Std Mobile Events]] into [[Std Mobile View]].

Exports:
- `type Place = Plain | Secure`: where a value is kept. Codes 0 and 1 in that order, read by `placeCode`.
- `placeCode(place: Place) -> UInt32`: the stream code of a place.
- `read(tag: UInt32, place: Place, key: Str) -> Bytes`: a commit asking for the value under `key`. The answer is `Stored(tag, Some(value))`, or `Stored(tag, None)` when nothing is kept.
- `write(place: Place, key: Str, value: Str) -> Bytes`: a commit keeping `value` under `key`, replacing what was there. It reports nothing.
- `remove(place: Place, key: Str) -> Bytes`: a commit removing what is kept under `key`. It reports nothing.

## Behavior

- A read answers after every earlier write and removal in the same stream, because the host applies instructions in stream order on the main thread.
- A value written to `Plain` is kept until the application is removed. A value written to `Secure` is kept on this device only and is left out of backups.
- Removing a key that holds nothing is not a defect. The key simply stays absent.

## Invariants

- Every request carries its place as one code word, so the host never guesses the store.
- `Secure` and `Plain` share one key space per place. The same key in two places names two values.
- Place codes come from `placeCode`, not from an if-ladder at each call.

## Negative Logic

- No cache. The module never remembers what it wrote; the program receives every answer as an event.
- No default value. A missing key answers `None`, and the program decides what that means.
- No secret leaves the device through this module. A `Secure` read answers the value to the program that asked and nothing else; no request sends a secret to a network or a log.
- No platform call. The effects are made by the host in [[pudu-ios-storage]] and [[PuduStore]].

## Dependencies and consumers

Depends on [[Std Mobile Stream]] for the STORE_READ, STORE_WRITE and STORE_REMOVE instructions. Consumers: [[Std Mobile View]], which decodes the `Stored` event; the host [[pudu-ios-storage]] and the Android host [[PuduStore]]; the example [[Vault Example]]; and the fixture [[Uses Mobile Storage]].

## Resolved Grill Log

- **Q:** Why two places rather than one store? **A:** Settings and secrets differ in what must be protected. Settings are kept with the application and may appear in backups. Secrets are encrypted at rest and kept off backups. One store would force every value to the stricter rule or to the looser one. _Rejected:_ one store with a per-key flag, which would let a secret be written to the looser place by mistake.
- **Q:** Why does the answer carry the tag and not the key? **A:** The program matches an answer to the request it sent by its tag, as it does for every system request in [[Std Mobile System]]. The key is the program's own text, so the host has no need to echo it, and a tag keeps the event one fixed-size word of identity.
- **Q:** Why do Secure values never leave the device? **A:** A secret that is copied off the device by a backup or a migration can be read by another device with no key. The platform's protected store is bound to this device, so the module keeps values there and makes no request that moves them. A restored value that cannot be decrypted reads as absent, as [[PuduStore]] describes.

## Referenced by

[[src/Std/_MOC]] · [[Std Mobile System]] · [[Std Mobile Stream]] · [[Std Mobile Events]] · [[Std Mobile View]] · [[pudu-ios-storage]] · [[PuduStore]] · [[NATIVE-MOBILE]]
