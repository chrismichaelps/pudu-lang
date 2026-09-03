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
declareForeign :: Foreign -> Checker ()
checkForeign   :: Foreign -> Checker ()
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
- **Three things are catchable here and all three are caught:** a type that cannot cross, an owned
  result that names no release, and a release the library does not declare. The fourth — a signature
  that does not match what the library actually exports — is the one nothing can catch, which is why
  the other three are worth catching.

### Linkage

- **Requires:** [[Type Env]], [[Foreign Crossing]].
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

## Referenced by

[[src/Pudu/Type/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
