---
type: module
path: "@root/src/Pudu/Type/Check/Expression.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: DEEP
coupling: 6.0
interface_stability: 0.75
tags: [module, deep]
aliases: [Type Check Expression]
---

# Type Check Expression

Compile-time loop bounds validate through [[Type Check Bound]] under their fresh
rigid field parameters. Invalid bounds withhold the loop body while retaining
source/element checks. Resolved Grill Log: a malformed capability cannot become
an abstract assumption merely because no concrete request exists yet.

## Purpose

Decide what an expression's type is.

In derive checking, a call whose callee is a field callback is checked by `checkBuildCall`. A generated multi-segment name naming a canonical variant is typed as that variant's constructor even when the defining module does not import its owner.

## Interface

```haskell
data CheckSurroundings = CheckSurroundings
  { aroundBlock     :: DeclaredTypes -> [Text] -> Located Block -> Checker Type
  , aroundAgainst   :: DeclaredTypes -> [Text] -> Type -> Located Expression -> Checker Type
  , aroundParameter :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
  }

checkExpression :: CheckSurroundings -> DeclaredTypes -> [Text] -> Located Expression -> Checker Type
```

### Governance

- An expression contains blocks and blocks contain expressions, so **one of the
  two directions has to be an argument rather than an import**. This is that
  direction — the same shape [[Parser Expression]], [[Type Check Call]], and
  [[Type Check Record]] already use for their own recursion.
- The record carries exactly three things, and each is decided where statements
  and declarations are: a block's type is the statements in it, a value checked
  *against* an expected type may push that type inward, and a function literal
  binds parameters. Nothing else was needed, which is why nothing else is there.
- **Every expression's type is recorded**, both for a use of a name and for the
  name that introduces one. An editor asked about `text` in `let text = "hello"`
  has to be answered about `text`, and a reader points at the place a name is
  introduced at least as often as at a use of it.
- A literal is given the kind inference settles on rather than the kind it was
  spelled, which is what makes a declared width hold for a value that did not
  come from a suffixed literal.
- `if let` checks its subject once, looks through a borrow exactly as `match` does, binds the pattern
  in a fresh then-branch type scope, and unifies its branch values exactly as ordinary `if` does.
  Without else it has unit type. No separate pattern checker exists for this form.
- An assignment's target, a `&mut` argument, a call's loans, a captured name, and a type application's
  arguments are handed to [[Check Place]]; a call admits its own `&mut` arguments before checking them
  and compares its loans with the callee's parameter types before unifying them.
- A non-empty `SetExpression` unifies all member types and produces `Set[T]`. The empty form creates
  one local inference variable; expected-type contexts may determine it before a statement boundary.
- A compile-time loop that reaches checking is `E3090` outside a derive definition, where
  instantiation has nothing to unroll. Inside one it checks generically: the `where` subjects bind
  rigid, the element binds at its ascribed type, and the body checks under both.
  Its source checks before the element is bound. Ordinary sources must have
  Array[Element] type; canonical Std.Meta.Fields[T] and Variants[T] validate
  their descriptor and owner through [[Type Check Reflection]]. An unbound F in
  canonical Field[T, F] binds rigidly even when no capability is required.
  The source check is mandatory even in an unused derive. New rigid subjects
  are deduplicated, enclosing identities and bounds persist, and local obligations
  discharge before those bounds are restored. The binder retains error poison on
  a source mismatch so body uses do not repeat the same defect.

### Linkage

- **Requires:** [[Type Env]], [[Type Formation]], [[Type Unify]], [[Type Check Rule]],
  [[Type Check Call]], [[Type Check Record]], [[Type Check Method]],
  [[Type Check Pattern]], [[Type Check Safety]], [[Type Check Iteration]],
  [[Type Exhaust]], [[Type Check Expression Control]].
- **Consumed by:** [[Type Check]], which ties the knot.

## Algorithm

Dispatch on the expression, ask the closed rules in [[Type Check Rule]] for the
ones with a fixed shape, and reach blocks, pushed-down types, and parameters
through the record.

## Negative Logic (Prohibited Paths)

- No declaration or statement checking, and no importing [[Type Check]] — the
  record is the path back, and importing would make the cycle real.
- No deciding what a declaration owes about itself; that is [[Type Check Signature]],
  which runs before any body is looked at.

## Grill Log

- **Q:** Why a record rather than moving blocks here too? **A:** Because that
  trades one module over the limit for another. _Rationale:_ statements, blocks,
  and pushed-down checking are about six hundred lines together with expressions,
  so the cut has to fall between them, and then something has to cross the gap.
  _Rejected:_ one large module; an `hs-boot` file, which hides the cycle rather
  than stating it.
- **Q:** Why does the record carry `aroundParameter`? **A:** Because a function
  literal binds its parameters and a parameter's type is formed where
  declarations are. _Rationale:_ it is the only part of a lambda that is not an
  expression. _Rejected:_ duplicating the binding here, which would put one rule
  in two places.
- **Q:** Default an empty Set's element type here? **A:** No. _Rationale:_ expression inference must
  first let annotations, arguments, and returns constrain it; a boundary diagnostic is more honest
  than a type chosen without evidence. _Rejected:_ `Int`, unit, or an implicit bottom element.
- **Q:** Why decompose match arms, lambdas, and loop control into `Pudu.Type.Check.Expression.Control`?
  **A:** To satisfy file length contracts (< 500 lines) and isolate sub-expression scope and branch checking
  from expression AST dispatch. _Rationale:_ arms, closures, and loops represent distinct control-flow boundaries
  that can be checked via parameterised runners without cyclic dependencies.
- **Q:** Require the defining module to import every target? **A:** No; generated constructions name owners canonically.

## Referenced by

[[src/Pudu/Type/_MOC]] · [[Type Check]]

## Complete trait evidence

Compile-time loop where bounds are formed under enclosing and fresh loop-local parameters and retain their full trait applications.

Resolved Grill Log: fields bounded by a generic trait must not receive arbitrary trait arguments during generic derive checking.

## Static field owner selection (#457)

Delegate explicit method applications on a selected nominal owner to [[Type Check Call]] before
the ordinary dotted-name application path. That path retains existing type argument count, kind,
bound and inference checks. Resolved Grill Log: method-local arguments cannot overwrite the owner's
implementation selection; the settled full selection still uses ordinary literal elaboration.
