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

## Collection callable values (#631)

charFromCode, bytesOf, mapOf and setOf register bodies keyed by the full
solved CoreFunctionType, built by the Convert, Bytes and Keyed builders their
direct calls use. A Keyed body that may meet an unorderable key refuses at
the caller through CoreFailCaller.
Resolved Grill Log: one Core definition per builtin; per-tag identity; no
synthetic source call. See [[Native Collection Callables]].

## Stopping builtin values (#633)

panic and convertInteger register bodies from [[Compiler Lower Stop]] for any
represented one-argument signature; panic needs a Str parameter.
Resolved Grill Log: refusals point at the value call through CoreFailCaller;
identity stays per tag. See [[Native Stopping Builtins]].

## Any arity and annotated panic (#633)

register takes every parameter type, numbering locals from zero and keeping
the single-parameter name `value`. annotatedPanic lets `let stop: fn(Str) ->
Never = panic` bind, reading the written annotation because checking gives
panic no type (#634); other annotations still refuse.
Resolved Grill Log: trusting any annotation would let calls with unchecked
argument types through, so only panic's own signature is taken.

Closure info passes closureMethod = Nothing. (#644)
