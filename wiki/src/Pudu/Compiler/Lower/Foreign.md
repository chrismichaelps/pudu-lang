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

A parameter may be `Option` of a declared handle (#935), lowered as the same handle crossing with
an optional value.

## Resolved Grill Log for #876 — Native callback lowering

Translate checked callback parameters and fallbacks into Core. Direct and
first-class registrations share one operation. A retained unregister
member captures the evaluated token. The ABI position map excludes output
slots and context pointers when matching source operands.

## Resolved Grill Log for #877 — Native loan lowering

Map declared loans to caller argument positions. Lower mutable loans using the existing held-place copy-in and ordered writeback.

## Resolved Grill Log for #877 — Checked foreign bounds

Translate each checked length relation to caller indices with the same position map used for argument crossings.

## Resolved Grill Log for #877 — C11 array crossings

Accept a represented Core array at a declared address-only position when its element has a scalar-only ABI layout.

## Resolved Grill Log for #877 — Optional handles

Admit the built-in Option type around opaque handles and preserve that type for the generated wrapper.

## Resolved Grill Log for #877 — Returned run ABI

Admit an array as the native-result component only when a returned-run contract supplies its ABI and destructor.

## Resolved Grill Log for #877 — Native nullable loans

Lower checked bare None as a zero placeholder at the pointee type. Its explicit absence flag drives ABI pointer generation and avoids a mutable place read.

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

## Mixed crossings (#854)

Resolved Grill Log: allow existing input crossings and scalar, unit, text and record native results beside output slots.

## Qualified calls (#873)

`lowerQualifiedForeignCall` lowers `Qualifier.f(...)` when the qualifier
names a module (an alias or the module path's last segment) that declares
`f` foreign. It shares the crossing admission of `lowerForeignCall`, so
qualified and bare calls carry the same crossings, claims, slots and
refusals.

`lowerQualifiedForeignCall :: (LowerState -> Located Expression -> Lowered) -> LowerState -> Span -> Text -> Text -> [Located Expression] -> Maybe Lowered`

Resolved Grill Log: **Q:** Resolve the qualifier here? **A:** No; [[Compiler
Lower State]] owns qualifier scopes, and a local named like the qualifier
shadows it before this module is asked. _Rejected:_ a second qualifier table.

### Split callback placement Grill Log resolved

Pudu input positions omit static trampolines and paired hidden context slots.

## Resolved Grill Log for callback byte runs

Carry resolved extents to Core without changing native parameter order.

## Resolved Grill Log for retained split callbacks

Carry callback capability for every call declared in a block that splits
registration from its trampoline. A later call without token parameters may
invoke a retained callback, so it needs the same outbound failure scope and
must allow the handler to acquire the gate.

## Resolved Grill Log for callback group slots

Build the native signature with the module-qualified registration owner.

## Resolved Grill Log for native callback groups

Resolve declared member names to fields of the concrete checked handler record.

## Resolved Grill Log for Objective-C dispatch

Mark Objective-C calls as capable of re-entering the runtime. Other argument and ownership crossings keep their checked positions.

## Resolved Grill Log for Objective-C delegates

Lowering a delegate constructor call goes through the foreign lowering path, which validates the group token and records the class for the module's delegate definitions.

## Foreign declarations as values (#956)

A checked foreign name becomes a closure over its resolved crossing.
The direct call and the closure share the descriptor, including positions,
bounds, output slots, claims and callback handling. A mutable crossing
returns the declared result beside its final inputs through the usual
callable loan ABI and settles the foreign operation before returning.

### Resolved Grill Log

The closure does not reopen name resolution. It uses the call-through-value
site for failures and the foreign declaration identity for equality and
rendering. Nullable addresses require a separate callable ABI for absence.
