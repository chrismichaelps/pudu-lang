---
type: architecture
status: IMPLEMENTED
tags: [architecture, backend, methods]
aliases: [Native Trait Methods]
---
# Native Trait Methods

Methods come from two places in Pudu: the built-in sets on Str, Char and the
collections, and `impl` blocks. Native lowering covers the second for
implementations without type parameters, plus the universal `toText()`.

## Contract

- **Which body.** Checking records every method it declares with its owner,
  scheme and name span (`compileMethods`), the inherited defaults included.
  [[Compiler Lower Method]] keys each one as an instance. A default is a copy of
  the trait member with `Self` bound to the owner, through the bindings
  [[Compiler Lower Types]] applies to every fact it reads.
- **Which call.** The receiver's checked type at its span chooses the owner.
  Str's built-in members, and Char's `code` and `toText`, come first. A type's
  own `toText` beats the universal one, which is the `display` text.
- **Order.** Arguments, then the receiver; the receiver is passed first.
  Qualified calls are ordinary calls in written order.
- **Failures.** A runtime failure inside a method or a default reports at that
  body's own source, through the ordinary call path.

## Not yet

Implementations with type parameters, defaults that read trait type
parameters, `&mut self` methods, `dynamic Trait` values and method values all
refuse with E6001. So do methods of two modules' types of one name until the
evaluator stops colliding on them (#550).

## Resolved Grill Log

- The checker's selection is the reference, not the evaluator's string keys.
  The two agree everywhere except #550, which is an evaluator bug.
- No dispatch table at run time: every receiver's type is known, so every call
  is direct.
- Instance bindings travel with the body being lowered; entering a callee sets
  the callee's and restores the caller's on the way back.

## Referenced by

[[Native Emission Coverage]] · [[Compiler Lower Method]] · [[Backend Method Programs]]
