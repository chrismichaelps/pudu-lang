---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel/Audio.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Audio Kernels]
---
# Native Audio Kernels

Export the family's runtime parts and their prerequisites.

The tone and ramp byte generators as `Pudu.Eval.AudioKernel` answers them, with their parameter tests as separate kernels.

## Resolved Grill Log

Samples are computed in 64-bit integers; the bounds the tests enforce keep every product inside them.

## Referenced by

[[Native Kernel Runtime]] · [[Native Builtin Kernels]]
