---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Foreign.hs"
fidelity: Active
domain: "[[Pudu Module]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 3.0
interface_stability: 0.7
tags: [module, medium, parser, foreign, ffi]
aliases: [Parser Declaration Foreign]
---

# Parser Declaration Foreign

## Purpose

Parse a declaration of a library written elsewhere.

## Interface

```haskell
parseForeign :: Visibility -> Parser (Located Declaration)
```

### Governance

- **The block is the unit.** The library is what its functions share: it is opened once, its version
  is one fact, and what a program reaches outside itself is one place to look rather than a search.
- **`foreign`, `version`, `symbol`, `owned`, and `by` are contextual.** They start or continue this
  declaration and are ordinary names everywhere else. Reserving four common words to add one
  declaration form would break every program that had used them, and a language that charges its own
  users a rename for a feature has chosen the feature over them.
- **The library is named by a string.** It is a name the platform is asked for rather than a name in
  this program, and a string is where a reader already expects something from outside.
- **A version is recorded rather than enforced.** Nothing here fetches or verifies a library, and a
  check this cannot perform would be a claim rather than a check.
- **`symbol "ExactName"` is an optional lookup spelling after the local name.** It admits C APIs
  such as Raylib without admitting their upper-initial names into Pudu's value namespace. The
  parser retains both spellings; it does not conflate editor identity with loader identity.
- **An owned result that names no release is refused here**, rather than leaking later. The reason
  ownership is in the declaration is that it can be checked where it is written.
- **A block-local `type Name` declares an opaque handle.** It has no fields or constructors because
  the foreign library, not Pudu, owns its representation. `type` retains its established keyword
  role and the handle name must follow the ordinary upper-identifier rule.

### Linkage

- **Requires:** [[Parser State]], [[Parser Type]], [[Parser Declaration Function]].
- **Used by:** [[Parser Declaration]].

## Grill Log

- **Q:** Reserve `foreign` as a keyword, which is simpler to parse? **A:** No.
  _Rationale:_ an existing program used `foreign` as a variable and stopped
  compiling the moment it became reserved. That is the cost, paid by users, of
  the parser's convenience. _Rejected:_ a reserved word.
- **Q:** Annotate each function with its library instead of grouping them?
  **A:** No. _Rationale:_ the library, its version, and the fact of reaching
  outside are one thing repeated on every line, and a reader auditing what a
  program touches would have to find them all. _Rejected:_ per-function
  annotations.
- **Q:** Permit the foreign spelling directly as the Pudu name? **A:** No. _Rationale:_ one imported
  library should not suspend the language's naming grammar for every caller and editor feature.
  _Rejected:_ upper-initial value identifiers inside foreign blocks.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[ADR-0018 Calling a Library Written Elsewhere]] · [[grammar/pudu]]
