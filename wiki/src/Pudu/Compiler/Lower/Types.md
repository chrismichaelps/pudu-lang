---
type: module
path: "@root/src/Pudu/Compiler/Lower/Types.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, compiler, types]
aliases: [Compiler Lower Types]
---

# Compiler Lower Types

## Unsigned admission

Extend nativeIntegerKind to PlatformUnsigned and UnsignedKind 8/16/32/64/128.
The existing canonical identity guard and nativeScalarType propagate admission
through every scalar consumer. Resolved Grill Log: preserve UInt versus UInt64
and reject same-spelling user-owned identities and generic shapes.

## Fixed signed admission (#497)

Export nativeIntegerKind (PlatformSigned or SignedKind 8/16/32/64/128) and
nativeScalarType (those integers, Bool, Unit; not Never/Text). formedCoreType
matches NominalId Nothing with no arguments before integerKindOf, preserving
canonical identity rather than display spelling. Resolved Grill Log: aliases
are already expanded, Int64 stays distinct from Int and user-owned Int8 refuses.

## Purpose and interface

Retain the checker's settled expression types and module schemes for native
lowering. This phase-owned input belongs to the same successful CompileResult
as the checked module; it never checks syntax or infers another type.

```haskell
data LowerTypes
nativeTypes :: Maybe TypeInfo -> [(Text, Scheme)] -> Maybe LowerTypes
lookupScheme :: LowerTypes -> Text -> Maybe Scheme
typeForSpan :: LowerTypes -> Span -> Maybe CoreType
formedCoreType :: Type -> Maybe CoreType
```

## Algorithm and invariants

Store the complete TypeInfo and a deterministic map of final module schemes.
Lookup expression facts by the exact complete Span through Type.typeAt; never
use authored offsets, approximate spans, declaration spelling or another source's
facts. Generated source identity remains part of the lookup key. Function names
are scoped to the single checked module; module linking remains a separate slice.

Project canonical compiler-wired Int/UInt and their fixed 8/16/32/64/128-bit families,
Bool identities, UnitTypeValue and
NeverType into their existing Core representations. Recognize canonical Str as
CoreTextType for admission diagnostics and existing literal/display effects;
recognition does not admit owned text locals or results. Aliases have already
expanded in the formed type. User nominal identities with a matching spelling
must not be mistaken for compiler-wired identities. Unresolved variables,
generic applications and every unrepresented formed type return Nothing.

[[Compiler Lower Signature]] owns callable policy: consume a monomorphic final
scheme, validate synchronous function shape and parameter count, then use this
projection. Its source syntax supplies modifiers, defaults and refusal spans;
annotation spelling never chooses representation. [[Compiler Lower Body]] can
consult initializer facts for annotated scalar locals while preserving structural
Never propagation and print-carrier escape guards.

## Failure and negative logic

Missing expression facts or unsupported types are absent results for the caller
to turn into a located E6001. No fallback re-inference, alias expansion, offset
lookup, host exception or executable-cache widening. Full-analysis callers must
refuse missing compileTypes before entering lowering. Cached interpreter products
are not silently treated as complete native inputs.

## Dependencies and consumers

[[Type Boundary]] · [[Type Value]] · [[Pudu Core]] · [[Source]].
Consumed by [[Compiler Lower]], [[Compiler Lower State]],
[[Compiler Lower Signature]] and [[Compiler Lower Body]].

## Grill Log

- **Q:** How does Core name a record or sum? **A:** By canonical key (`Main.Point`; a built-in sum keeps its bare name), and `layoutOf` finds the layout by that key (#539).

- **Q:** What layout does a sum's unconstrained type argument get? **A:** Unit. A variable checking left unconstrained names a payload no value holds, such as the error of `Ok(1)` that is never `Err`, so the representation is unobservable. Elsewhere an unresolved type still refuses (#525).

- **Q:** Reconstruct private signatures from annotations? **A:** No; consume final schemes, which already include inference and aliases. Rejected: a second native inference pass.
- **Q:** May an offset identify a generated expression? **A:** No; only the complete Span owns the fact. Rejected: authored-offset fallback or nearest-expression lookup.
- **Q:** Does recognizing Str admit general text ownership? **A:** No; representation admission remains at each existing lowering boundary. Rejected: treating type recognition as completed runtime support.
- **Q:** Can a nominal type named Int select the integer ABI? **A:** Only the canonical compiler-wired identity may do so. Rejected: comparing display names alone.
- **Q:** Should expected static types erase Never control flow? **A:** No; existing structural transfer propagation remains in Core lowering. Rejected: replacing a divergent operand with an inhabited expected value.
- **Q:** Must interpreter caches retain all analysis facts? **A:** No; this slice uses full-analysis products. Rejected: widening unrelated execution-product caches.

## Rigid bindings and owner keys (#551)

Resolved Grill Log: LowerTypes carries what each rigid parameter stands for
in the copy of a body being lowered, and formedCoreTypeIn starts from those
bindings, so a fact naming `Self` forms the owner's type. `ownerKeyOf` gives
the name a value's methods are filed under: a record or sum key, or a
builtin's name (`Int`, `Float64`, `Str`, `()` and so on). Tuples have none.

## Generic records and raw facts (#552)

Resolved Grill Log: a record forms with its arguments, binding its own
parameters for its fields, and `layoutOf` reads a record's fields under those
arguments. `typeFactAt` gives the unformed fact, which is what
[[Compiler Lower Generic]] matches a scheme against.

## Function types (#555)

Resolved Grill Log: a synchronous function type forms when its inputs and
result do; an async one does not.

## Arrays (#556)

Resolved Grill Log: `Array[T]` forms when `T` does; its owner key is `Array`.

## Maps and sets (#561)

`Map[K, V]` and `Set[T]` are native when their arguments are, and their
methods are filed under "Map" and "Set".

## Range values (#564)

`Range[Int]` is `CoreRangeType`; its methods are filed under "Range".

## Bytes (#565)

`Bytes` is `CoreBytesType`; its methods are filed under "Bytes".

## Referenced by

[[Compiler Lower]] · [[Compiler Lower Signature]] · [[Native Emission Coverage]]

## Wide source admission (#507)

Admit SignedKind 128 and UnsignedKind 128 through the existing whitelist after #506 validation. Preserve canonical NominalId Nothing with no arguments, settled facts, platform/fixed identity and all other refusals. Resolved Grill Log: no spelling-based matching, re-inference, interpreter change or additional numeric-family admission. [[Native Wide Source Admission]].

## Floating forms (#512)

`formedCoreType` maps the canonical builtin nominals `Float32` and `Float64`
to `CoreFloatType`; the `Float` alias already resolves to `Float64` during
type formation, so an unresolved alias name is not accepted here.
`nativeScalarType` admits both widths, which opens parameters, results,
bindings and loop break values without further changes.

Resolved Grill Log: accept only the settled canonical names the checker
publishes. _Rejected:_ matching the alias spelling as a second route.

## Native value types (#515)

`nativeValueType` is `nativeScalarType` plus `CoreTextType`. Signatures,
bindings, breaks and display operands admit value types; places that still
need a scalar (conditions, integer operators) keep `nativeScalarType`.

## Char (#518)

`formedCoreType` maps the builtin `Char` nominal to `CoreCharType`, and
`nativeScalarType` admits it, which opens bindings, parameters, results,
loop values and the entry result.

## Tuples (#521)

`formedCoreType` maps a tuple of two or more native value types to
`CoreTupleType`; `nativeValueType` admits it. Tuples are values, not scalars,
so they never become conditions or integer operands.

## Records (#521)

`LowerTypes` carries the root module's records by nominal identity, set by
`withRecords`. `formedCoreTypeIn` maps a parameterless record to
`CoreRecordType` with each field formed the same way, refusing a record
reached from inside itself. `formedCoreType` stays builtin-only.

## Checked shared reference carriers (#544)

Resolved Grill Log: formedCoreTypeIn recursively projects ReferenceTypeValue
False target to the target's canonical carrier; True remains unrepresented.
Export sharedReferenceTarget, which requires an actual shared-reference type
at the exact complete TypeInfo span before projecting its target. Plain erased
Core types, approximate offsets and missing facts are insufficient evidence.
No runtime reference tag or mutable writeback is implied.

## Open type variables (#631)

formedWith forms any VariableType as unit, not only a sum's type argument.
A variable left open after checking names a type no value has, such as the
member of `setOf([])` or the argument of a builtin that is only compared.
Resolved Grill Log: Pudu does not generalize let-bound values and generic
bodies carry RigidType, so a final fact's variable is never used at two
types. The full backend suite passes with the wider rule.

## Defaulted function types (#638)

A FunctionTypeRequiring whose required count is below its parameter count
forms with a trailing Int. Resolved Grill Log: checking keeps defaulted and
all-required function types apart, so no value of one is called as the
other; nothing at run time reads parameter types.

## Made-up facts (#644)

withFacts lays facts for made-up spans over the checked ones. Resolved Grill
Log: only method-value lowering uses it, and it restores the original facts.
