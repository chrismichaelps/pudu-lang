---
type: module
path: "@root/src/Pudu/Type/Check/Place.hs"
fidelity: Active
domain: "[[Pudu Type]]"
subsystem: "[[Semantics]]"
grammar: "[[grammar/haskell]]"
depth_score: 0.7
depth_status: DEEP
coupling: 5.0
interface_stability: 0.7
tags: [module, deep, semantics, ownership]
aliases: [Check Place, Type Check Place]
---

# Type Check Place

## Purpose

Decide what an assignment may write, what `&mut` may lend, and where an exclusive reference may be
written or held, as [[ADR-0022-lending-a-place]] states.

## Interface

```haskell
checkAssignment :: Text -> Located Expression -> Checker ()
admitLending :: [Located Expression] -> Checker ()
checkLent :: Span -> Located Expression -> Checker ()
checkLending :: Type -> Maybe (Located Expression) -> [Located Expression] -> [Type] -> Checker ()
checkExclusiveReceiver :: Located Expression -> Checker ()
exclusiveInput :: Type -> Checker Bool
checkParameterTypes :: Function -> Checker ()
noteUnwrittenParameters :: Function -> [Type] -> Checker ()
requireWrittenExclusive :: Checker ()
checkAnswer :: Function -> Type -> Checker ()
checkBindingType :: Maybe (Located TypeSyntax) -> Located Text -> Type -> Checker ()
checkExclusiveCapture :: Span -> NonEmpty Text -> Type -> Checker ()
checkTypeArguments :: [Located TypeSyntax] -> Checker ()
checkTypeDeclaration :: TypeDeclarationValue -> Checker ()
```

## Behaviour

- **Places.** `writable` walks the target with the types already recorded for its sub-expressions.
  A root name needs a `var` binding — the resolver's answer, read through [[Type Env]] — or, when the
  write is inside the value, an exclusive reference type. A captured root is `E3076`; a root that is
  neither is `E3078`. A field needs `mut` on its record (`E3079`), a shared reference on the way is
  `E3080`, an element needs an array, and anything else is `E3077`.
- **Lending.** A call first admits its own `&mut` arguments; `checkLent` refuses any other `&mut`
  (`E3081`) and checks an admitted one's place. `checkLending` compares each argument with the
  callee's parameter types before they are unified: an exclusive parameter takes `&mut place` or an
  exclusive reference by name (`E3081`); an exclusive reference given to a parameter of any type, to a
  callee of unknown type, or inside another value is `E3084`. Lent places — the receiver first when a
  method takes `self: &mut Self` — are compared as paths, and one inside another is `E3082`.
- **Type positions.** `misplaced` finds `&mut` anywhere but the top of a parameter type, where a
  function type written inside a type has parameters of its own (`E3083`). Parameters, results,
  binding annotations, fields, payloads, aliases, and type arguments are each checked where they are
  formed; an `async fn` parameter is refused at the top as well.
- **Kept references.** A binding, an unannotated result, or a captured name whose type holds an
  exclusive reference is `E3084`. A function literal's untyped parameter is recorded and, once its
  top-level declaration is checked, refused if inference made it exclusive (`E3083`).

Every one of these codes is reported from this module alone.

Resolved Grill Log: the rules sit in one module rather than beside each expression form so that the
place model has one statement; the expression checker only calls in. Comparing argument types before
unification is what separates a parameter declared `&mut` from a type variable that would be
instantiated to one.
