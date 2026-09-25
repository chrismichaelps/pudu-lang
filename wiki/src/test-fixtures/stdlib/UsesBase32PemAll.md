---
type: module
path: "@root/test-fixtures/stdlib/UsesBase32PemAll.pudu"
fidelity: Active
domain: "[[Testing]]"
subsystem: "[[architecture/DELIVERY]]"
tags: [module, fixture, stdlib, encoding]
aliases: [Uses Base32 Pem All]
---

# Uses Base32 Pem All

## Purpose and interface

Executable fixture for [[Std Base32]] and [[Std Pem]]. Its `main` returns 30 held assertions reaching
every export: the RFC 4648 vectors in both alphabets, unpadded output, round trips of arbitrary
bytes, Crockford's grouping and forgiven letters, each Base32 refusal; PEM wrapping at 64 columns,
a round trip, a refused label, a bundle with comments read in order and selected by label, and each
PEM refusal including an encrypted legacy header.

## Grill Log

- **Q:** Source of vectors? **A:** RFC 4648 section 10, and reference encodings computed outside
  this implementation.

## Referenced by

[[Std Base32]] · [[Std Pem]] · [[Runtime Evaluation Spec]]
