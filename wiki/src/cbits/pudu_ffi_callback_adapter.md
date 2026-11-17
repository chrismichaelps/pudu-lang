---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ffi_callback_adapter.h"
fidelity: Active
grammar: C11
aliases: [Pudu FFI Callback Adapter]
---

# Pudu FFI Callback Adapter

Shared declarations for the callback bridge and its Objective-C entries. The
header holds the adapter struct every callback shape uses, the block literal
layout, and the locking and dispatch entries that both translation units call.

## Interface

- The shared adapter struct carries the trampoline code, its fallback, and the
  registration generation that the dispatcher checks on each entry.
- The block literal layout matches the stable block ABI: isa, flags, reserved,
  invoke, descriptor, then the registration key as the last field.
- `pudu_ffi_lock_callbacks` and `pudu_ffi_unlock_callbacks` bracket registry
  access.
- `pudu_ffi_dispatch_callback` is the single entry that hands a decoded
  invocation to the interpreter bridge.

## Resolved Grill Log

The header is the only place the layouts are declared. Both the general callback
bridge and the Objective-C entries include it, so a block literal built on one
side is read on the other with the same offsets.

Declarations here carry no behavior. Each definition lives in the translation
unit that owns its platform, which keeps the header usable on every target.

## Referenced by

[[Pudu FFI Callback Bridge]] · [[Pudu FFI Objective-C Bridge]] · [[src/cbits/_MOC]]
