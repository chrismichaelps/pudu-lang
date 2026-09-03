---
type: module
path: "@root/src/Pudu/Frontend/Parser/Capability.hs"
fidelity: Active
domain: "[[Pudu Module]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.2
depth_status: SHALLOW
coupling: 1.0
interface_stability: 0.9
tags: [module, shallow, parser, unsafe]
aliases: [Parser Capability]
---

# Parser Capability

## Purpose

Read the unchecked abilities an unsafe form names.

## Interface

```haskell
parseCapabilities :: Parser [Located Capability]
capabilityOf      :: TokenKind -> Maybe Capability
```

### Governance

- **Its own module because two forms name capabilities and neither can reach the other.** A
  declaration writes them before `fn`; a type writes them before the function shape it describes,
  and the type parser sits below the declaration parser. One reader means one vocabulary and one
  diagnostic for a word that is not in it.
- **The vocabulary is closed.** A misspelling is caught where it is written rather than silently
  granting nothing, which is the failure that matters: a region that grants nothing looks exactly
  like a region that grants what was meant.
- **`raw`, `foreign`, and `unchecked` are ordinary identifiers**, not reserved words. Reserving three
  common words to spell one list would cost every program that had used them.

### Linkage

- **Requires:** [[Parser State]].
- **Used by:** [[Parser Declaration Function]], [[Parser Type]].

## Grill Log

- **Q:** Leave this inside the declaration parser and duplicate it for types?
  **A:** No. _Rationale:_ two readers drift, and the one that drifts is the one
  that gets the new capability late — so a program would name an ability in a
  signature that a type could not express. _Rejected:_ a second copy.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[grammar/pudu]]
