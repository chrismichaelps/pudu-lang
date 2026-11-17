---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Foreign/Callback.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, foreign, ffi]
aliases: [Foreign Callback Signature]
---

# Foreign Callback Signature

## Purpose and interface

Validate a foreign block's callback signatures and the placement of function
pointer and context arguments under [[Foreign Callbacks and Thread Affinity]].
`checkCallbackDeclarations` returns the block-local signatures.
`callbackPairs` returns the native positions of callback arguments and their
context references, in callback argument order.

A callback signature retains the native parameter sequence. Value parameters
reuse [[Foreign Crossing]] and a handle parameter is always borrowed. The
result is either void, or a scalar paired with a checked fallback value.

## Resolved Grill Log

- **Q:** What does validation do with the native context? **A:** Keep its
  position in the trampoline. In a foreign function, validate each context
  reference against a unique callback argument in the same signature. Both
  positions count toward the ABI's parameter limit.
- **Q:** How are literal widths handled? **A:** Read the literal using the
  existing compiler decoders, require a matching explicit suffix, and check
  the declared integer width or float representation. Preserve the float
  width and signed zero through the fallback.
- **Q:** When does a callback name resolve? **A:** Within its own foreign
  block, after its declaration. Reject duplicate names and collisions with
  opaque handles before using the block's signatures.
- **Q:** Does a validated signature enable dispatch? **A:** The checker
  retains a separate admission guard until token binding and both runtime
  paths consume these checked shapes.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Type Check Foreign]] · [[Foreign Callback Delivery]]

### Split callback placement Grill Log resolved

Checked placements carry native positions and identify the single input position, if any.

## Resolved Grill Log for callback byte runs

Resolve every Bytes argument to exactly one fixed-width integer length.

## Resolved Grill Log for callback groups

Resolve each group member against an earlier same-block callback signature. Preserve declaration order for use by the two runtime dispatch paths.

## Resolved Grill Log for a group constructor

Member metadata retains callback type identity independently of the projected group field.

## Resolved Grill Log for callback group slots

A projected trampoline carries the member ordinal and selected signature. The context slot carries the group owner and takes one token.
