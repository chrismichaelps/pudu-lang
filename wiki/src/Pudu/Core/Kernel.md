---
type: module
path: "@root/src/Pudu/Core/Kernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Core Kernel Operations]
---
# Core Kernel Operations

Export CoreKernelName: the closed set of runtime kernels a `CoreKernel`
expression may name. A kernel reads operands that are already held and
answers one value of the expression's type. Names are grouped by family:
presence of a held box, buffers, columns, digests and keyed digests,
checksums, sealing, signature checks, audio bytes, the JSON, XML and CSV
codecs, and the flat table. Layout positions a kernel needs (variant
indexes, field positions, a width or a mode) travel beside the name as
integers, not inside it.

## Resolved Grill Log

One closed name per runtime function keeps lowering and emission exhaustive
without target text in Core. Rejected: a free-form function name in Core,
and one expression shape per family.

## Referenced by

[[Core IR]] · [[Core Frame IR]] · [[Compiler Lower Kernel]] · [[Backend Emit Kernel]] · [[Native Builtin Kernels]]
