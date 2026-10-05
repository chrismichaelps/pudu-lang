---
type: module
path: "test/Pudu/Frontend/ParserDeriveSpec.hs"
fidelity: Active
subsystem: "[[Frontend]]"
grammar: "[[grammar/haskell]]"
tags: [module, tests, derive]
aliases: [Parser Derive Spec]
---

# Parser Derive Spec

## Purpose and interface

`parserDeriveProperties` exercises attributes, derives clauses, definitions,
requests, compile-time loops and lambda constraints through the real lexer and
parser. Assertions inspect preserved AST structure and exact diagnostic codes.

## Algorithm and edge cases

Cover every literal kind, empty arguments, misplaced attributes, contextual
identifiers, exported definitions, record/sum/alias clauses and loop bounds.
Malformed compound arguments produce one diagnostic and balanced recovery keeps
later literals and declarations. Missing closers preserve following declarations,
including at EOF. Duplicate generic entries compare nested structure without
locations; distinct argument structures remain distinct. Span assertions include
closing parentheses and leading type attributes.

## Negative logic

Do not accept a recovered tree as success without checking its diagnostics.
Do not use whole-compiler typing to test syntax or ignore lost declarations.

## Grill Log

- **Q:** How is recovery proved? **A:** Assert both the exact diagnostic list and
  the declarations after the mistake. _Rationale:_ a small diagnostic count alone
  cannot prove the parser retained subsequent code. _Rejected:_ only checking
  membership of an error code.

## Referenced by

[[src/Pudu/Frontend/_MOC]] · [[Parser Derive Declaration]] · [[Repository Test Runner]]
