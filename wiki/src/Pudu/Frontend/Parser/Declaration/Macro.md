---
type: module
path: "@root/src/Pudu/Frontend/Parser/Declaration/Macro.hs"
fidelity: Active
domain: "[[Source Text]]"
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: SHALLOW
coupling: 3.0
interface_stability: 0.8
tags: [module, shallow, parser]
aliases: [Parser Macro]
---

# Parser Macro

## Purpose

Parse `macro name(parameter: kind, ...) = body`, the declaration form of a typed syntax
transformer.

## Interface

```haskell
parseMacro :: Visibility -> Parser (Located Declaration)
```

### Governance

- **Every parameter declares the syntax it accepts.** That is what lets [[Macro Expansion]] report a
  mismatched argument against the *call* rather than against a matcher, and what tells it which
  identifiers a body introduced. A macro system without typed parameters reports its failures in
  terms the caller never wrote.
- The kind vocabulary is closed — `expr`, `ident`, `block` — and a name outside it is `E1045` at the
  declaration. A misspelling caught here is a declaration that never existed; caught later it is a
  parameter that silently accepts nothing.
- A macro body is one expression. A block is an expression, so a macro expanding to several
  statements writes them in braces and needs no second body form. The `=` is required for every
  other body, which keeps `macro f(x: expr) { ... }` and `macro f(x: expr) = ...` from being two
  spellings of one thing.
- Parameter iteration is bounded by required token progress and stops when [[Parser State]]'s shared
  nesting budget is exhausted, so a hostile parameter list cannot loop or cascade.
- A trailing comma ends the list rather than admitting an empty parameter, matching every other
  comma-separated form in [[grammar/pudu]].

### Linkage

- **Requires:** [[Parser State]], [[Parser Expression]], [[Parser Block]], [[Parser Name]],
  [[Syntax Tree]], [[Token]].
- **Consumed by:** [[Parser Declaration]].

## Algorithm

Require `macro` and a value identifier, then a parenthesised parameter list where each entry is a
name, a `:`, and a closed kind keyword. Read the body as a block when one opens, and otherwise
require `=` and parse a single expression. Merge the keyword-to-body span.

## Negative Logic (Prohibited Paths)

- No expansion, hygiene, or arity checking — those are [[Macro Expansion]]'s, and doing any of them
  here would put the same rule in two phases.
- No open kind vocabulary. A kind that could be anything is a parameter that constrains nothing.
- No repetition syntax. [[Macro Design]] records why it stays open: `Array` values and compile-time
  functions may already cover what repetition exists for, and a syntax added first is the one every
  use is then forced through.

## Grill Log

- **Q:** Why type the parameters at all, when most macro systems match on token trees? **A:** So a
  bad call is reported where it was written. _Rationale:_ a matcher failure names the matcher, which
  the caller did not write and often cannot read. _Rejected:_ untyped token-tree matching.
- **Q:** Why is a block body spelled without `=`? **A:** Because it is the one body that already has
  a delimiter. _Rationale:_ `macro f(x: expr) = { ... }` and `macro f(x: expr) { ... }` would
  otherwise both be legal and identical, and the formatter would have to choose. _Rejected:_
  requiring `=` everywhere; admitting both.

## Referenced by

[[src/Pudu/Frontend/Parser/Declaration/_MOC]] · [[Parser Declaration]] · [[Macro Expansion]] · [[grammar/pudu]]
