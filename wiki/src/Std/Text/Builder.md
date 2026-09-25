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

## Builder and view decision

This is already the needed `StringBuilder` role: callers append persistent fragments and materialize
once. A second builder name or mutable façade would duplicate the contract without improving the
current representation. A distinct `StringView` is not added: `Str.drop`, `take`, and `slice` retain
shared native text storage, and parsers that advance an unread remainder already get view semantics;
byte-coordinate consumers use [[Std Source Buffer]]. A public view would additionally need retention
and scalar-versus-byte indexing rules but has no demonstrated caller that these two surfaces cannot
serve. The decision must be revisited only with a measured workload and an ownership contract, not
as speculative API breadth.

## Grill Log

- **Q:** Concatenate the whole prefix while appending? **A:** No; retain chunks and allocate the
  final text at `finish`, keeping the materialization point explicit.
- **Q:** Count bytes as characters? **A:** No; this builder exposes neither ambiguous length.
- **Q:** Add `StringBuilder` and `StringView` names beside the existing APIs? **A:** No. The builder
  role already exists, and shared `Str` remainders plus the byte-indexed source buffer cover the two
  view use cases observed in the compiler and standard library. _Rejected:_ alias-only API growth;
  an unmeasured view with unspecified backing-storage retention.

## Referenced by

[[src/Std/_MOC]] · [[architecture/STDLIB]] · [[architecture/FFI-SELF-HOSTING]]
