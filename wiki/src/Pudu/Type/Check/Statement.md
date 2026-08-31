---
type: module
path: "@root/src/Pudu/Type/Check/Statement.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.6
depth_status: DEEP
coupling: 5.0
interface_stability: 0.8
tags: [module, deep]
aliases: [Type Check Statement]
---

# Type Check Statement

## Purpose

Decide what a block and the statements in it mean, and what checking a value
*against* an expected type does.

## Interface

```haskell
data StatementNeeds = StatementNeeds
  { statementExpression  :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
  , statementDeclaration :: DeclaredTypes -> Located Declaration -> Checker ()
  , statementFunction    :: FunctionRole -> DeclaredTypes -> [Text] -> [(Text, [NominalId])] -> Maybe NominalId -> Function -> Checker ()
  }

checkBlock        :: StatementNeeds -> DeclaredTypes -> [Text] -> Located Block -> Checker Type
checkAgainst      :: StatementNeeds -> DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
checkBlockAgainst :: StatementNeeds -> DeclaredTypes -> [Text] -> Type -> Located Block -> Checker Type
checkMember       :: StatementNeeds -> DeclaredTypes -> [Text] -> [(Text, [NominalId])] -> Maybe NominalId -> Located Function -> Checker ()
```

### Governance

- A direct empty Set literal is inspected after its binding or expression statement has received
  all available local constraints. If its element variable remains unresolved, `E3037` asks for an
  explicit `Set[T]`; a contextual literal is left alone.

- A statement holds expressions, may declare something, and a function declared
  inside one is checked as a function. All three reach statements again, which
  is why they **arrive as a record rather than being imported**.
- **Checking against an expected type is here rather than with expressions**,
  because what it does is push the expectation into the *constructs* — the arms
  of a match, the branches of an `if`, the result of a block — and each of those
  is a statement's business. Only a `dynamic` expectation changes an outcome, so
  anything else is left to inference.
- A pushed expectation reaches both present `if let` branches. A form without `else` falls back to
  ordinary inference so its required unit result is still checked. Its subject is read through a borrow as for
  `match`, while the successful pattern binds only around the then block; this preserves dynamic
  widening without leaking the binding into else.
- `checkAgainst` returns what `unify` produced rather than the inferred type, so
  a failure is reported once: the caller unifies again against the same
  expectation and `ErrorType` absorbs there.
- A block's type is its result expression. When it has none, a final direct
  `return`, `break`, or `continue` makes the block `Never`; every other ending
  makes it unit. This is deliberately structural at the block boundary: a
  nested conditional that can fall through does not make the containing block
  diverge. A statement
  whose value is discarded is reported (`W3002`) only where discarding it is
  the mistake — a method that answers with a new value rather than changing its
  receiver.

### Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Unify]], [[Type Check Rule]], [[Type Check Call]],
  [[Type Check Pattern]], [[Type Check Safety]], [[Type Exhaust]].
- **Consumed by:** [[Type Check]], which ties it together with
  [[Type Check Expression]].

## Algorithm

Walk the statements in order, then the result. A binding forms its annotation
and unifies the value against it; a declaration is handed back through the
record. If there is no result, classify the final statement before unifying the
block with an expected type. A direct control transfer supplies `Never`, while
an ordinary resultless ending supplies unit. `let … else` consequently asks the
fallback's inferred type whether it diverges and needs no second structural
exception.

## Negative Logic (Prohibited Paths)

- No importing [[Type Check]] or [[Type Check Expression]] — the record is the
  path back, and importing either would make the cycle real.

## Grill Log

- **Q:** Diagnose `#{}` while first inferring it? **A:** No. _Rationale:_ inference has not yet seen
  the annotation or surrounding call/return constraint. The statement boundary is the earliest
  point that can distinguish missing context from context not yet applied. _Rejected:_ eager
  expression-level failure.

- **Q:** Why does this need three things rather than the two an expression
  needs? **A:** Because a statement can declare. _Rationale:_ a `let` is a
  statement and a `fn` inside a block is a declaration checked as a function, so
  both directions out of a statement are real; an expression only ever reaches
  blocks and bindings. _Rejected:_ handling declarations here, which would put
  the same rule in two modules.
- **Q:** Why not type every block without a result expression as unit? **A:** A
  direct control-transfer ending is `Never`, the same type the transfer has at
  its valid boundary. _Rationale:_ such a block cannot produce unit, and calling
  it unit rejects valid joins such as a returning match arm beside an `Int` arm.
  The final statement is inspected only when the parser supplied no result, so
  a genuinely fallthrough block remains unit. _Rejected:_ special-casing each
  consumer such as `let … else`, because it leaves `if`, `match`, and contextual
  checking with contradictory answers. Resolved for issue #146.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]] · [[Type Check Expression]]
