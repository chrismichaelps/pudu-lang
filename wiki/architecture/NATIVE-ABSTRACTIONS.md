---
type: architecture
tags: [architecture, backend, native, generics]
aliases: [Native Type Abstractions]
---
# Native Type Abstractions

The forms that name a type without holding a value of it are native (#846).

| Form | Native behavior |
| --- | --- |
| `T.member()` in a generic copy | the copy's bound type selects the implementation, with `Self` and the implementation's own parameters settled from that type |
| `made[Point]()` | written type arguments bind parameters the function's type never mentions |
| `Array.parse[Int](text)`, `Option[Str].decode(json)`, `Module.Type.member(...)` | the forms elaboration writes for a static call it selected |
| `dynamic Trait` | a sum over the trait's implementing types; widening, dispatch, rendering as the held value |
| `F[_]`, `F[_, _]` | the parameter is bound to a constructor and applied when a type is formed |
| `let [a, ..rest] = value` | a sequence pattern at any depth of a `let` pattern |

## Type arguments at a call

Checking records the arguments written on a type application as one fact,
under the application's own span with its ends exchanged. Such a span covers
no offset, so no reader pointing at the source finds it. Elaboration writes
type applications checking never saw; their arguments are read from the
syntax, which is already canonical. [[Compiler Lower Generic]]'s
`writtenTypeArguments` forms and holds them for the callee's admission,
which reads them once: the generic path for a module's function,
[[Compiler Lower Method]] for an implementation's member.

A static call through a type parameter passes the type the parameter stands
for. The member's copy takes `Self` from it, and the head of the
implementation that provides the member is matched against it to settle the
implementation's own parameters: `A` of `impl [A] Named for Array[A]` where
`T` is `Array[Int]`.

## Dynamic values

[[Compiler Lower Dynamic]] owns the contract. A `dynamic Trait` forms to a
sum with one variant per implementation that has no parameters of its own.
A concrete value widens into its variant where a dynamic type is expected:
array items, record fields, variant payloads, call and method arguments,
annotated bindings, assignments, `return`, a function's result, and the
branches of an `if` or the arms of a `match` whose own type is dynamic. A
literal nested inside another literal widens with it. A method call on a
dynamic value runs the arguments, then the receiver, and matches on the held
type to call that type's implementation, inherited defaults included. A
dynamic value renders and compares as the value it holds.

## Constructor parameters

A parameter of arity above zero is bound to the constructor the actual type
names and the arguments the application does not supply. Forming `F[A]`
applies the bound constructor to the formed arguments. A call through a
constructor parameter leaves the callee's fact naming an application
checking never settled; the arguments' own facts say what was applied.

## Sequence bindings

[[Compiler Lower Match]] lowers a `let` whose pattern holds a sequence
pattern as a match: success publishes the bindings into the enclosing block,
and any other value stops with E7013 at the pattern, naming what the subject
is, as the interpreter does.

## Not native

Trait members named as values (`Trait.member` without a call) are rejected
by checking, so there is nothing to emit (#647). A user `Drop` has no
run-time meaning in the interpreter, so native has none to match. A generic
implementation's types are not variants of a dynamic sum.

## Evidence

[[Backend Abstraction Programs]] carries the corpus through the differential
and counted-allocation harnesses; the derive, default-self, dynamic and
higher-kind fixtures build natively and match the interpreter.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]]
