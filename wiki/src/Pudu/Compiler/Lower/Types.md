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

- **Q:** Reconstruct private signatures from annotations? **A:** No; consume final schemes, which already include inference and aliases. Rejected: a second native inference pass.
- **Q:** May an offset identify a generated expression? **A:** No; only the complete Span owns the fact. Rejected: authored-offset fallback or nearest-expression lookup.
- **Q:** Does recognizing Str admit general text ownership? **A:** No; representation admission remains at each existing lowering boundary. Rejected: treating type recognition as completed runtime support.
- **Q:** Can a nominal type named Int select the integer ABI? **A:** Only the canonical compiler-wired identity may do so. Rejected: comparing display names alone.
- **Q:** Should expected static types erase Never control flow? **A:** No; existing structural transfer propagation remains in Core lowering. Rejected: replacing a divergent operand with an inhabited expected value.
- **Q:** Must interpreter caches retain all analysis facts? **A:** No; this slice uses full-analysis products. Rejected: widening unrelated execution-product caches.

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
