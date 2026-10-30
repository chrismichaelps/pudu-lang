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
with callers. No expression evaluation, import lookup, new type formation or value fallback.

Preserve module-export priority and existing single-name trait/builtin ambiguity rules. Extend
multi-segment selection only to declared concrete owners. Shared provider ambiguity emits one
E3013 and a poisoned scheme; a missing method returns Nothing to the existing namespace refusal.
Record the canonical concrete owner at a successful method-expression span for executable lowering.
Traits do not receive that rewrite. No method is chosen from a basename or import order.

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
