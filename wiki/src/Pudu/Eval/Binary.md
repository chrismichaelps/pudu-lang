---
type: module
path: "@root/src/Pudu/Eval/Binary.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, runtime, performance, serialization]
aliases: [Eval Binary]
---

# Eval Binary

## Purpose, interface and invariants

The native codec for the planned `Std.Binary` facade. `binaryEncode(node)` writes a `Std.Binary.Node` tree;
`binaryDecode(bytes)` answers `Ok(node)` or `Err(message)`. The wire form is a 32-bit count of
distinct names and each name as a 32-bit length and UTF-8, in first-use order, then the root
node. Every node is one tag byte and its body:

| Tag | Node | Body |
| --- | --- | --- |
| 0 | `Whole` | eight bytes, two's complement |
| 1 | `Real` | eight bytes of the bit pattern |
| 2 | `Flag` | one byte, `0` or `1` |
| 3 | `Text` | 32-bit length and UTF-8 |
| 4 | `Raw` | 32-bit length and the bytes |
| 5 | `Reals` | 32-bit count and eight bytes per value |
| 6 | `Items` | 32-bit count and the nodes |
| 7 | `Absent` | nothing |
| 8 | `Present` | the node |
| 9 | `Fields`/`Record` | 32-bit count, then a name index and node per field |
| 10 | `Choice`/`Picked` | the variant's name index, then fields as above |

All fixed widths are little-endian. Reading checks every length against the bytes left before
copying, refuses an unknown tag, a name index past the table, a field repeated in one record, a
flag above 1, non-UTF-8 text, nesting deeper than 512 and bytes after the root node. Records
decode as `Record(Map[Str, Node])` and variants as `Picked(name, map)`, so a derive looks fields
up by name; `encode` also accepts those forms so decoded values can be written again; map key order may change field/name-table ordering.

## Grill Log

- **Q:** Import a fold already supplied by the locked Prelude? **A:** No; redundant imports are
  rejected by the warning-free build. Keep only `toList` in the explicit Foldable import.

- **Q:** Encode each field from Pudu? **A:** No; interpreted byte operations cost 7-25
  microseconds each, which made a derived binary archive slower than JSON. The derive builds
  constructors and one native pass writes them, the split that makes JSON fast.
- **Q:** Tag fields with a hash of their name? **A:** No; reading would hash every field name in
  Pudu and two names could collide. The name table writes each name once and indices are exact.
- **Q:** Leave nesting unbounded? **A:** No; hostile bytes would exhaust the stack. 512 levels is
  far beyond any data shape and keeps decoding total.

Native validation: [[Binary Codec Properties]].

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Binary Codec Properties]] · [[Pudu Cabal Manifest]]
