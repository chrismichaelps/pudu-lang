---
type: module
path: "@root/src/Pudu/FloatKernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, math]
aliases: [Float Kernel Identity]
---

# Float Kernel Identity

## Purpose and interface

States which binary64 kernels exist, their prelude names and their shapes. It depends only on
`Data.Text`, so the checker and resolver read it without depending on the runtime layer that
implements the kernels in [[Runtime Float Kernels]].

```haskell
data FloatKernel   -- closed, Enum and Bounded
data KernelShape = FloatArguments !Int | FloatToWord | WordToFloat | IntToFloat | FloatToInt
floatKernels     :: [FloatKernel]
floatKernelName  :: FloatKernel -> Text
floatKernelShape :: FloatKernel -> KernelShape
```

Names are `float` followed by the operation (`floatSqrt`, `floatAtan2`, `floatToBits`).
Two-argument kernels are `atan2`, `pow` and `hypot`; `fma` takes three; `fromInt` and `toInt`
convert between Int and Float64; the rest take one Float64.

## Grill Log

- **Q:** Put the enumeration in the runtime module? **A:** No; the checker and resolver would then
  depend on the evaluator's runtime layer. Identity and implementation are separate modules.

## Referenced by

[[Runtime Float Kernels]] · [[Eval Builtin Definition]] · [[Type Check Prelude]] · [[Semantic Prelude]]
