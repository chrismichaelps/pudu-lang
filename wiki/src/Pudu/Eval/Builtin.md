---
type: module
path: "@root/src/Pudu/Eval/Builtin.hs"
fidelity: Active
domain: "[[Execution Result]]"
subsystem: "[[Runtime]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 4.0
interface_stability: 0.8
tags: [module, medium, runtime]
aliases: [Eval Builtin]
---

# Eval Builtin

## Purpose

Implement the values [[Semantic Prelude]] wires in: the effects, the built-in methods on arrays,
text, maps, sets, and characters, and the conversions nothing in the language can express.

## Interface

```haskell
type Apply = Span -> Value -> [Value] -> Evaluator Value

callArrayMethod  :: Apply -> Span -> ArrayMethod -> Value -> [Value] -> Evaluator Value
callStringMethod :: Span -> StringMethod -> Value -> [Value] -> Evaluator Value
callMapMethod, callSetMethod, callCharMethod :: Span -> ... -> Evaluator Value
callEffect       :: Span -> Builtin -> [Value] -> Evaluator Value
callDecimal      :: Span -> Builtin -> [Value] -> Evaluator Value
callShow, callDisplay, callPanic, callMapOf, callSetOf, callCharFromCode,
callConvertInteger :: Span -> ... -> Evaluator Value
effectBuiltins   :: [Builtin]
isDecimalBuiltin :: Builtin -> Bool
```

### Governance

- **Only `callArrayMethod` takes the `Apply` capability**, because only it calls back into a value
  the caller supplied: `map`, `filter`, and `reduce` invoke their argument, and dispatch needs the
  method to answer a call. That is a genuine cycle and the capability is how it is expressed. The
  other method families take no capability because they never call back, and giving them one would
  have claimed a dependency that does not exist.
- Every effect answers with `Result[T, Str]` rather than failing. The language has no exceptions, so
  a missing file is an outcome a caller handles, and the failure carries what the operating system
  said rather than a message this compiler invented.
- Effects are refused while a constant is folded. A `const` initialiser runs inside the compiler, so
  reading a file there would make the compiled output depend on the machine that compiled it.
- `show` quotes text and `display` does not. A reader inspecting a value needs `"1"` never to be
  mistaken for the number; a message being built wants the string's own content. Everything that is
  not text or a character renders identically either way.
- `effectBuiltins` is one list so the evaluator and the checker cannot disagree about which names
  exist, and adding an effect is one edit rather than three.

### Linkage

- **Requires:** [[Eval Value]], [[Eval Env]], [[Eval Array]], [[Eval Keyed]], [[Eval Io]],
  [[Eval Clock]], [[Eval Order]], [[Decimal Literal]], [[Integer Literal]].
- **Consumed by:** [[Evaluator]].

## Algorithm

Dispatch on the built-in tag and the argument shapes, answering with a value or aborting with an
`E7xxx` diagnostic. Higher-order array methods call the supplied `Apply`.

## Negative Logic (Prohibited Paths)

- No typing. The checker has already decided what these receive; re-deciding here would put one rule
  in two phases.
- No importing [[Evaluator]]. The `Apply` capability is the path back.
- No host exceptions. Every failure is a diagnostic.

## Grill Log

- **Q:** Why does only one method family take the capability? **A:** Because only one has the cycle.
  _Rationale:_ threading `Apply` through the map, set, char, and text families made four signatures
  claim a dependency none of them has, and GHC said so immediately. _Rejected:_ a uniform signature
  for symmetry.
- **Q:** Why are effects blocked at fold time rather than refused statically? **A:** They are not,
  any more — see [[ADR-0009]] for the proposal that moves the check into the type. Today the gate is
  here because effects have no static vocabulary to check against.

## Referenced by

[[src/Pudu/Eval/_MOC]] · [[Evaluator]] · [[Semantic Prelude]]
