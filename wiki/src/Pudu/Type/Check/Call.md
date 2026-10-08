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

`traitQualifiedCall` dispatches on the first argument only when the qualifier is a trait and the member takes `self`. `Point.read(text)` names its owner; it is never answered by the impl for `text`'s type.

## Interface

```haskell
newtype CheckExpression = CheckExpression
  { runCheck :: DeclaredTypes -> [(Text, Int)] -> Located Expression -> Checker Type }

checkCallee        :: CheckExpression -> DeclaredTypes -> [(Text, Int)] -> Located Expression -> Checker Type
traitQualifiedCall :: CheckExpression -> DeclaredTypes -> [(Text, Int)]
                   -> Located Expression -> [Located Expression] -> Checker (Maybe (Type, [Type]))
selectedStaticCallee :: DeclaredTypes -> [(Text, Int)] -> Span -> Expression -> [Type]
                     -> Checker (Maybe Type)
checkCalleeLending :: CheckExpression -> DeclaredTypes -> [(Text, Int)]
                   -> Located Expression -> Checker (Type, Maybe (Located Expression))
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
- `Q.member` where `Q` is a module qualifier that exports `member` is that export, even when a type
  of `Q`'s spelling is also declared: `Json.encode` is the module's function whether or not the
  `Json` type implements `Encode`. Only when the module exports no such value is `Q` read as a type.
- Ambiguity between two traits providing one member is reported at the call rather than at the
  declaration: declaring both is legal, and only an unqualified call has to choose.
- An instantiated method unifies self with its actual receiver through
  [[Type Check Receiver]] before removing that bound parameter. Generic owner and
  field types cannot be inferred independently from later arguments or results.

### The capability

A call's arguments are expressions and an expression may be a call, so one direction has to be an
argument rather than an import. `CheckExpression` is that direction — the same shape
[[Parser Expression Control]] uses for the same reason.

- **A variant that named its payload is refused before the callee is resolved**, and answered here rather than left to fall through. Falling through re-checks the same member as an expression, which reports one mistake twice; short-circuiting is also what reaches an imported variant, whose qualified name resolves before qualified member typing is ever consulted.

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

## Grill Log

- **Q:** Keep receiver dispatch for type qualifiers? **A:** No; it typed `P.read("x")` with `Str`'s impl whenever one existed.
- **Q:** Let a type's static method take `Q.member` from a module qualifier of the same spelling?
  **A:** No. _Rationale:_ a whole-module import's qualifier is how its values are written, and a
  type sharing the module's last segment (`Std.Json.Json`) is ordinary. _Rejected:_ forbidding impls
  on such types; requiring the module to be imported under another alias.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[grammar/pudu]]

## Places

`checkCalleeLending` answers the callee type and, when the method takes `self: &mut Self`, the receiver, which [[Check Place]] requires to be writable; `checkCallee` is its first half. See [[ADR-0022-lending-a-place]].

## Generic qualified evidence

A trait-qualified call on a rigid receiver selects that canonical trait from its
full scoped bounds through Type.Check.Method. Trait parameters and Self specialize
before remaining method-local parameters instantiate. Check the receiver once and
reuse its type when checking the full call. Resolved Grill Log: qualifying a
Holds[Int] receiver as Holds.get must not allow the result to become Bool.

## Static field owner selection (#457)

`selectedStaticCallee` recognizes a member qualified by a complete nominal type application.
Form the owner, resolve its unambiguous method and provider, then match the provider's implementation
head through [[Type Implementation Rules]]. Instantiate implementation parameters in declaration
order from those structural bindings; remaining parameters are inferred normally. Explicit method
arguments follow the selected implementation prefix. Record the complete ordinary static selection.
Resolved Grill Log: preserving `Pair[B, A]` and nested heads requires structural matching, not zipping
owner arguments. Missing or ambiguous selection returns a located diagnostic, never a guessed owner.

The interface graph and local declaration collection can contribute identical implementation facts.
Collapse identical matching rules in one linear pass before deciding uniqueness; keep different
heads, traits, parameters or conditions distinct. Resolved Grill Log: repeated facts do not create
ambiguity, and existing coherence checks still reject duplicate authored implementations.
