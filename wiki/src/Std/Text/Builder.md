---
type: module
path: "@root/lib/Std/Text/Builder.pudu"
fidelity: Active
subsystem: "[[architecture/STDLIB]]"
grammar: "[[grammar/pudu]]"
tags: [module, stdlib, text]
aliases: [Std Text Builder]
---

# Std Text Builder

## Purpose and interface

Accumulate text fragments for code generation and diagnostics without rebuilding the entire prefix
on every append. `empty`, `append`, `appendLine`, `appendAll`, `concat`, `chunkCount`, `isEmpty`, and
`finish` form a persistent chunk builder. `finish` joins once using the existing array text join.
Appending returns a new builder and leaves previous snapshots valid. Empty appended fragments are
omitted; `appendLine` always appends an LF, including for an empty line.

## Algorithm and boundaries

Store `Array[Str]` chunks using the existing persistent sequence. Appending does not concatenate the
accumulated prefix. Finishing allocates the final text; repeated finish calls repeat that work.
Chunk counts are representation counts, not character or byte lengths. No allocation-free claim or
measured speedup is made. The public record may contain empty chunks; `isEmpty` checks their text.

## Dependencies and consumers

Uses array push, concat, and join plus text emptiness. Compiler emitters and diagnostic formatters
can import it explicitly. No IO or foreign primitive is introduced.

## Grill Log

- **Q:** Concatenate the whole prefix while appending? **A:** No; retain chunks and allocate the
  final text at `finish`, keeping the materialization point explicit.
- **Q:** Count bytes as characters? **A:** No; this builder exposes neither ambiguous length.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[architecture/FFI-SELF-HOSTING]]
