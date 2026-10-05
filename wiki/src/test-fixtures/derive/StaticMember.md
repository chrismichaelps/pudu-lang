---
type: module
path: "@root/test-fixtures/derive/StaticMember.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive StaticMember Fixture

## Purpose and contract

A static member named through its owner when another impl's owner matches the first argument's type.

## Grill Log

- **Q:** Dispatch on the first argument? **A:** Only for a trait-qualified member taking self.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
