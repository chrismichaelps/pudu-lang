---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ffi_objc.c"
fidelity: Active
grammar: C11
aliases: [Pudu FFI Objective-C Bridge]
---

# Pudu FFI Objective-C Bridge

Hold the Objective-C entries of the callback bridge: block invocation, runtime
delegate classes, and their release. The file compiles to working code only on
Apple platforms; on every other platform each entry answers null.

## Interface

- Block invoke closure, moved from the callback bridge. It forwards the block's
  key and arguments to the group member's trampoline. `pudu_ffi_callback_block_code`
  builds the closure for a signature.
- `pudu_ffi_block_size` and `pudu_ffi_block_fill` size and write a block literal
  into storage allocated for one call.
- Method closures receive `(self, _cmd, args...)`. Each is built per member
  signature with its Objective-C type encoding and prefixed with the two
  hidden parameters.
- `pudu_ffi_delegate_class` defines the runtime subclass of the root object
  class once. It adds one method per group entry.
- `pudu_ffi_delegate_new` creates an instance and stores the group registration
  key in its indexed extra bytes.
- `pudu_ffi_delegate_release` sends the release message to an instance.

## Resolved Grill Log

An instance keeps only the registration key. A method closure reads the key from
`self`, looks up the member, and enters its trampoline with the member's
context first. A call that arrives after the group is unregistered finds the key
retired and answers the member's declared fallback, so a late message from a
library never reaches freed state.

## Referenced by

[[Pudu FFI Callback Bridge]] · [[Pudu FFI Callback Adapter]] · [[src/cbits/_MOC]]
