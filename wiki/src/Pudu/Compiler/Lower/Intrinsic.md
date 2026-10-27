---
type: module
path: "@root/src/Pudu/Compiler/Lower/Intrinsic.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Intrinsic]
---
# Compiler Lower Intrinsic

Export lowerIntrinsicValue :: LowerState -> Span -> Text -> Maybe Lowered.
Recognize standard-stream and display/show prelude values after the caller
resolves nearer declarations. Validate exact solved callable types, then
register Core functions and builtin metadata under reserved keys. Stream
bodies take Str and share outputResult; rendering bodies use CoreDisplay or
CoreShow with the represented parameter type. Restore caller-local state
while retaining new context products.

## Resolved Grill Log

Builtin identity is per tag, never per reference span or generic caller.
Generated bodies carry no hidden environment and no counted source call.
Their output/Result semantics are shared with direct calls. Refuse missing or
unrepresented facts with an explicit located diagnostic; never infer a type.
No source evaluator invocation, alternate output adapter or borrowed capture.

## Referenced by

[[Native Output Callable Values]] · [[Compiler Lower Body]] · [[Compiler Lower Call]] · [[src/Pudu/Compiler/_MOC]]

## Rendering callable values (#575)

Rename the entry point lowerIntrinsicValue. Recognize display/show with exact
one-argument represented callable facts and Str results. Register separate
bodies keyed by full canonical CoreType; use CoreDisplay/CoreShow directly.
Resolved Grill Log: per-tag closureSite identity survives specialization while
function bodies/ABIs remain distinct. Preserve existing output keys, restore
caller state and retain context products. See [[Native Rendering Callables]].
