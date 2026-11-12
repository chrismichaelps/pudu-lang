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

The receiver is retained before the supplied operands. Direct Core calls
pass the receiver first and evaluate their operands in that order. A Never
receiver stops lowering the call before arguments. An argument that transfers
skips invocation. Qualified calls pass their arguments as written.

## Resolved Grill Log

- **Q:** Why the name span and not the target syntax? **A:** Checking already
  resolved the owner, aliases and imports; the span pins the exact declaration.
  Resolving the target again here would be a second checker.
- **Q:** Can a default body be lowered once for all owners? **A:** No. Its facts
  name the rigid `Self`, so each owner gets its own copy with `Self` bound.
  Rejected: a dynamic dispatch table, which the native subset has no value for.
- **Q:** How does a direct call retain the receiver across argument effects?
  **A:** Its first frame operand owns the receiver value until invocation or
  unwind. A loaned receiver also retains the place and indices for writeback.
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

## Array built-ins first (#556)

Resolved Grill Log: an array answers its built-in methods before any
implementation, as `readArrayMember` does.

## Maps and sets (#561)

Map and set methods answer before any implementation, as `readKeyedMember`
looks there first.

## Bytes (#565)

Byte methods answer before any implementation.

## Dynamic receivers first (#828, #846)

A method of a dynamic value holds its receiver, then its arguments, in locals
before matching on the type the receiver holds, as every other receiver call
runs under [[Callee First Call Evaluation]].

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Body]] · [[Native Trait Methods]]

## Mutable loans (#651)

An instance whose admitted signature has loaned parameters refuses at the
first `&mut` type written in it ("a method with &mut parameters"): a method
call lowers its operands before the instance is chosen, so it holds no place
to write back to. See [[Native Mutable Loans]].

## Method loans (#790)

`instanceTarget` resolves the instance a call reaches (specialized when
open) and admits its signature; `invoke` builds an ordinary call from it.
A receiver call or a qualified call whose instance has loaned parameters is
lowered again from the state before the ordinary attempt, through
[[Compiler Lower Loan]]'s `lowerLoanedOperands`: a receiver call first
retains its receiver, which lends whatever place it names, then its arguments; a
qualified call's operands are arguments in order. Lowering is a pure state
function, so the discarded attempt leaves nothing behind. Only `for`-loop
protocol calls still go straight to `invoke`, whose loans refuse at the
`&mut` type. A bound method value lifts the written call, so a loaned
method held as a value writes back to the copy of the receiver it holds, as
the evaluator's `closureSelf` does. See [[Native Mutable Loans]].

## Selected providers (#798)

A receiver call decodes a provider-selected member and takes the
implementation that provider gives the receiver's type, falling back to the
owner's only method of that name. A qualified call accepts the canonical key
checking writes for its owner, and matches a trait by its last segment.

## Members through a type parameter (#819)

`lowerQualifiedMethod` resolves its qualifier with `boundOwner` before
`lowerOwnerMethod` selects an implementation. A qualifier this copy binds as a
type parameter, as in `T.made()` or `T.scaled(1)`, names the owner key of the
type bound to it, so the copy calls that type's member or the default it
inherits. Any other qualifier stays as written.

Resolved Grill Log:
- *Why at the qualifier and not by reading `T` as a value?* The evaluator
  reaches the member through the copy's type witness, and a generic copy
  already holds every binding. Rewriting the owner before selection reuses the
  type-qualified path, with its argument order, loans and failure spans,
  unchanged.
- *What if a type is declared under the parameter's name?* Inside the generic
  body the parameter shadows it, as it does in checking and in the evaluator,
  so the binding wins.
- *Built-in owners?* `ownerKeyOf` gives `Int` and the other scalars their own
  key, so `impl Sized for Int` is selected like any record's implementation.

## Inherited defaults by their declaring module and trait arguments (#824)

`methodTables` finds each method's declaration in whichever module declares
it, by its span, and lowers it there. A default inherited from an imported
trait therefore resolves its names in the trait's module, as the evaluator runs
it in that module's scope, so a private helper of the trait's module is the one
it calls.

An inherited default's body was checked once with the trait's parameters
rigid. Checked implementation heads supply those trait arguments; matching
the declared and implemented member schemes supplies renamed own parameters.
These become `instanceDerived` bindings in the implementation scheme's
namespace. They are formed after the call's copy settles implementation
parameters and then overlay those parameters for the body. Concrete and
same-spelling arguments follow the same path.

Resolved Grill Log:
- *Why match member schemes as well as read the checked head?* The head supplies
  all trait parameters, including ones absent from a member signature. Scheme
  matching additionally recovers checking's renamed own method parameters.
- *Why lower in the trait's module?* Its body's facts and names are that
  module's. The importer may declare a same-named function, and the
  interpreter never calls it.

## Binding namespaces (#824 follow-up)

Resolved Grill Log: all matched body rigid names except `Self` are retained as
unformed derived bindings, including a default's own renamed parameters.
Implementation scheme parameters are settled first; body bindings overlay them
only after substitution. A trait's `T` may therefore be `Str` while the
implementation's `T` is `Int`. A nonempty derived map requires specialization
even for a monomorphic implementation. `Self` remains the fixed receiver.

## Trait arguments absent from a member signature (#824)

Resolved Grill Log: a default may use a trait parameter only in its body.
Matching that member's signature cannot recover the argument. Read every
trait parameter from the implementation head already canonicalized by
[[Compiler Literals]], matched to the canonical owner and trait identities.
Decode that checked syntax structurally, treating implementation parameters
as rigid names; never resolve aliases or infer types again. Scheme matching
still supplies a method's own parameters renamed by checking. Trait-head
arguments take precedence over same-spelling method matches.

## Indexed stores (#840)

Built-in dispatch precedes trait lookup for the store's seven methods, read from the evaluator's table. Resolved Grill Log: one method list for both engines.

## Dynamic dispatch, written type arguments and constructor parameters (#846)

A method on a `dynamic Trait` value runs its arguments first, then its
receiver, and matches the held type against the trait's closed sum; each arm
calls the implementation selected for that type. The result type is the first
arm's, and an empty sum refuses where the call is written.

A qualifier naming a type parameter in a generic copy resolves through the
copy's bindings before selection. A qualified call carries what it wrote: an
owned receiver type (`Option[Str].decode`), the type arguments written on the
call, and the instantiation checking inferred. `invoke` widens each operand to
its parameter's type, so a constructor parameter (`F[_]`) works plain and
through a trait. Resolved Grill Log: dynamic dispatch is a match over the
program's implementations, not a table of addresses; written, elaborated and
inferred arguments all select the same instance.
