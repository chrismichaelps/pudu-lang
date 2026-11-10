---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Kernel Runtime]
---
# Native Kernel Runtime

Export kernelRuntimeParts and kernelRuntimeDependencies: every kernel part
in emission order and each part's prerequisites, gathered from the family
modules under `Runtime/Kernel`. The parts use `pudu_cell`, so they are
emitted after the frame types.

## Resolved Grill Log

One function per part: a program carries only the kernels it calls, and no
unused static function is written.

## Referenced by

[[Backend Frame Program]] · [[Native Runtime Dependencies]] · [[Native Builtin Kernels]]
