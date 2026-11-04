---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Check/Qualified.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, semantics, nominal]
aliases: [Type Check Qualified]
---
# Type Check Qualified

Resolve a type-qualified method scheme once for immediate calls and retained concrete methods.
`qualifiedScheme` returns the canonical owner and uninstantiated scheme, or Nothing; callers
instantiate through the existing rule. `concreteOwner` recognizes a complete name/member chain
only when declaredNames resolves it to a non-trait owner. Ordinary local-head admission remains
with callers. No expression evaluation, source loading or new type formation.

Preserve module-export priority and existing single-name trait/builtin ambiguity rules. Extend
multi-segment selection only to declared concrete owners. Shared provider ambiguity emits one
E3013 and a poisoned scheme; a missing method returns Nothing to the existing namespace refusal.
Record the canonical concrete owner at a successful method-expression span for executable lowering.
This scheme branch does not rewrite traits; admitted receiver-taking trait calls publish their qualifier through Call. No method is chosen from a basename or import order.

Resolved Grill Log: share scheme lookup rather than duplicate callee and retained-method rules.
Keep instantiation in Rule to avoid a phase cycle. Qualified concrete paths require a declaration;
capitalization or a dotted spelling alone proves nothing. Keep trait qualification on its existing
path because its receiver dispatch differs from a concrete static owner.

Requires [[Type Env]], [[Type Value]], [[Syntax Tree]]; consumed by [[Type Check Call]] and
[[Type Check Rule]]. See [[Qualified Record Method Delivery]].

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check Call]] · [[Type Check Rule]]

Resolved Grill Log: a qualified path that already names an exported value is an ordinary
receiver, even if a type has that spelling. Check the complete dotted value binding before
concrete-owner admission; preserve existing single-name handling of shared interface frames.

## Qualified imported trait calls (#734)

Admitted trait callees retain their canonical trait qualifier as an owner fact at
the original callee span, only after successful self-taking trait selection.
Reuse existing member-head lowering so evaluation never reads an alias namespace
for the qualifier. The receiver and remaining arguments still check once.
Qualified authored trait paths resolve through the exact consumer-visible name
map and yield to complete dotted value bindings; preserve legacy single-name and
generated paths. Env retains that forward map beside its lazy preferred spelling
map. Never resolve authored aliases from graph-wide hidden names.
Resolved Grill Log: unused-import admission alone exposed E7001 at A; canonical
trait selection must survive into executable syntax without runtime alias guesses.
See [[Imported Provider Delivery]].
