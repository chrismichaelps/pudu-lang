---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Foreign/Callback/Native.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Foreign Callback Native Adapter]
---

# Foreign Callback Native Adapter

Marshal validated callback signatures into [[Pudu FFI Callback Bridge]].
The adapter publishes a native function and context pair while keeping its
stable pointer behind the bridge's generation lookup.

## Resolved Grill Log

- Decode record arguments with the same offsets and leaf reconstruction as
  [[Foreign Call]]. Incoming pointer storage is used only during invocation.
- Separate the immutable signature's code pointer from the live generation.
  Cache each native context by its logical registration generation for the
  run. Release the stable pointer through the native retirement hook after the
  last invocation leaves. No late callback can dereference the pointer.
- Return a native fallback on a host exception at the foreign export.
  Evaluator failures are recorded by the invocation handler before this
  final boundary.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.

## Referenced by

[[src/Pudu/Foreign/_MOC]] · [[Pudu FFI Callback Bridge]] · [[Foreign Callback Delivery]]

### Split callback placement Grill Log resolved

Static and registration crossings share the adapter code address.

## Resolved Grill Log for callback byte runs

Validate pointer and length before copying bytes from callback storage.

## Resolved Grill Log for static adapter reuse

Cache successful adapter lookups by checked owner within the run. Native
registrations still have independent lifetimes and retain their own context
keys. Closing the cache retires registrations and releases lookup state.

## Resolved Grill Log for interpreter callback groups

Cache adapters by owner and member. One registration retains the dispatcher while each adapter supplies its member and decoded leaf count.

## Resolved Grill Log for Objective-C delegates

`createDelegate` leases the group registration and calls the native constructor. `releaseDelegate` drops that lease and sends the release message through the runtime.
