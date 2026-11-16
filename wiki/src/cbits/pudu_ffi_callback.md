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

## Referenced by

[[src/cbits/_MOC]] · [[Pudu FFI Bridge]] · [[Foreign Callback Delivery]]
