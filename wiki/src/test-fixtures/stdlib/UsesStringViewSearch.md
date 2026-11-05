---
type: module
path: "@root/test-fixtures/stdlib/UsesStringViewSearch.pudu"
fidelity: Active
tags: [module, fixture, stdlib]
aliases: [UsesStringViewSearch]
---
# UsesStringViewSearch

## Purpose and interface
UTF-8 code-unit reads and restartable walks, bounded reverse and byte-set searches, lexical order and atomic destination-copy refusal.
The exported main returns four successful groups; a false assertion aborts with its group name.

## Algorithm and invariants
Exercise the actual shipped public modules. Extreme Int inputs must refuse through Option,
without arithmetic diagnostics. Mutating an Array preserves a previously retained view.
Compare layout certificates against independently enumerated positions for all small two-dimensional shapes and strides.
Byte operations use code-unit indices, including continuation bytes; text slicing still validates scalar boundaries.
Invalid copy requests must preserve the complete destination.

## Resolved Grill Log
Use explicit expected values and an independent small layout oracle, rather than repeat the implementation.
Check successful and refused requests in both evaluators. Do not infer resource identity from block coordinates.

## Referenced by
[[Program View Spec]] · [[C++ Inspired View Coverage]]
