---
type: module
path: "@root/src/Pudu/Type/Check/Foreign.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Type System]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.5
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.7
tags: [module, medium, types, foreign, ffi]
aliases: [Type Check Foreign]
---

# Type Check Foreign

## Purpose

Give every foreign function a type, and catch what its declaration can be wrong about.

## Interface

```haskell
declareForeign :: DeclaredTypes -> RecordLayouts -> Foreign -> Checker ()
checkForeign   :: RecordLayouts -> Foreign -> Checker ()
foreignHandles :: Foreign -> Set Text
```

### Governance

- **A foreign declaration is checked more carefully than ordinary code, not less.** It is the only
  description of the function that exists — there is no body to read and no definition elsewhere —
  and where it is called a mistake is a corrupted stack rather than a diagnostic.
- **The name is bound like any other name.** So a call is checked, hover shows the signature,
  completion offers it, and going to the definition arrives at the declaration, which is the
  definition as far as this program is concerned. None of that needs machinery of its own.
- **Every foreign function requires the `foreign` capability without saying so.** The signature is
  unverifiable by construction, and this language already has a word for an assertion of that kind.
- **Handle syntax is formed through `DeclaredTypes`.** This preserves the declaring module in nominal identity, so same-spelling handles from two binding modules cannot unify; scalar crossings still retain their exact ABI widths. A parameter is formed through
  `parameterCrossingFor`, so `Option` of a declared handle is admitted there and nowhere else;
  `formedCrossing` takes the same path.
- **A slot is a native argument and not a Pudu one.** Two signatures are derived from one
  declaration: the native one, ordinary parameters and slots in source order, and the Pudu one,
  ordinary parameters answering a tuple of the native result and each slot. The native result stays
  in that tuple even when it is unit, so adding a status later moves no slot.
- **A pointer slot answers `Option` and a scalar or record slot does not.** Null is an absence a
  pointer really carries; a written zero and an unwritten cell leave the same bytes, so optionality
  there would be invented rather than observed.
- **Every locally catchable ownership mistake is caught here:** a type that cannot cross, a borrowed
  handle result, an owned non-handle result, an absent release, and a release whose declaration is
  missing or does not take exactly the produced handle and return `()`. A signature that disagrees
  with the binary remains unverifiable and is why calls require `unsafe(foreign)`.
- **An explicitly mapped native symbol must not be empty.** Empty lookup is always a declaration
  defect and is reported as `E3068` before the platform loader is involved.
- **Void and bridge capacity are checked at the declaration.** `()` may be a result but cannot be an
  argument or record field, and the native bridge accepts at most 32 arguments and 32 fields in one
  flat record. A signature beyond those bounds is not admitted and then surprised at runtime;
  `E3071` names the record limit rather than collapsing that case into the generic uncrossable-type
  diagnostic.

### Linkage

- **Requires:** [[Type Env]], [[Foreign Crossing]], [[Foreign Callback Signature]].
- **Used by:** [[Type Check]].

## Grill Log

- **Q:** Let a declaration name its own capabilities, as an ordinary unsafe
  function does? **A:** No; every foreign function requires `foreign`.
  _Rationale:_ a declaration that could opt out of the capability would be an
  assertion nobody was asked to grant. The whole feature sits inside `unsafe`
  for one reason and it applies to all of it. _Rejected:_ per-function grants.
- **Q:** Allow a release declared in another foreign block? **A:** No.
  _Rationale:_ a release from a different library is a call into the wrong
  allocator, and the reason ownership is written in the declaration is that it
  can be checked where it is written. _Rejected:_ resolving releases globally.
- **Q:** Admit a borrowed handle now? **A:** No. _Rationale:_ the checker has no foreign lifetime to
  attach it to, so accepting one would permit storage after the library invalidates it. _Rejected:_
  treating an unowned handle like a process-lifetime pointer.
- **Q:** Validate that the named symbol exists during checking? **A:** No. _Rationale:_ checking must
  not depend on what happens to be installed on the compiler's machine; existence is an integration
  property at execution. _Rejected:_ loading libraries during type checking.
- **Q:** Let libffi reject an oversized or void-bearing signature when it is called? **A:** No.
  _Rationale:_ the complete shape is already present in source, so deferral turns a declaration
  error into path-dependent runtime behavior. _Rejected:_ dynamic-only signature validation.
- **Q:** Diagnose an oversized record as merely uncrossable? **A:** No. _Rationale:_ the declaration
  is otherwise a supported flat record and the author needs the exact 32-field bridge boundary to
  repair it. _Rejected:_ reusing `E3063` and hiding the actionable cause.

## Resolved Grill Log for #876

- **Q:** How is `Name(f)` typed? **A:** Its sole argument is the ordinary
  synchronous function type formed from the validated callback inputs and
  result. It returns the nominal token from the declaring module. The
  registration value requires no foreign capability. Only the actual
  foreign call requires it.
- **Q:** Where do context arguments appear? **A:** The token occupies the
  checked Pudu parameter position. The context pointer is inserted at its
  separately checked native index and consumes no Pudu argument.

- **Q:** Which ordinary checks apply to a callback-bearing foreign function?
  **A:** The original argument count includes the callback and context slots.
  The remaining parameter, result, ownership and symbol checks use the same
  rules as other foreign functions. [[Foreign Callback Signature]] validates
  the callback argument types and their context pairs.
- **Q:** When can a valid pair reach dispatch? **A:** The checker retains
  the admission guard until registration, lowering and both runtime paths
  consume the checked signature. Invalid pairs report the failing span.

## Resolved Grill Log for #876 — Interpreter callback values

A callback token answers unregister with `Result[(), Str]`. This method
uses the owning nominal identity and has no foreign capability requirement.

## Resolved Grill Log for #877 — Reference parameters

Preserve the declared reference type in the Pudu function signature after
checking the pointee's ABI shape. A loan is input-only. Report a reference
in a result or output slot as E3094 and an invalid pointee as E3095.

## Resolved Grill Log for #877 — Foreign extent relations

Report invalid foreign extent relations at the declaration. A parsed nullable loan or returned run remains refused until its crossing can dispatch safely.

## Resolved Grill Log for #877 — Interpreter array crossings

Preserve reference array types at the call boundary. Report a by-value array separately from a reference whose element cannot cross.

## Resolved Grill Log for #877 — Optional handles

Keep Option in the formed language type while applying the underlying handle's ownership contract. Refuse a written Option output slot and non-handle payloads.

## Resolved Grill Log for #877 — Returned run declarations

A returned run requires owned transfer, a unique fixed-width output length, and a destructor taking one declared opaque handle. Reuse the ordinary array or Option type for the result.

## Resolved Grill Log for #877 — Direct nullable loans

Store nullable reference ordinals in the function signature in Pudu argument order. Native slots and callback contexts do not consume a Pudu argument.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]

### Split callback placement Grill Log resolved

A static trampoline occupies a native slot and contributes no Pudu argument.

## Resolved Grill Log for callback byte runs

Present the checked byte run and its scalar length to the handler.

## Resolved Grill Log for callback groups

Reject malformed callback group declarations while checking a foreign block. Group membership is independent of the native function signatures that use the group.

## Resolved Grill Log for a group constructor

The group constructor names the token and shares the existing unregister method. Member signatures determine the expected handler types.

## Resolved Grill Log for callback group slots

Foreign group contexts consume a checked group token. Projected trampolines reserve ABI slots without consuming source arguments.

## Resolved Grill Log for C loader names

Reject embedded noughts in library names, versions and explicit symbols at
the source span because the generated and interpreter loaders accept
nought-terminated strings.

## Resolved Grill Log for Objective-C declarations

Resolve class names within the same block. Count declared selector arguments separately from self and the hidden selector.

## Resolved Grill Log for Objective-C ownership

Check borrowed and transferred method results, including an instance receiver and a transferred object result for initializers.
