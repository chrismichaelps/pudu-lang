---
type: architecture
tags: [backend, native, collections]
aliases: [Native Word Map Queries]
---
# Native Word Map Queries

`wordMapIsSubsetOf` and `wordMapIsDisjointFrom` take identical Map[K, UInt64]
values and return Bool. Visit left keys in order; missing right words mean
zero. Stop at the first failed bit predicate, matching [[Runtime Word Kernels]].
`wordMapPopCount` returns UInt128. `wordMapMembers` requires UInt64 keys and
payloads and returns Array[UInt64], in chunk-key then low-set-bit order.
Chunk shifts wrap at 64 bits, so output may contain duplicates and need not
be sorted by the wrapped member ID. Never sort or deduplicate it.

## Resolved Grill Log

- Keep queries in the existing deep [[Compiler Lower Word Map]] and
  [[Native Persistent Trees]] modules, which remain below 500 lines; shared
  signature/snapshot code preserves algebra behavior without another module.
- Typed UInt64 payloads need no runtime projection. Predicates borrow an
  ascending left view and probe the right tree, freeing the view after a
  short circuit. Inputs remain persistent and owned by ordinary map slots.
- Sum word popcounts with the existing two-word add and wide constructor;
  64 times the host entry count fits UInt128 on supported 64-bit hosts.
- Count member capacity with checked size_t increments before allocation;
  use the existing checked array allocator and release node views. Construct
  exact UInt64 cells; ordinary array cleanup owns the result.
- Direct calls and values share exact checked signature admission. Preserve
  eager operand order, Never transfers, builtin identity and failure spans.
- Each typed frame validates operand/result carriers before selecting a C
  helper. Clang/GCC, sanitizer, counted cleanup and differential gates prove
  execution; a successful C compile alone cannot establish parity.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Native Word Map Query Delivery]]
