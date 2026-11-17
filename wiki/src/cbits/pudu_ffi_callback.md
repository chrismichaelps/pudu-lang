---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ffi_callback.c"
fidelity: Active
grammar: C11
aliases: [Pudu FFI Callback Bridge]
---

# Pudu FFI Callback Bridge

Prepare one libffi trampoline per native callback declaration shape.
Decode native arguments into the interpreter bridge's scalar channels.

## Resolved Grill Log

- Cache immutable trampoline code and its fallback separately from live
  interpreter state. Libraries can invoke an old code pointer after run
  teardown, when it only returns the declared fallback.
- A native context is a process-unique nonzero generation. Acquire the
  matching live entry under the registry lock, then release the lock before
  calling the interpreter. Retirement removes admission and defers disposal
  until the last invocation leaves.
- Publish a scoped call context on the invoking native thread only during
  the foreign call. The trampoline receives it for nested failure routing.
- Records use the same flattened leaves and platform offsets as outbound
  calls. Follow libffi's widened integer return contract.

## Resolved Grill Log for Objective-C blocks

A callback parameter written `work: block Work` crosses as one pointer to a block literal, with passing mode BlockPassing and placement BlockCallback. The block is a stack block (isa `_NSConcreteStackBlock`, no copy or dispose helpers) whose last field is the registration key, and it lives for the foreign call only. A callee that keeps the block copies it with `Block_copy`; the copy carries the key, which is how escaping blocks are copied. The block's invoke receives the block first, so the callback must declare its context first; the checker refuses otherwise with E3063 ("callback X must take its context first to cross as a block"). A late invocation after unregister finds the key retired and answers the fallback.
Interpreter: each libffi adapter lazily builds a second closure (`pudu_ffi_callback_block_code`) that reads the key from the block. `pudu_ffi_block_fill` writes the literal into storage allocated for the call.

## Referenced by

[[src/cbits/_MOC]] · [[Pudu FFI Bridge]] · [[Foreign Callback Delivery]]

## Resolved Grill Log for callback byte runs

Libffi decodes the Bytes argument as one pointer leaf. The dispatcher checks its extent before reading the buffer.

## Resolved Grill Log for callback scratch

Scalar and small record callbacks decode into invocation-local scratch.
Larger flattened layouts allocate one array per carrier. The dispatcher
receives null on allocation failure and applies the checked fallback.

## Resolved Grill Log for group callback dispatch

A group member closure matches the stable group owner and key. Individual
callbacks still require adapter identity. The closure passes its checked
member and leaf count while retaining the shared registration.

## Resolved Grill Log for Objective-C delegates

The Objective-C entries moved to [[Pudu FFI Objective-C Bridge]]. The helpers that remain in this file use the `pudu_ffi_` prefix, and the shared declarations live in [[Pudu FFI Callback Adapter]].
