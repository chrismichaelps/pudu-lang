---
type: module
path: "@root/test-fixtures/derive/Builders.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive Builders Fixture

## Purpose and contract

A user derive builds records and sums through Result callbacks, with an early return for an attributed field, ? propagating a lookup failure, and variant builds over unit, positional and named payloads.

## Grill Log

- **Q:** Let ? in a callback leave the enclosing method? **A:** No; it ends the build with that Err, as the callback's own ? would.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
