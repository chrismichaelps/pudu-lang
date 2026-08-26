---
type: module
path: "@root/src/Pudu/Type/Check/Call.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.55
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.8
tags: [module, medium, semantics]
aliases: [Type Check Call]
---

# Type Check Call

## Purpose

Resolve what a call's callee refers to — a method on a value, a method named by its type, or a
method named by the trait that declares it — and give the call the type of the thing it will
actually run.

## Interface

```haskell
newtype CheckExpression = CheckExpression
  { runCheck :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type }

checkCallee        :: CheckExpression -> DeclaredTypes -> [Text] -> Located Expression -> Checker Type
traitQualifiedCall :: CheckExpression -> DeclaredTypes -> [Text]
                   -> Located Expression -> [Located Expression] -> Checker (Maybe (Type, [Type]))
throughBorrow      :: Type -> Checker Type
```

### Governance

- **A trait-qualified call is typed from the implementation it will run**, not from the trait's
  declaration. `Speak.label(&bot)` names the trait, but the method that runs is `Bot`'s, and only
  that one knows the concrete types — a generic trait leaves its parameters open in the declaration
  by design. This is the rule [[Evaluator]] already followed for the same call, so the two phases
  agree rather than only appearing to.
- The receiver is checked **once**, here, and its type handed back, so a call is never walked twice
  and its integer literals never constrained twice.
- A member in callee position prefers a method over a field of the same name, because `value.name()`
  reads as a call and a field would have to be parenthesised to be called anyway.
- A borrow is followed as far as it goes before the receiver's type is read. `&&T` is writable, and
  stopping after one would report a mismatch against a type the reader never intended.
- Ambiguity between two traits providing one member is reported at the call rather than at the
  declaration: declaring both is legal, and only an unqualified call has to choose.

### The capability

A call's arguments are expressions and an expression may be a call, so one direction has to be an
argument rather than an import. `CheckExpression` is that direction — the same shape
[[Parser Expression Control]] uses for the same reason.

### Linkage

- **Requires:** [[Type Env]], [[Type Unify]], [[Type Check Rule]], [[Type Check Method]].
- **Consumed by:** [[Type Check]].

## Algorithm

Dispatch on the callee's shape: a qualified name resolves through the declared names, a member
resolves against the receiver's type after following borrows, and a trait-qualified call resolves
against the receiver's own implementation. Anything else falls through to ordinary expression
checking.

## Negative Logic (Prohibited Paths)

- No importing [[Type Check]]; the capability is the path back.
- No checking a receiver twice.
- No resolving a trait-qualified call from the trait's declaration when an implementation exists.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[grammar/pudu]]
