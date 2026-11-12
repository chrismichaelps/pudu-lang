---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Compiler/Lower/Foreign.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Compiler Lower Foreign]
---
# Compiler Lower Foreign

`lowerForeignCall` lowers a call whose bare name reaches a foreign
declaration, the module's own or a selectively imported one, to
`CoreForeignCall`: the arguments run in order, then the call through the
declared library, version and symbol ([[Native Foreign Call Sites]], #850).
The crossing types are the checked argument types and the call's own result.

## Interface

`lowerForeignCall :: (LowerState -> Located Expression -> Lowered) -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered`

## Resolved Grill Log

- **Q:** Read the parameter types from the declaration? **A:** From the checked
  call. _Rationale:_ checking already formed every argument at its declared
  crossing type, and lowering has the call's facts at hand; the declaration's
  written types would need a second resolution.
- **Q:** Which crossings? **A:** Fixed-width integers, both float widths, `Bool`
  and a `()` result. Text, bytes, records, handles and slots refuse here until
  their slices (#851–#854).

## Referenced by

[[Compiler Lower Primitive]] · [[Native Foreign Call Sites]]
