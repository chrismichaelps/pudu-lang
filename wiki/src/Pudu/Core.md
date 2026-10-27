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
  , coreModuleEntry :: !Text
  , coreModuleFunctions :: ![CoreFunction]
  }

data CoreFunction = CoreFunction
  { coreFunctionName :: !Text
  , coreFunctionParameters :: ![CoreParameter]
  , coreFunctionResult :: !CoreType
  , coreFunctionBody :: !CoreBlock
  }

data CoreParameter = CoreParameter
  { coreParameterLocal :: !CoreLocal
  , coreParameterSpan :: !Span
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
  | CoreIf !CoreExpression !CoreBlock !(Maybe CoreExpression)
  | CoreReturn !(Maybe CoreExpression)
  | CoreBreak !CoreLoopId !(Maybe CoreExpression)
  | CoreContinue !CoreLoopId

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
  | CoreComplement !CoreExpression
  | CoreNot !CoreExpression
  | CoreBinary !CoreBinaryOperator !CoreExpression !CoreExpression
  | CoreDisplay !CoreExpression
  | CorePrint !CoreExpression
  | CoreCall !Text ![CoreExpression]
  | CoreOperatorFailure !Text ![CoreExpression]
  | CoreBlockValue !CoreBlock
  | CoreIfValue !CoreExpression !CoreBlock !CoreExpression
  | CoreWhileValue !CoreLoopId !CoreExpression !CoreBlock
  | CoreLoopValue !CoreLoopId !CoreBlock

data CoreBinaryOperator
  = CoreAdd | CoreSubtract | CoreMultiply | CoreDivide | CoreRemainder
  | CoreBitAnd | CoreBitOr | CoreBitXor | CoreShiftLeft | CoreShiftRight
  | CoreWrapAdd | CoreWrapSubtract | CoreWrapMultiply
  | CoreSaturateAdd | CoreSaturateSubtract | CoreSaturateMultiply
  | CoreLess | CoreLessOrEqual | CoreGreater | CoreGreaterOrEqual
  | CoreEqual | CoreNotEqual | CoreAnd | CoreOr

newtype CoreLoopId = CoreLoopId Int
data CoreType = CoreIntegerType !IntegerKind | CoreBoolType | CoreTextType | CoreUnitType | CoreNeverType
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
  assignment, `if` without else, `while` — so a discarded value is
  typed, never guessed. `CorePrint` uses this effect representation only in discarded positions; lowering refuses its Result escaping into a native return.
- `CoreReturn` is a statement, not an expression: a return is control flow and
  the interpreter treats it that way, so nothing downstream has to reason
  about a value that never arrives.
- `CoreCall` names its callee and carries its arguments in source order:
  argument evaluation order is the evaluator's left-to-right order, so the
  emitter must sequence them itself rather than lean on C's unspecified order.
  The callee is a name because function symbols are name-derived and unique per
  module; the emitter resolves it once, the way it resolves every local.
- `coreModuleEntry` names the function the process enters: the emitter writes
  its C `main` from this field rather than from a hard-coded `"main"`, so the
  entry vocabulary stays the caller's decision all the way to code generation.
- Core preserves required operand order and control effects. Target calling
  conventions and C statement sequencing belong to [[Backend Emit]].

## Negative Logic (Prohibited Paths)

- No unresolved names, no sugar (`if let`, patterns, ranges), no implicit
  conversions, no target types or rendered diagnostic objects. Operator refusal
  messages are semantic payload; source excerpts are carried only by spans.
- No partial fields: a `CoreIfValue` without an else is unrepresentable, so
  the emitter cannot meet a branch it has no code for.

## Dependencies and consumers

Requires [[Source]] spans, [[Integer Literal]] kinds and [[Float Literal]] widths only. Consumed by
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
- **Q:** Why is `CoreCall` a callee name rather than a function identity?
  **A:** Function symbols are already name-derived (`pudu_fn_<encoded-name>`) and
  module function names are unique, so a second identity space would exist
  only to be mapped back to the name at emission. _Rejected:_ numeric function
  ids in the IR.
- **Q:** Why does the module carry its entry name? **A:** The emitter writes a
  C `main` and must call something; leaving `"main"` hard-coded in emission
  would make the entry vocabulary a code-generation constant instead of the
  caller's decision it already is in lowering and evaluation. _Rejected:_ a
  literal entry symbol in [[Backend Emit]].

## Referenced by

[[src/Pudu/_MOC]] · [[src/Pudu/Backend/_MOC]] · [[Core IR]] · [[Compiler Lower]] ·
[[Backend Emit]] · [[Backend]] · [[ADR-0002-compiler-pipeline]]

## Resolved loop control (#489)

CoreLoopId is a function-local numeric identity, resolved before emission. While and loop are expression forms; break/continue are statement transfers with explicit destinations. While is unit; loop is the supported type carried by its breaks, or Never without a local break. CoreNeverType records divergent blocks and merges with reachable branch values. Break operands retain source ordering, including nested transfers. Resolved Grill Log: explicit numeric targets preserve nested source-label shadowing and condition scope without coupling Core to C labels or parser syntax.


## Explicit scalar runtime refusals (#494)

Add CoreOperatorFailure Text [CoreExpression] to CoreExpressionShape. It carries an interpreter operator-refusal message and ordered operands; its expression type is CoreNeverType. The enclosing span is the whole operation. This is an explicit semantic trap, not an emitted C error or diagnostic rendering object. No new imports or target ABI data.

Resolved Grill Log: reproduce actual interpreter dispatch, canonical settled kinds, operand order and diagnostic spans; never classify print Result as unit or implement invalid operations as integer arithmetic. No syntax/inference change.

## Platform Int operators (#495)

Add CoreComplement and binary CoreBitAnd/Or/Xor, CoreShiftLeft/Right, CoreWrapAdd/Subtract/Multiply, CoreSaturateAdd/Subtract/Multiply. All operate on platform Int; shifts carry the whole-operation span and can refuse E7004. Preserve the existing Bool logical operators as distinct forms.

Resolved Grill Log: use defined unsigned bit patterns, validate counts before shifts, and prove signed arithmetic bounds before evaluation. The actual interpreter determines results, effect order and exact diagnostic vocabulary. No syntax or type-inference change.

## Exact native integer values (#498)

CoreIntegerLiteral retains its mathematical Integer payload and canonical kind;
it is not a signed C bit pattern. Accepted deferred platform Int magnitudes
through positive 2^63 now survive blocks/locals/calls. [[Backend Integer Value]]
implements their private carrier; operation policies still check/wrap/clamp at
the interpreter's boundaries. No Core type vocabulary or source kind changes.
Resolved Grill Log: carry exact values through Core and keep target encoding
in the backend, rather than narrowing a literal while constructing the IR.

## Floating values (#512)

Add `CoreFloatType !FloatWidth` and `CoreFloatLiteral !FloatWidth !Word64`.
The payload is the binary64 encoding [[Float Literal]] produced while parsing,
already narrowed through binary32 for `f32`, so nothing downstream reads
decimal text again. `coreTypeName` answers `Float32`/`Float64`. Arithmetic
reuses `CoreAdd`/`CoreSubtract`/`CoreMultiply`/`CoreDivide`, comparisons reuse
the six ordering/equality operators and negation reuses `CoreNegate`; the
operand type selects the floating helper, as it already selects the integer
kind. No new operator vocabulary.

Resolved Grill Log: carry bits rather than `Double` so Core equality is
bit equality (NaN payloads and signed zero stay distinct) and so the C side
writes a hexadecimal constant instead of a second decimal conversion.
_Rejected:_ a `Double` payload, and separate floating operator constructors.

## Owned text (#515)

`CoreTextType` is now an ordinary value type: locals, parameters, results,
branch and loop values may carry it. `CoreDisplay` yields text for every
native value type, and `CoreShow` yields `renderValue` text (Str gains its
quotes and escapes; scalars render as `display` does). `CoreAdd` on two Str
operands is concatenation, and the ordering/equality operators compare text.
The earlier rule that text may only appear as a `CorePrint` argument is
retired.

Resolved Grill Log: text joins Core as a type rather than a new family of
nodes, the same way floats reused the operator vocabulary. _Rejected:_
separate concatenation and comparison constructors.
