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

## Text and bytes (#851)

Parameters may also cross as `Str` and `Bytes`, and a result as `Str`. Records, handles and slots still refuse (#852–#854).

## Records (#852)

A parameter or result may also be a record of between one and thirty-two fields, each a number, Bool, text or such a record (bytes excepted), as the interpreter's crossing rules admit.

## Handles (#853)

Opaque handles cross at top level. A result carries its checked borrowed,
owned or counted transfer policy. Output slots remain refused (#854).

## Referenced by

[[Compiler Lower Primitive]] · [[Native Foreign Call Sites]]

## Scalar output slots (#854)

Resolved Grill Log: Admit scalar slots from the checked tuple. Preserve the ABI result before the slots.

## Record output slots (#854)

Resolved Grill Log: admit record slot layouts with scalar leaves, preserving nested C ABI.

## Text slots (#854)

Resolved Grill Log: Admit optional text slots and record slots with text fields.

## Owned output slots (#854)

Resolved Grill Log: Admit checked optional handle slots with a declared destructor.
