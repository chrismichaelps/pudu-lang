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
declareForeign :: DeclaredTypes -> Foreign -> Checker ()
checkForeign   :: Foreign -> Checker ()
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
- **Handle syntax is formed through `DeclaredTypes`.** This preserves the declaring module in nominal identity, so same-spelling handles from two binding modules cannot unify; scalar crossings still retain their exact ABI widths.
- **Every locally catchable ownership mistake is caught here:** a type that cannot cross, a borrowed
  handle result, an owned non-handle result, an absent release, and a release whose declaration is
  missing or does not take exactly the produced handle and return `()`. A signature that disagrees
  with the binary remains unverifiable and is why calls require `unsafe(foreign)`.

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
- **Q:** Admit a borrowed handle now? **A:** No. _Rationale:_ the checker has no foreign lifetime to
  attach it to, so accepting one would permit storage after the library invalidates it. _Rejected:_
  treating an unowned handle like a process-lifetime pointer.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]]
