---
type: decision
status: Accepted
date: 2026-10-17
review_date: 2027-01-17
tags: [decision, semantics, control-flow, conformance]
aliases: [ADR-0025, If Without Else Unit Results]
---

# ADR-0025 — If without else yields unit

## Context

Ordinary inference assigns unit to an if without else. Existing if-let evaluation
also yields unit on both normal paths. Ordinary tree evaluation, compiled bodies,
and boxed loop regions instead expose the taken block's trailing value. Derive
residualization additionally replaces a literal-true conditional with that block.
A contextual checker path pushes dynamic expectations into the taken block even
without else. Together these allow a checked unit to carry an Int, text, Result,
or another runtime value, depending on execution path and condition.

This is an implementation conformance defect in a statically typed language.
No accepted contract gives an ordinary unit-typed conditional a dynamic payload.
Native emission must agree with the repaired non-native paths before its temporary
refusal for such values is removed.

## Decision

An ordinary if without else evaluates its Boolean condition exactly once. False
produces unit without running the block. True runs the complete block and then
produces unit only after normal completion. The block's trailing value is discarded
with the ordinary discarded-value ownership and cleanup rules. A diagnostic or
return/break/continue unwind never becomes unit; all existing effects, source
provenance, lexical scope cleanup, and transfer destinations are preserved.

An if with else retains its selected branch value and existing branch unification.
No syntax, AST constructor, diagnostic code, or Result propagation rule is added.
A Result computed as a normal trailing branch value is discarded as a value;
this does not propagate its Err or catch a runtime diagnostic.

Contextual checking first establishes the no-else expression's unit result.
Dynamic widening, including expectations inside aggregates, checks that resulting
unit against the expectation. It must not widen the discarded then value or type
an absent alternative as an arbitrary expected result. With-else bidirectional
checking remains unchanged. Condition or branch transfers retain their existing
Never/control-flow behavior; no new divergence inference is introduced.

Tree evaluation, compiled bodies, and boxed loop regions implement the same
normal-result discard. Derive residualization must preserve it when the condition
folds true: retaining the conditional is valid; replacing it with an ordinary
value block is not. Constant folding uses the same evaluator semantics.
Statement block inlining may flatten already discarded statements, but may not
promote a discarded result into a containing value.

Native lowering may represent no-else values with the existing unit Core block
containing CoreIf. Broaden admission only after non-native agreement; the supported
branch's normal value is evaluated and discarded regardless of its scalar type.
Unsupported branch syntax and ownership representations retain their own explicit
refusals. This decision does not claim complete native coverage.

## Compatibility and migration

`if true { 7 }` and `if false { 7 }` both produce unit. Before repair, the first
incorrectly produced 7 on affected evaluator paths. A program needing a scalar
value writes both alternatives, for example `if ready { 7 } else { 0 }`.
A program relying on an accidental leaked Result or dynamic payload must likewise
provide an explicit else with a compatible result or move that value outside the
conditional. Effects inside the block still run in their original order.

The semantic version advances from 1.0.0-draft to 1.0.1-draft under the clarification
policy. This records an observable implementation correction, not a newly chosen
meaning for conforming source. Compiler package release numbering remains owned
by release delivery. No existing diagnostic code changes meaning; dynamic-context
programs that relied on discarded-value widening may now receive the existing
unit/type or trait-admission diagnostic at the conditional.

## Ownership and evidence

Runtime ownership covers Eval.hs, Eval/Compile.hs, and Eval/Loop/Kernel.hs. Derive
ownership covers Derive/Record.hs. Semantic ownership covers Type/Check/Statement.hs.
Backend ownership covers Compiler/Lower/Body.hs and affected native admission tests.
Each owner updates the complete mirrored module page and resolved Grill Log before
source edits; owners preserve each other's work. Tests own an independent regression
family and existing backend and derive corpora. Implementation review is independent
of authorship.

Required evidence covers both conditions; scalar/text/Result branch results;
binding, assignment, return, call argument, aggregate, nested conditional and break
contexts; ordered effects; return/break/continue and diagnostic preservation;
with-else and if-let regression; constant folding; dynamic expectations; derive
true/false residualization; tree and compiled modes; actual boxed-kernel admission;
and native stdout/stderr/status parity where represented. Tests must assert unit
against an independent expected value, not only agreement between buggy paths.
Clean focused and full gates plus independent implementation, architecture and
wiki review are required. GHC 9.14.1 evidence remains outstanding until run.

## Grill Log

- **Q:** Preserve the leaked value for compatibility? **A:** No. It contradicts the expression's unit type and the established if-let contract. Rejected: undocumented condition-dependent payloads.
- **Q:** Can native lowering alone discard it? **A:** No. Repair and verify all admitted execution and transformation paths first. Rejected: a native-specific meaning.
- **Q:** Can a catch turn a transfer or diagnostic into unit? **A:** No. Discard only normal successful results through existing sequencing. Rejected: catching control flow at the conditional.
- **Q:** May a literal-true fold expose the block value? **A:** Only when an else exists. Without else the fold must preserve normal unit production. Rejected: unconditional block replacement.
- **Q:** Can a dynamic expectation choose the branch payload? **A:** No. Check the conditional's unit result against it. Rejected: bypassing the absent alternative through contextual checking.

## Referenced by

[[decisions/_MOC]] · [[architecture/_MOC]] · [[grammar/pudu]] ·
[[architecture/SEMANTICS]] · [[Native Emission Coverage]] · [[Native C11 Backend Delivery]]
