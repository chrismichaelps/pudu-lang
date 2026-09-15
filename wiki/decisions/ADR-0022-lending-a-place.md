---
type: decision
status: ACCEPTED
date: 2026-09-15
tags: [decision, language, ownership, mutation, references]
aliases: [ADR-0022-lending-a-place]
---

# ADR-0022: Lending a Place

## Context

[[ADR-0003-ownership-and-resource-safety]] gave Pudu `var`, `mut` record fields, and `&mut T`, and
[[architecture/SEMANTICS]] said mutation needs one of them. None of it worked. The evaluator stored
only into a binding by its name, and treated `&`, `&mut`, and `*` as the value itself, so
`*reference = value`, `record.field = value`, and `items[i] = value` checked and then stopped the
program. They were then refused at check time with `E3077`, which left `&mut` in every signature
meaning nothing: a function declared to change what it was lent could not change it.

The checker also never asked whether a binding was declared `var`. Assigning to a `let`, a
parameter, or a pattern binding was accepted, and ran.

## Decision

**A place** is a variable, a field of a place, an element of an array place, or `*r` where `r` is
an exclusive reference. Writing one needs authority at its root and permission at every step:

- the root was declared `var`, or the path goes through a `&mut` parameter — which may be written
  inside but not itself replaced;
- a field is declared `mut`;
- nothing is written through a shared reference `&T`;
- text, tuples, and maps have no element places.

**`&mut place` is written only as a call argument**, and the place must be writable by the same
rules. A method taking `self: &mut Self` requires a writable receiver. Two places lent to one call
may not overlap: one may not be the other or lie inside it, and two elements of one array count as
possibly the same.

**`&mut T` is only the type of a parameter**, at the top of it. It is refused in results, binding
annotations, fields, variant payloads, aliases, type arguments, and the parameters of an `async fn`.
A binding, a result, or a value passed to a parameter of any type may not come to hold one by
inference, a closure may not capture one, and a function literal's parameter that receives one must
be written `&mut`.

**The evaluator lends by copy and hands back.** A `&mut` argument's place is resolved, with its index
keys evaluated once, and its value given to the callee. When the callee finishes — by its last
expression, `return`, or `?` — the final value of each `&mut` parameter is stored into the place it
was lent from. An assignment resolves its place before evaluating the right-hand side.

Whether a name reaches a `var` binding is taken from the resolver, which already scopes every
binding: the checker receives the spans of every use of a `var` as a set, rather than scoping names
a second time.

## Why copy-in, copy-out is not a workaround

A reference that cannot be stored, returned, captured, or duplicated exists only while the call it
was lent to runs, and for that time nothing else can reach the place — not the caller, which is
suspended in the call; not another argument, which may not overlap; not a closure or a field, which
cannot hold it. A program therefore has no way to observe the place between the loan and the return,
and handing the value in and the final value back is indistinguishable from writing through an
address. It needs no aliasing analysis and no heap cell, and a future compiled backend is free to
pass an address instead, because the rules above are exactly the ones that make that safe.

## Consequences

- `E3078` a binding that is not `var`; `E3079` a field not declared `mut`; `E3080` a write through a
  shared reference; `E3077` something that is not a place; `E3081` `&mut` outside a call argument,
  or a non-place given to an exclusive parameter; `E3082` overlapping loans; `E3083` `&mut` written
  in a type position it may not take; `E3084` an exclusive reference kept by inference. `E3076`, a
  change to a captured name, is unchanged.
- No committed program assigned to a `let`, a parameter, or a pattern binding: 527 standard library,
  example, website, and fixture sources check unchanged.
- `UsesPlaces` holds 18 evaluated writes; `PlaceSpec` holds every acceptance and refusal above.

## Rejected

- **Keeping `E3077` and documenting "return the changed value".** `&mut` would remain a word in
  signatures that nothing honours.
- **References as mutable cells in the evaluator.** Every value would need an indirection and every
  read a dereference, to support aliasing the language forbids.
- **Scoping `var` again in the checker.** Two walks of the same scopes must agree forever; the
  resolver's answer is already exact.
