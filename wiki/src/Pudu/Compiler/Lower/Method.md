---
type: module
path: "@root/src/Pudu/Compiler/Lower/Method.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Method]
---
# Compiler Lower Method

## Purpose and interface

Lowers method calls to ordinary Core calls of a method instance, under
[[Native Trait Methods]].

- `methodTables` reads each module's `compileMethods` and builds the instance
  table plus two indexes: `(owner key, member)` for receiver calls and
  `(trait, owner key, member)` for trait-qualified ones.
- `lowerMethodCall` handles `receiver.member(arguments)` and the universal
  `toText()`, or declines so the built-in Str/Char lowering runs.
- `lowerQualifiedMethod` handles `Owner.member(arguments)`.

## Selection

A method checking declared is found by its name span. If the span is an
implementation's own function, the instance runs with no bindings (plus
`Self` when the owner forms). If it is a trait member the implementation
inherits, the instance runs with `Self` bound to the owner. Its key is
`owner.trait.member`, so two traits giving one type the same member stay apart.
Implementations with type parameters are left out; their calls fall through to
the existing refusal.

A receiver call reads the receiver's checked type at its span and files it with
`ownerKeyOf`. Str answers its built-in members and Char its `code` and `toText`
before any implementation, as `readMember` does. When the type has no such
method, `toText()` with no arguments is the receiver's `display` text, the
evaluator's `TextMethodValue`.

The trait-qualified form picks the implementation for the first argument's
type. The type-qualified form matches the written name against the owner's
display name. When several owners share that name, the first argument's type
decides; otherwise exactly one candidate must exist.

## Order

Arguments run first, then the receiver, and the receiver is passed as the first
argument. Each argument is declared into an unnamed temporary inside the call's
block value, so the order survives the receiver going first. If an argument or
the receiver is Never, the operands are evaluated in order and the call is not
made. Qualified calls pass their arguments as written.

## Resolved Grill Log

- **Q:** Why the name span and not the target syntax? **A:** Checking already
  resolved the owner, aliases and imports; the span pins the exact declaration.
  Resolving the target again here would be a second checker.
- **Q:** Can a default body be lowered once for all owners? **A:** No. Its facts
  name the rigid `Self`, so each owner gets its own copy with `Self` bound.
  Rejected: a dynamic dispatch table, which the native subset has no value for.
- **Q:** Must arguments go into temporaries? **A:** Yes. An argument may
  reassign the receiver's variable, and the evaluator reads the receiver after
  the arguments. Rejected: reordering operands in C.
- **Q:** Are two modules' same-named types distinguished? **A:** Here, yes, by
  canonical key, as checking types the call. The evaluator collides on them
  (#550); conformance for that case waits for its fix.
- `&mut self` still refuses at the parameter type, because no place writeback
  exists yet.

## Dependencies and consumers

[[Compiler Lower State]] · [[Compiler Lower Types]] · [[Compiler Lower Signature]] ·
[[Compiler Lower Scalar]] · [[Compiler Lower Control]] · [[Core IR]]

## Generic implementations (#552)

Resolved Grill Log: generic implementations join the tables. An instance with
unbound parameters, or one whose `Self` comes from the call, is specialized at
each call against the receiver's type followed by the callee's bound inputs
(qualified calls use the callee's fact as is).

## Calls from lowering (#554)

Resolved Grill Log: `callInstance` calls a method instance with operands that
are already lowered, as `for` does with `begin` and `advance`.

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Native Trait Methods]]
