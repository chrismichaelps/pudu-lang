---
type: module
path: "@root/src/Pudu/Core.hs"
fidelity: Active
domain: "[[Core IR]]"
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, ir]
aliases: [Pudu Core IR Module, Core Module]
---

# Pudu Core

## Purpose and interface

The concrete Haskell form of [[Core IR]]: the checked, name-resolved program
the native backend consumes, with every statement and expression carrying the
source span it came from. It is a domain module — no IO, no diagnostics, no
rendering — so both [[Compiler Lower]] and [[Backend Emit]] share one
vocabulary and neither invents its own.

```haskell
data CoreModule = CoreModule
  { coreModuleName :: !Text
  , coreModuleFunctions :: ![CoreFunction]
  }

data CoreFunction = CoreFunction
  { coreFunctionName :: !Text
  , coreFunctionParameters :: ![CoreParameter]
  , coreFunctionResult :: !CoreType
  , coreFunctionBody :: !CoreBlock
  }

data CoreBlock = CoreBlock
  { coreBlockStatements :: ![CoreStatement]
  , coreBlockResult :: !(Maybe CoreExpression)
  }

data CoreLocal = CoreLocal
  { coreLocalId :: !Int, coreLocalName :: !Text, coreLocalType :: !CoreType }

data CoreStatement = CoreStatement
  { coreStatementSpan :: !Span, coreStatementShape :: !CoreStatementShape }

data CoreStatementShape
  = CoreDeclare !CoreLocal !CoreExpression
  | CoreAssign !CoreLocal !CoreExpression
  | CoreEvaluate !CoreExpression
  | CoreWhile !CoreExpression !CoreBlock
  | CoreIf !CoreExpression !CoreBlock !(Maybe CoreExpression)
  | CoreReturn !(Maybe CoreExpression)

data CoreExpression = CoreExpression
  { coreExpressionSpan :: !Span
  , coreExpressionType :: !CoreType
  , coreExpressionShape :: !CoreExpressionShape
  }

data CoreExpressionShape
  = CoreIntegerLiteral !IntegerKind !Integer
  | CoreBoolLiteral !Bool
  | CoreTextLiteral !Text
  | CoreReadLocal !CoreLocal
  | CoreNegate !CoreExpression
  | CoreNot !CoreExpression
  | CoreBinary !CoreBinaryOperator !CoreExpression !CoreExpression
  | CoreDisplay !CoreExpression
  | CorePrint !CoreExpression
  | CoreBlockValue !CoreBlock
  | CoreIfValue !CoreExpression !CoreBlock !CoreExpression

data CoreBinaryOperator
  = CoreAdd | CoreSubtract | CoreMultiply | CoreDivide | CoreRemainder
  | CoreLess | CoreLessOrEqual | CoreGreater | CoreGreaterOrEqual
  | CoreEqual | CoreNotEqual | CoreAnd | CoreOr

data CoreType = CoreIntegerType !IntegerKind | CoreBoolType | CoreTextType | CoreUnitType
coreTypeName :: CoreType -> Text
```

## Governance

- Positions are uniform: every statement and expression is a record whose
  first field is its span, so no pass has to guess where a node came from and
  no constructor is special.
- Every expression carries its type, computed once during lowering, so helper
  selection (checked arithmetic, printer choice) is a lookup rather than a
  second type pass.
- A local carries its identity, its source name, and its type together, so the
  emitter never re-derives any of the three and shadowing is represented by
  distinct identities rather than distinct names.
- `CoreTextType` values (`CoreTextLiteral`, `CoreDisplay`) exist only as
  `CorePrint` arguments; [[Compiler Lower]] refuses every other position, so
  the emitter may rely on that discipline rather than re-check it.
- `CoreUnitType` is the type of effects the interpreter also types as Unit —
  `print`, assignment, `if` without else, `while` — so a discarded value is
  typed, never guessed.
- `CoreReturn` is a statement, not an expression: a return is control flow and
  the interpreter treats it that way, so nothing downstream has to reason
  about a value that never arrives.
- The module is deliberately silent about execution: no evaluation order, no
  calling convention, no C. Those are [[Backend Emit]]'s contract.

## Negative Logic (Prohibited Paths)

- No unresolved names, no sugar (`if let`, patterns, ranges), no implicit
  conversions, no target types, no diagnostics, no source text beyond spans.
- No partial fields: a `CoreIfValue` without an else is unrepresentable, so
  the emitter cannot meet a branch it has no code for.

## Dependencies and consumers

Requires [[Source]] spans and [[Integer Literal]] kinds only. Consumed by
[[Compiler Lower]] (produces it) and [[Backend Emit]] (consumes it). It
imports no compiler, evaluator, or frontend module; the backend boundary of
[[ADR-0002-compiler-pipeline]] passes through it.

## Grill Log

- **Q:** Why a new IR instead of emitting C from the checked tree? **A:** The
  tree is a parser artefact: it keeps sugar, patterns, and syntax that the
  backend must never reinterpret, and [[ADR-0002-compiler-pipeline]] fixes
  Core IR as the shared checked representation. Lowering is the one place
  allowed to refuse what it cannot represent. _Rejected:_ backend imports of
  frontend syntax, and target-shaped nodes in the tree.
- **Q:** Why records with span-first fields instead of a `Located` wrapper?
  **A:** [[grammar/haskell]] forbids ad-hoc position fields; a record whose
  every node has the same first field is uniform, total, and cheap to pattern
  match, and it keeps `Located` a frontend concern. _Rejected:_ frontend
  `Located` reuse in the backend.
- **Q:** Why is `CoreReturn` a statement when `if` has a value form? **A:**
  Pudu returns from a function, not from an expression; the evaluator treats a
  return as a terminating statement and the C emitter maps it to `return`.
  Giving it a value type would invent a semantics the interpreter does not
  have. _Rejected:_ expression-typed return.
- **Q:** Why carry `CoreLocal` (id, name, type) in every read and write? **A:**
  Names are ambiguous under shadowing and types are needed to choose checked
  helpers; resolving once at lowering keeps the emitter a translation, not a
  second resolver. _Rejected:_ name-keyed maps rebuilt per pass.

## Referenced by

[[src/Pudu/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Core IR]] · [[Compiler Lower]] ·
[[Backend Emit]] · [[Backend]] · [[ADR-0002-compiler-pipeline]]
