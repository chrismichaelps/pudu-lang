---
type: module
path: "@root/test-fixtures/derive/StdOrder.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive StdOrder Fixture

## Purpose and contract

Derive Eq, Hash and Ord for a record, a generic record, a sum with every payload shape and a recursive sum. Assert equality, hash agreement for equal values, declaration-order ordering, variant order before payload order, and a prefix ordering before a longer array.

## Grill Log

- **Q:** Prove recursion through a container? **A:** Yes; Tree holds Array[Tree], so its own generated head must discharge its field bound.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
