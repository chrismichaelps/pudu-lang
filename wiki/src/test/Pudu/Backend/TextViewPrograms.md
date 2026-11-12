---
type: module
path: "@root/test/Pudu/Backend/TextViewPrograms.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Text View Programs]
---
# Backend Text View Programs

Export textViewSuccessPrograms, textViewRefusalPrograms and textViewFacadePrograms. Independent expected
outputs cover all six primitives over mixed-width UTF-8, every nearby byte
position, empty text/needles, overlapping searches, embedded NUL, reversed and
extreme offsets, and deferred positive Int boundaries. Verify UInt8 arithmetic,
(Char, width) tuples and shared slices surviving their source and parent.

## Resolved Grill Log
Direct, aliased and captured calls share exact semantics, tag identity and entry
rendering. Pin operand effects/snapshots, early transfers and runtime failures.
Use ordinary native differential/module/counted-cleanup registries, with dedicated
focused labels. New cases supplement existing corpora; matching two implementations
alone does not replace the independent answers. Public facade execution may depend
on the imported-default integration in #824; do not hide such a dependency.

## Referenced by
[[Backend Native Tests]] · [[Backend Text Leak Tests]] · [[Backend Module Programs]] · [[Native Text Views]]

Bind deferred positive magnitudes without a contextual literal target, settle them through the existing negative-Int binding, and relay through an ordinary function parameter. This preserves the checker's accepted deferred-value form while exercising the actual out-of-range magnitude in byte kernels; do not change literal typing to make a fixture pass.

Computed builtin callees print before both supplied operands. The operands then
run left to right, and the byte read uses the text held before the index
expression mutates the source binding. This fixture covers ordinary callable
preparation under [[Callee First Call Evaluation]].

Facade cases use whole-program module conformance, exercising Std.StringView byte units, shared substrings, checked mutable copy and byte searches. They join complete module tests and a focused integration property; only library-free kernel cases enter the single-module counted harness.
