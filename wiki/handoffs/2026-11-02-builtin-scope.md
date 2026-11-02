---
type: handoff
status: ACTIVE
aliases: [Builtin Scope Delivery]
tags: [handoff, types, ark]
---
# Builtin Scope Delivery

The latest project instruction resumes #759. Fresh feature/759-builtin-scope-integration
starts at fetched dev bf8fbaa21. Preserve the original 7679c777 commit and all
uncommitted #758 lights/shadows work in its separate checkout. No stashing,
rebasing or edits to that checkout. Independent review is waived; no delegation.

Architect → Semantic Engineer owns Type.Formation.Builtin, Check.Import,
Interface.Graph, qualified-expression admission in Check.Pattern, InterfaceSpec,
the carrier diagnostic boundary in DataSpec, seven builtinscope fixtures and matching mirrors,
MOCs and changelog. Complete resolved contracts precede implementation. Reapply
the existing focused fix to current code; preserve later changes in every file.

Current failure baseline: Main rejects with E3001/E3001/E3005 and Selected with
E3001/E3005; the refusal retains E3001. Keep exact original output externally.
Acceptance includes both evaluator modes, reversed imports, selected precedence,
positioned refusal and off/cold/warm CLI products, then every clean optimized gate.
Merged provider evidence #787 (0a4627b7c) is integrated before final validation.
Bounded runtime dispatch remains open; the richer simulation roadmap is #786.

The focused property passes in both evaluators. All 24 CLI executions pass
across three valid entry points and a positioned refusal, cache off/cold/warm
with unchanged warm inodes. All seven fixtures pass formatting. Reverse loads
Table before ZGrid under normal formatter sorting, changing actual traversal.
The first clean full run failed the existing carrier diagnostic regression: an
unimported Result.unwrapOr got generic variant help instead of module-import
guidance. A captured suite run identifies the exact mismatch. Qualified built-in
sum misses must defer to ordinary namespace admission; user sum/pattern misses
retain their variant help. The Pattern mirror records this resolved contract
before repair. The unchanged carrier diagnostic property now passes; no full-suite
passing claim is made until clean revalidation completes.
Exact next action: run clean validation on this integrated tree before PR delivery.

## Referenced by

[[handoffs/_MOC]] · [[Type Formation Builtins]] · [[Type Check Import]] · [[Type Interface Graph]] · [[Type Interface Spec]]
