---
type: handoff
status: MERGE_AUTHORIZED
issue: 471
aliases: [Qualified Shadow Delivery]
tags: [imports, resolution]
---
# Qualified Shadow Delivery

Language Architect resolved lexical value precedence before readiness. Semantic Engineer owns Type.Env, Type.Check.Rule, Call, Expression and Safety. Runtime Engineer owns Eval.Call and Eval.Call.Path. Test Engineer owns QualifiedShadowSpec and its runner/manifest registrations. Complete mirrors and resolved Grill Logs precede source edits. Work is direct and sequential on fresh feature/471-qualified-shadow from fetched development; preserve the pushed #470 branch and unrelated work. Transitions: Language Architect → Semantic Engineer → Runtime Engineer → Test Engineer → Tooling Engineer. Independent semantic, implementation and vault-parity review remains required.

A whole-module expression qualifier yields to a nearer ordinary local before any export/type/trait lookup. Nested checker frames carry these locals; the final shared module/interface frame does not. A type witness retains static dispatch; annotations, record construction and selected nominal type applications retain independent type lookup. Dotted explicit type arguments on ordinary receivers retain E3028 rather than selecting a shadowed module function. No new syntax is introduced.

Baseline: an Int shadow still calls its imported toTitle function; an Array shadow's length call is typed as the imported function; a record field becomes an unrelated function type. Typing and call dispatch must change together. Existing member reads and prepared-call local guards remain intact. Bare namespace/value repair #470 and block-local import design remain separate.

Acceptance: loaded and isolated successes/refusals, exact diagnostic identity, expected outputs in both evaluator modes, cold/warm/folded/carried/source-only evidence, strict focused/full build gates, formatting/lint/graphs and vault parity. No broader application readiness claim.

The final strict optimized build and both focused families pass. All 605 complete-suite groups pass after strengthening the matrix with actual serialized warm products. The initial controls incorrectly used an index-shaped generic capture and expected a cross-namespace warning; both were corrected to the existing syntax and independent namespace rules. No failing check remains.

Eight direct checks and eight runs prove expected results in both evaluators; invalid run/build refuse the scalar shadow with E3005 and write no executable. Six packaged executions retain outputs 2, 42 and 999 after deleting original sources, including an empty environment and unrelated working directory. Carried execution uses three products; the changed-digest source-only stand-in uses none. This is local packaging evidence, not a different-platform guarantee.

All 243 shipped library/example sources, formatting, command lint and diagnostic consistency pass. API coverage is 3628 of 3987 exports, above the 3598 floor, with no undocumented export. Five application graph regressions pass; 215 modules and 96 dependencies have no findings. The compiler source graph has 282 modules, 31 dependency layers and no missing internal edges or cycles. Owned mirrors now describe the actual shared module frame and current capability ownership. The author completed the local parity audit; independent semantic, implementation and vault-parity reviews remain pending.

Delivery owner integration: the user authorized ordered integration into development using the already passing checks without waiting for refreshed runs. Ownership is limited to retaining both resolution test registrations and their mirrored documentation, handoff and maps. The conflict introduces no new language behavior. Both original property families and manifest entries remain registered. Independent approval is not claimed.

Exact next action: merge the reconciled #473 head into development, then integrate #475. Scoped import syntax remains separate; the broader application goal remains active.

## Referenced by

[[handoffs/_MOC]] · [[architecture/SEMANTICS]] · [[Qualified Shadow Spec]]
