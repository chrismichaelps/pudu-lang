---
type: module
path: "@root/packages/pudu/v0.1/cbits/pudu_ffi_internal.h"
fidelity: Active
grammar: C11
aliases: [Pudu Private FFI ABI]
---

# Pudu Private FFI ABI

Share the checked kind codes, scalar reader and native record layout
between [[Pudu FFI Bridge]] and [[Pudu FFI Callback Bridge]].

## Resolved Grill Log

Record layout and scalar widths come from the same libffi helpers in both
directions. Function and context pointers have a private transport kind.

## Referenced by

[[src/cbits/_MOC]] · [[Pudu FFI Bridge]] · [[Pudu FFI Callback Bridge]]
