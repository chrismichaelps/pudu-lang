---
type: module
path: "@root/test-fixtures/derive/BuildEscape.pudu"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, fixture, derive]
---

# Derive BuildEscape Fixture

## Purpose and contract

A build callback whose failure type mentions its field type, and a collect callback answering a non-Option, are refused at the definition.

## Grill Log

- **Q:** Report at each request? **A:** No; once, at the definition.

## References

[[Derive Library Spec]] · [[Derive Design]] · [[src/_MOC]]
