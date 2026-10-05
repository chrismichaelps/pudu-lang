---
type: module
path: "@root/test-fixtures/derive/StdJson.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive StdJson Fixture

## Purpose and contract

Derive Json.Encode and Json.Decode for records with @json, @skip and @default, a sum with a renamed variant, a generic page and a recursive tree. Assert encoding, round trips, unknown-key tolerance, located type mismatches, missing and repeated keys, and unknown variants.

## Grill Log

- **Q:** Decode a missing Option field? **A:** Yes, as None: a missing field reads null unless it has a default.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
