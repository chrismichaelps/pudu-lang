---
type: handoff
status: ACTIVE
aliases: [Implementation Witness Delivery]
tags: [handoff, traits, runtime]
---
# Implementation Witness Delivery

Issue #735 remains open until bounded receiver calls preserve implementation
parameters for nonempty, empty and nested receivers through two generic levels
in both evaluators. No element inspection or blind argument zipping is acceptable.
Independent review is waived for this engine loop; no delegated agents.

Fresh feature/735-implementation-head-evidence starts at fetched dev 308130087.
The fully locally tested #734 prerequisite d711a83f is explicitly integrated;
PR #780 hosted checks must pass before merge. Do not publish this dependent
partition until the prerequisite lands and its diff is independently bounded.

Architect → Semantic Engineer owns Type.Value, Env, Check.Method,
Compiler.Literals, LiteralsSpec and their matching mirrors/navigation only.
This first partition retains complete checked implementation heads. It does not
claim that current receiver dispatch reifies implementation parameters.

## Resolved Grill Log

Canonical receiver identity alone loses nested/reordered generic target shape.
Add ImplementationOwner Type separately from concrete/variant owner facts. Form
with implementation rigids; expand transparent aliases before executable
projection. Use the structural Impl target boundary, never generic TypeSyntax
walking or the static-selection map. Existing record/pattern/member consumers
ignore implementation-only facts. No runtime representation changes in this
partition. Prove the semantic delta in the compiled tree and unchanged source
syntax; preserve all static-owner/derive behavior before runtime integration.

Next partition will carry the complete caller receiver witness with selected
provider evidence, structurally match it against this checked implementation
head, then bind implementation parameters, complete Self and method parameters
in their own declaration order. Immediate and retained methods, empty/nested
receivers, aliases and reordered heads must agree in both evaluators and cached
products. Do not fall back to global installation order after selected evidence.

Verification Engineer: the original alias-shape property failed with
Pair[A,Array[B]] before repair. The repaired property passes nested aliases,
function/reference/tuple arguments, higher-kinded applications, dynamic traits,
capability wrappers and Never while preserving authored heads and target spans.
Static-selection properties also pass. The clean full gate is running as
process session 42111, with log /tmp/pudu-735-head-full-gates.log.
Exact next action: observe that same live gate without restarting; require
#780 hosted checks, merge its final tested commit, then publish this bounded
prerequisite with Refs #735 after its full gate passes. Runtime repair follows.

## Referenced by

[[handoffs/_MOC]] · [[Type Value]] · [[Type Env]] · [[Type Check Method]] · [[Compiler Literals]] · [[Compiler Literals Spec]]
