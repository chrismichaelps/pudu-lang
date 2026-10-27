---
type: module
path: "@root/src/Pudu/Compiler/Lower/Intrinsic.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Intrinsic]
---
# Compiler Lower Intrinsic

Export lowerOutputValue :: LowerState -> Span -> Text -> Maybe Lowered.
Recognize only the four standard-stream prelude values after the caller has
resolved nearer declarations. Validate the exact solved callable type, then
register one Core function and builtin closure metadata under a reserved key.
The generated body takes one Str parameter and uses outputResult from Lower
Call. Restore caller-local state while retaining new context products.

## Resolved Grill Log

Builtin identity is per tag, never per reference span or generic caller.
Generated bodies carry no hidden environment and no counted source call.
Their output/Result semantics are shared with direct calls. Refuse missing or
unrepresented facts with an explicit located diagnostic; never infer a type.
No source evaluator invocation, alternate output adapter or borrowed capture.

## Referenced by

[[Native Output Callable Values]] · [[Compiler Lower Body]] · [[Compiler Lower Call]] · [[src/Pudu/Compiler/_MOC]]
