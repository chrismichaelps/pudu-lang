---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Check/Static.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/pudu]]"
depth_score: 0.3
depth_status: SHALLOW
coupling: 3.0
interface_stability: 0.9
tags: [module, shallow, semantics, native, performance]
aliases: [Type Check Static]
---

# Type Check Static

## Purpose

Refuse a constructor argument of a `@static_function` sum type unless the argument names a module-level function. A value of such a type holds functions whose result may be reused while their arguments are unchanged, so each function must read nothing but what the arguments carry. The rule is the checker half of [[Native Render Skipping]] part 2; [[Std Mobile Memo]] is its first consumer.

`checkStaticArguments` runs from the general call path of [[Type Check Expression]] once the call's type is known. It reads the call's result type, zonked, and when that type is a nominal type declared `@static_function` and the callee's last label is one of that type's constructors, it checks each argument.

## Interface

```haskell
checkStaticArguments :: DeclaredTypes -> Located Expression -> Type -> [Located Expression] -> Checker ()
```

The arguments are the callee, the call's result type, and the argument expressions. Diagnostics are reported through [[Type Env]].

### Governance

- **Refused: `E3103`, at the argument.** An argument is accepted only when its expression is a name, or a member access ending in a name, whose first segment is not a local binding. A name that resolves to a module-level function, or to one reached through an import, is accepted.
- **Refused: a lambda.** A lambda can read values that never reach its arguments.
- **Refused: a local binding, even one holding a module-level function.** The checker cannot see through a binding what it was given, so refusing every local keeps the rule exact.
- **Keyed by nominal identity.** The set of static types is keyed by the declaration's identity, so an import alias or a qualified spelling does not hide the type from the rule.
- **Only constructors of the static type are checked.** A function value passed to any other type or to an ordinary function is outside this rule.

Resolved Grill Log:

- **Q:** Why refuse a local that holds a module-level function? **A:** The checker cannot see through a binding what it was given; refusing every local keeps the rule exact. _Rejected:_ following a local to its initializer, which would need the checker to prove what the binding holds in every path.
- **Q:** Why an attribute on a type rather than on a parameter? **A:** Attributes annotate type declarations, and a type's identity survives any import alias, so the rule cannot be bypassed by renaming. _Rejected:_ a parameter attribute, which would bind the rule to a function signature that a caller can route around through another constructor.

## Invariants

- A constructor of a `@static_function` type is checked on every call that the general call path types, whatever the import alias used to reach it.
- Each refused argument reports once, at that argument's span.
- A type without the attribute is never checked by this module.

## Negative Logic

- No inference of purity. The rule does not prove that a named module-level function is pure; it proves only that the name carries no captured value. Effects are the business of [[Type Check Safety]].
- No check of the value a call produces. The rule runs on the arguments of the constructor, not on the view or result the memo later builds.
- No runtime check. A program that passes this rule runs with no extra cost.

## Dependencies and consumers

Depends on [[Type Env]] for `DeclaredTypes`, the local-binding lookup and the diagnostic report, and on [[Type Unify]] for zonking the result type. Declared static types are recorded by [[Type Formation]]. Called from [[Type Check Expression]]. Its refusal fixtures are [[Memo Render Lambda]] and [[Memo Render Local]], asserted in [[Pudu Compiler Program Eval Data Spec]]. The consumer that depends on the rule is [[Std Mobile Memo]].

## Resolved Grill Log

- **Q:** Why refuse a local that holds a module-level function? **A:** The checker cannot see through a binding what it was given; refusing every local keeps the rule exact.
- **Q:** Why an attribute on a type rather than on a parameter? **A:** Attributes annotate type declarations, and a type's identity survives any import alias, so the rule cannot be bypassed by renaming.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Native Render Skipping]] · [[Std Mobile Memo]] · [[Memo Render Lambda]] · [[Memo Render Local]]
