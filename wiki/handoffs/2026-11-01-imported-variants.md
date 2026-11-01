---
type: handoff
status: ACTIVE
aliases: [Imported Variant Delivery]
tags: [handoff, resolution, nominal]
---
# Imported Variant Delivery

Issue #775 owns feature/775-imported-variant-candidates, fresh from fetched dev
e93cf5527 with tested #774 prerequisite da26fddb explicitly integrated. Preserve
all other worktrees. Architect → Semantic Engineer: resolve export-candidate
propagation before implementation. No delegated agents. Independent review is
waived for this engine loop; focused/full gates and wiki parity still apply.

Ownership: Semantic.Interface, Resolve/State/Context/Canonical, Resolve facade,
new Resolve.Ambiguity, package registration, VariantNamespaceSpec, the loaded
sum-owner gate, and their complete mirrors/navigation. No runtime or type-scheme
change. Keep every source below 500 lines and the delivery below 600 changed lines.

## Resolved Grill Log

The verified producer exports First.Chosen and Second.Chosen. A selected import
silently chooses by declaration order. Preserve an owner-indexed variant pool
alongside ModuleExports' existing unique export projection; exportsOf and editor
completion remain one surface entry per namespace/name. Only exported sums enter
the pool. Group by label then declaring type, so same-owner duplicates remain
E2001 in the producer rather than becoming a new cross-owner ambiguity.

ImportBinding carries ambiguous variant suffixes, their declaration spans and
an explicit export-index type-head fact. A selected value binding uses an empty suffix; a module qualifier uses
one label segment. Type bindings and opaque recovery imports carry none. The
resolver stores this map by the actual introduced SymbolId, preserving nearest
lexical shadows. No constructor role is inferred from a scheme or runtime value.

Resolve.Ambiguity owns candidate registration, lookup and E2012 construction for
local and imported variants. Move the existing local refusal there to keep
Context below 500 lines. Its narrow direct state responsibility is the candidate
registry and diagnostic append; Context retains scope/symbol introduction and
sorted product publication. Both use the same pure invocation-owned State.

Ordinary single-name resolution keeps its existing single lexical lookup. The
selected symbol is passed into ambiguity checking. Import candidate metadata is
read only for ImportOrigin. Qualified paths may inspect the selected qualifier
and nonempty suffix; they never re-report an empty-suffix refusal. Type-qualified
paths such as C.First.Chosen remain valid, while C.Chosen reports all candidates.
An ambiguous imported alias yields to a known TypeSpace head during qualification,
matching local aliases; an actual ordinary value retains precedence.

Canonical preserves the generated-provenance skip boundary. Type paths never
receive value ambiguity checks. Member walking checks a directly named qualifier
plus member once; nested member targets retain their ordinary recursive walk.
Do not manufacture a second E2012 for the same reference or alter authored head
reference spans. Diagnostics point to the offending value selection and attach
all original declaration spans, independent of declaration/import order.

Required evidence: exact E2012 use/related spans for selected and module-alias
imports, unit/positional/named variants in both declaration orders, legitimate
lexical shadows, genuine duplicate/private/missing import controls, qualified
successful construction and retained/folded forms across both evaluators and
off/cold/warm products. Existing LSP import surface and generated derives remain
covered. Re-run focused and clean full optimized gates before delivery.

Verification Engineer: optimized build, positioned variant properties and the
loaded owner gate pass. The type-head collision control includes selected First
and C.First qualification, bare refusal and ambiguous value-field refusal. Both
evaluators retain qualified/retained/folded owners across off/cold/warm products.
The clean full optimized gate is running; no source changes follow its start.
Foreign related-span CLI coordinates are separately reported as #777; structured
source offsets are exact and retained here. Do not claim renderer repair.

Exact next action: observe the existing full-gate process to completion, publish
the bounded #775 PR after it passes, and merge #776 after hosted checks are green.
Then resolve #777's foreign-source rendering contract before engine continuation.

## Referenced by

[[handoffs/_MOC]] · [[Semantic Interface]] · [[Resolve Ambiguity]] · [[Resolve Context]] · [[Resolve State]] · [[Resolve Canonical]] · [[Name Resolution]] · [[Variant Namespace Properties]] · [[Sum Owner Gate]]

Type-head control: an exported type may share an ambiguous variant label.
Import candidate entries retain an explicit type-qualifier flag from the export
namespace index. Value selection still refuses the bare label; qualification
through that actual type is admitted. PathUse distinguishes value and qualifier
contexts. Flatten only syntactically named member targets, preserving the original
head reference span; computed targets retain recursive evaluation resolution.
Resolved Grill Log: C.First.Chosen must not reject the known First type when
First is also an ambiguous variant. Do not infer type qualification from spelling
alone, nor admit C.Held.value when Held has no exported TypeSpace binding.
