---
type: handoff
tags: [handoff, derive, frontend]
---

# Derive frontend syntax

## Scope and role transitions

Language Architect → Frontend Engineer: implement [[Derive Design]] slice 1 (issue
#430) — attributes, `derives` clauses, `derive` definitions and requests, and
`comptime for` as parse surface with persistence, expansion traversal, and
formatting. Checking, instantiation, and `Std.Meta` are later slices.
Owned responsibility: `Syntax.Tree` nodes, `Parser.Declaration.Derive`,
`Parser.Declaration` dispatch, `Parser.Declaration.Type` attributes and
derives, `Parser.Expression.Control` comptime loop, lambda `where` clauses,
`Parser.State` recovery starts, `Format.Spacing` attribute fixture, expansion
and substitution traversal, stored instances, and every downstream exhaustive
consumer made explicit (resolution, checking, eval, layout, capture, outline,
describe, lint, docs).

## Dependency graph and evidence

New syntax nodes touch every exhaustive consumer; the build names each one, so
the consumer sweep follows the compiler's own errors rather than memory:
`Compiler.Literals` (generic walk instances), `Semantic.Resolve` (name-like
references walked, rigid positions skipped), `Type.Check` (`E3090` on a
surviving loop), `Eval` (`E7001` refusal), `Eval.Compile.Layout` (framed
element), `Eval.Capture` (member/source/body names), `Repl.Outline` and
`Repl.Describe` (surface rendering), `Lint` (member/source/body work),
`Doc` (member entries). Test consumers needed the same treatment
(`ParserModuleSpec` shapes, expression `shape`, `TypeDeclarationSpec`
signature).
`derive`/`derives` stay contextual identifiers (`foreign` precedent); attribute
arguments are inert literals only; the comptime element is a typed binding.
`E1064`–`E1068` diagnose misplaced attributes, bad derives entries,
duplicates, bad attribute arguments, and bad derive shapes, each once.

## Benchmark: derive syntax compile-time cost (uncommitted scratch)

Measured with the slice-1/2 binary (`pudu check`, min of 3, `/tmp/derive-bench.mjs`
plus generated sources under `/tmp/pudu-derive-bench`, nothing committed):

- 2k/4k/8k/16k attributed types with `derives` clauses: 0.02/0.02/0.03/0.05s —
  linear (doubling 8k→16k doubles cost); ~0.01s over stripped equivalents.
- 50/100/200/400 derive definitions with comptime loops: flat ~0.05s — no
  per-block blowup.
- All benchmark sources check with zero diagnostics.

No caching work indicated at these magnitudes; revisit once real derives with
`Std.Meta` measure instantiation itself.

## Exact next action

Slices 1–3 are implemented with edge-case batteries: full suite green at
497 passes. Slice 4 (`Std.Meta` groundwork) is opened as issue #434 with the
module-path seam decided in the vault; entry points identified
(`nameType`/`qualifiedMemberType` + declared-name provenance). Next: ship the
`Std.Meta` surface with the refusal rule and specs, then instantiation.

## Pre-existing notes left untouched

`wiki/src/Pudu/Diagnostic.md` (generated diagnostic provenance) and
`wiki/src/Pudu/Source.md` (generated provenance contract) already carried
uncommitted derive-related vault text before this work began; neither was
written here and neither is staged. They belong to the later
span-provenance slice.

## Referenced by

[[handoffs/_MOC]] · [[Derive Design]] · [[Syntax Tree]]
