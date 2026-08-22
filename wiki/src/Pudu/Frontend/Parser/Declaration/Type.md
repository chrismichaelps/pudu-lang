---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Type.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.66
depth_status: MEDIUM
coupling: 5.0
interface_stability: 1.0
tags: [module, medium]
aliases: [Parser Type Declaration]
---

# Parser Type Declaration

## Purpose

Parse `type` declarations into their three shapes — record, sum, and alias — preserving field mutability, variant payloads, and generic parameters.

## Interface

### Signatures

```haskell
parseTypeDeclaration :: Visibility -> Parser (Located Declaration)
```

### Governance

- One keyword declares all three shapes, matching [[grammar/pudu]]: `enum` and `struct` stay reserved rather than becoming second spellings of the same thing.
- Visibility is supplied by the orchestrator that consumed `export`.
- The declared name is uppercase through [[Parser Name]]'s `E1011` rule; field names use the `E1012` value-name rule.
- Definition dispatch is structural: `{` opens a record, a leading `|` opens a sum, and an uppercase name is a sum exactly when a `|` follows its first variant at bracket depth zero. Everything else is an alias for one type reference.
- The sum lookahead is bounded to 512 tokens and stops at the next declaration start, so a malformed definition can never make it walk the file.
- Record fields are immutable unless marked `mut`, preserving the ownership rule in [[architecture/SEMANTICS]] as syntax.
- Variants carry a unit, positional, or record payload; payload types are ordinary references through [[Parser Type]].
- Field and variant iteration require token progress and stop on a latched budget.

### Linkage

- **Requires:** [[Parser State]], [[Parser Name]], [[Parser Type]], [[Parser Generic]], [[Syntax Tree]], [[grammar/pudu]].
- **Consumed by:** [[Parser Declaration]].

## Algorithm

Consume `type`, validate the uppercase name, parse optional generic parameters, require `=`, then dispatch to record, sum, or alias parsing and merge the keyword-to-definition span.

## Negative Logic (Prohibited Paths)

- No field or variant uniqueness checking, recursion or size analysis, `Copy` eligibility, exhaustiveness data, or type resolution.

## Edge Cases

- `type Choice = Yes | No` is a sum even without a leading `|`; `type Meters = Int64` is an alias because no `|` follows.
- A record admits one trailing comma; an empty record body yields no fields rather than a diagnostic.
- A variant record payload reuses the same field parser, so `Circle{radius: Float}` and a record declaration share one rule.

## Depth

DEPTH 0.66 (MEDIUM). It hides three definition shapes, the bounded sum lookahead, and payload dispatch behind one entry point.

## Grill Log

- **Q:** How is a one-variant sum distinguished from an alias? **A:** By a bounded depth-zero scan for `|`. _Rationale:_ the parser has no backtracking, and requiring a leading `|` on every sum would reject the spelling [[grammar/pudu]] shows. _Rejected:_ speculative parse with rollback; mandatory leading `|`; deciding by the payload's shape.
- **Q:** Should `enum` and `struct` become aliases for sum and record? **A:** No; they stay reserved with `E1039`. _Rationale:_ one declaration keyword keeps the surface small, and silently accepting a second spelling would fork the grammar. _Rejected:_ admitting all three keywords.
- **Q:** Where does field mutability live? **A:** In the syntax node as a flag. _Rationale:_ ownership checking needs the declared intent, and a later phase cannot recover it from the source. _Rejected:_ dropping `mut` at parse time.

## Variants

- Recursive-type indirection markers and const generic arguments extend this module when their semantics are resolved.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser Declaration]] · [[Parser Generic]] · [[Parser Type]] · [[Syntax Tree]]
