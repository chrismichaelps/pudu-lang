---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Type/Check/Attribute.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.4
depth_status: MEDIUM
coupling: 2.0
interface_stability: 0.8
tags: [module, medium]
aliases: [Type Check Attribute]
---

# Type Check Attribute

## Purpose

Check declared attributes for [[Type Check]]. `checkAttributes` requires every attribute on a type, field or variant to name a declared attribute, with arguments matching in count and literal kind. Inside a derive definition it also requires every `has` or `attributeOr` read to name a declared attribute. The declarations come from `declaredAttributes` in [[Type Env]].

## Interface

`checkAttributes` takes one module's declarations and the program's `declaredAttributes` map, and answers its diagnostics.

### Governance

- An undeclared attribute is `E3104` "unknown attribute @name", with the nearest declared name as help.
- An argument count or literal kind mismatch is `E3105` at the argument.
- Inside a derive definition, `has("name")` or `attributeOr("name", fallback)` on an undeclared name is `E3104` at the name.
- Literal kinds are `Str`, `Int`, `Float` (an integer literal is accepted), `Decimal`, `Bool` and `Char`.

## Invariants

- Declarations are program-wide: the map is the union over the loaded modules and the exported declarations of the program's interfaces.
- A conflicting redeclaration is reported by formation (`E3106`); this check reads the earlier parameters.

## Negative Logic (Prohibited Paths)

- Does not check attribute values beyond their literal kind.
- Does not check attributes written on an attribute declaration; that is `E1064` in the declaration checker.
- Does not warn about declared attributes that no derive reads.

## Algorithm

For each attribute on a declaration, look up its name in `declaredAttributes`. If absent, report `E3104` with the nearest declared name. If present, compare argument count, then each argument's literal kind against the declared parameter. Derive bodies are scanned for `has` and `attributeOr` calls whose first argument is a string literal, and each literal is looked up the same way.

## Edge Cases

- A misspelled attribute on a field gets the nearest name as its help; a fixture pins this (see [[src/test-fixtures/attributes/UnknownAttribute]]).
- A read whose name is not a literal cannot be checked here and is left to evaluation.

## Depth

Shallow: one lookup per use, one comparison per argument.

## Grill Log

- **Q:** Why are declarations visible across the whole program? **A:** A derive's attributes are written in modules that import the derive's trait, not its declaring module; every module the program loads is in scope, which matches how derives themselves are found.
- **Q:** Why suggest the nearest name? **A:** A misspelled attribute is the common case; naming the intended one fixes it at once.

## Referenced by

[[Type Check]] · [[Type Env]] · [[Type Formation]] · [[Derive Design]] · [[grammar/pudu]] · [[src/test-fixtures/attributes/UnknownAttribute]]
