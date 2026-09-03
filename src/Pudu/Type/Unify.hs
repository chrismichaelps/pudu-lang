{-| @Type.Unify.Module — makes two types equal or explains why not -}
module Pudu.Type.Unify
  ( expect
  , unify
  , zonk
  ) where

import Data.Text (Text)
import Pudu.Source (Span)
import Control.Monad (unless)
import Pudu.Type.Env (Checker, implementsTrait, report, reportedAt, resolveVariable, setVariable)
import Pudu.Type.Value (Type (..), TypeVar, nominalKey, nominalName, renderType)

{-| Unify two types, reporting `E3001` when they cannot be made equal.

    `ErrorType` absorbs: a type that already failed unifies with anything, so
    one mistake produces one diagnostic instead of a cascade. `Never` unifies
    with everything, which is exactly the rule [[architecture/SEMANTICS]] gives
    it for unreachable control-flow joins. -}
unify :: Span -> Type -> Type -> Checker Type
unify spanValue expected actual = do
  left <- shallow expected
  right <- shallow actual
  case (left, right) of
    (ErrorType, _) -> pure ErrorType
    (_, ErrorType) -> pure ErrorType
    (NeverType, other) -> pure other
    (other, NeverType) -> pure other
    (VariableType variable, other) -> bindVariable spanValue variable other
    (other, VariableType variable) -> bindVariable spanValue variable other
    (NominalType leftName leftArgs, NominalType rightName rightArgs)
      | leftName == rightName && length leftArgs == length rightArgs ->
          NominalType leftName <$> unifyAll spanValue leftArgs rightArgs
    {-| Two applications agree when their constructors agree and their arguments
        do, pairwise. Only equal arities are compared: a constructor is never
        split across an application boundary, which is what keeps solving these
        terminating and keeps a mismatch about two constructors rather than two
        unsolved shapes. -}
    (AppliedType leftHead leftArgs, AppliedType rightHead rightArgs)
      | length leftArgs == length rightArgs -> do
          solvedHead <- unify spanValue leftHead rightHead
          AppliedType solvedHead <$> unifyAll spanValue leftArgs rightArgs
    {-| A constructor variable meets a named constructor carrying at least as
        many arguments. The variable takes the constructor with the arguments it
        does not consume, and the rest are matched pairwise. -}
    (AppliedType leftHead leftArgs, NominalType rightName rightArgs)
      | length rightArgs >= length leftArgs -> do
          let (kept, matched) = splitAt (length rightArgs - length leftArgs) rightArgs
          _ <- unify spanValue leftHead (NominalType rightName kept)
          NominalType rightName . (kept <>) <$> unifyAll spanValue leftArgs matched
    (NominalType leftName leftArgs, AppliedType rightHead rightArgs)
      | length leftArgs >= length rightArgs -> do
          let (kept, matched) = splitAt (length leftArgs - length rightArgs) leftArgs
          _ <- unify spanValue (NominalType leftName kept) rightHead
          NominalType leftName . (kept <>) <$> unifyAll spanValue matched rightArgs
    (TupleTypeValue leftMembers, TupleTypeValue rightMembers)
      | length leftMembers == length rightMembers ->
          TupleTypeValue <$> unifyAll spanValue leftMembers rightMembers
    (FunctionTypeValue leftAsync leftInputs leftResult, FunctionTypeValue rightAsync rightInputs rightResult)
      | leftAsync == rightAsync && length leftInputs == length rightInputs -> do
          inputs <- unifyAll spanValue leftInputs rightInputs
          result <- unify spanValue leftResult rightResult
          pure (FunctionTypeValue leftAsync inputs result)
    {-| Two restricted functions agree when they require the same abilities and
        the functions underneath them agree.

        Exactly the same set, not a subset either way. A function requiring less
        cannot stand where one requiring more is expected, because the caller
        was written to grant what the expected type asked for and would grant
        more than it needs; and one requiring more certainly cannot stand where
        less is expected, which is the laundering this exists to stop. Whether a
        set should be allowed to narrow is the question capability variables
        answer, and [[ADR-0009 Effects in the Type]] is where that is settled. -}
    (RestrictedType leftCapabilities leftInner, RestrictedType rightCapabilities rightInner)
      | leftCapabilities == rightCapabilities ->
          RestrictedType leftCapabilities <$> unify spanValue leftInner rightInner
    (ReferenceTypeValue leftMutable leftTarget, ReferenceTypeValue rightMutable rightTarget)
      | leftMutable == rightMutable ->
          ReferenceTypeValue leftMutable <$> unify spanValue leftTarget rightTarget
    (RigidType leftName, RigidType rightName)
      | leftName == rightName -> pure left
    (UnitTypeValue, UnitTypeValue) -> pure UnitTypeValue
    (DynamicTypeValue leftTrait, DynamicTypeValue rightTrait)
      | leftTrait == rightTrait -> pure left
    {-| A concrete type widens into a dynamic one when it implements the trait.

        This is the one direction the rule runs, and `unify` is already
        oriented — its message names the expected type first — so a widening
        can only happen where a `dynamic` was asked for. The reverse would be a
        narrowing, which needs a match, not an assignment. -}
    (DynamicTypeValue traitIdentity, NominalType concrete _) -> do
      implements <- implementsTrait concrete traitIdentity
      if implements
        then pure left
        else do
          seen <- reportedAt spanValue "E3032"
          unless seen $
            report "E3032" spanValue
              (nominalName concrete <> " does not implement " <> nominalName traitIdentity)
              ( Just
                  ( "implement it for this type, or use a type that does; a dynamic "
                      <> nominalName traitIdentity
                      <> " holds only values that implement it"
                  )
              )
          pure ErrorType
    _ -> mismatch spanValue left right

{-| Check an actual type against an expected one. The message names the
    expected type first, because that is the one the reader declared. -}
expect :: Span -> Type -> Type -> Checker Type
expect = unify

unifyAll :: Span -> [Type] -> [Type] -> Checker [Type]
unifyAll spanValue expected actual = case (expected, actual) of
  ([], []) -> pure []
  (left : leftRest, right : rightRest) -> do
    unified <- unify spanValue left right
    rest <- unifyAll spanValue leftRest rightRest
    pure (unified : rest)
  _ -> pure []

{-| Bind an inference variable, refusing a binding that would make the type
    contain itself. -}
bindVariable :: Span -> TypeVar -> Type -> Checker Type
bindVariable spanValue variable candidate = case candidate of
  VariableType other | other == variable -> pure (VariableType variable)
  _ -> do
    occurs <- occursIn variable candidate
    if occurs
      then do
        rendered <- renderResolved candidate
        report "E3002" spanValue ("type would contain itself: " <> rendered)
          (Just "annotate the binding or the signature to break the cycle")
        pure ErrorType
      else do
        setVariable variable candidate
        pure candidate

occursIn :: TypeVar -> Type -> Checker Bool
occursIn variable candidate = do
  resolved <- shallow candidate
  case resolved of
    VariableType other -> pure (other == variable)
    NominalType _ arguments -> anyOccurs arguments
    AppliedType head' arguments -> do
      inHead <- occursIn variable head'
      if inHead then pure True else anyOccurs arguments
    TupleTypeValue members -> anyOccurs members
    FunctionTypeValue _ inputs result -> do
      inInputs <- anyOccurs inputs
      if inInputs then pure True else occursIn variable result
    RestrictedType _ inner -> occursIn variable inner
    ReferenceTypeValue _ target -> occursIn variable target
    _ -> pure False
 where
  anyOccurs types = case types of
    [] -> pure False
    first : rest -> do
      found <- occursIn variable first
      if found then pure True else anyOccurs rest

mismatch :: Span -> Type -> Type -> Checker Type
mismatch spanValue expected actual = do
  resolvedExpected <- zonk expected
  resolvedActual <- zonk actual
  let (expectedText, actualText) = collisionAware resolvedExpected resolvedActual
  report "E3001" spanValue ("expected " <> expectedText <> ", found " <> actualText)
    (borrowGuidance resolvedExpected resolvedActual)
  pure ErrorType

{-| When only a borrow separates the two types, the help names the operator that
    closes the gap. Pudu converts in neither direction on its own, so the reader
    needs to know which way to write it. -}
borrowGuidance :: Type -> Type -> Maybe Text
borrowGuidance expected actual = case (expected, actual) of
  (_, ReferenceTypeValue _ target)
    | sameShape expected target -> Just "dereference the borrow with * to read the value"
  (ReferenceTypeValue _ target, _)
    | sameShape target actual -> Just "borrow the value with & to pass a reference"
  _ -> Just "change the value, or change the declared type it must match"

{-| Compare without inference variables resolved further: the two types have
    already been zonked, so structural equality is the honest test. -}
sameShape :: Type -> Type -> Bool
sameShape = (==)

collisionAware :: Type -> Type -> (Text, Text)
collisionAware expected actual = case (expected, actual) of
  (NominalType left _, NominalType right _)
    | left /= right && nominalName left == nominalName right ->
        (nominalKey left, nominalKey right)
  _ -> (renderType expected, renderType actual)

renderResolved :: Type -> Checker Text
renderResolved typeValue = renderType <$> zonk typeValue

{-| Replace every solved inference variable throughout a type. -}
zonk :: Type -> Checker Type
zonk typeValue = do
  resolved <- shallow typeValue
  case resolved of
    NominalType name arguments -> NominalType name <$> mapM zonk arguments
    {-| An application whose constructor has been solved becomes that
        constructor carrying the arguments, so what a reader is shown is the
        type itself rather than the shape it was solved through. -}
    AppliedType head' arguments -> do
      solvedHead <- zonk head'
      solvedArgs <- mapM zonk arguments
      pure $ case solvedHead of
        NominalType name existing -> NominalType name (existing <> solvedArgs)
        _ -> AppliedType solvedHead solvedArgs
    TupleTypeValue members -> TupleTypeValue <$> mapM zonk members
    FunctionTypeValue asynchronous inputs result ->
      FunctionTypeValue asynchronous <$> mapM zonk inputs <*> zonk result
    RestrictedType capabilities inner -> RestrictedType capabilities <$> zonk inner
    ReferenceTypeValue mutable target -> ReferenceTypeValue mutable <$> zonk target
    other -> pure other

{-| Follow a variable to whatever it currently stands for, one level deep. -}
shallow :: Type -> Checker Type
shallow typeValue = case typeValue of
  VariableType variable -> do
    solved <- resolveVariable variable
    case solved of
      Nothing -> pure typeValue
      Just found@(VariableType _) -> do
        {-| Point this variable at what the chain ends in.

            Solving `a` to `b` and then `b` to `c` leaves a chain, and every
            reader walked all of it. A variable per literal made the chains grow
            as a body did, so following one cost the literals before it: fifteen
            thousand asks over fifteen hundred statements became a hundred and
            twenty-eight million steps.

            Writing the end back where it was found means each link is followed
            once however many asks end in it. It is the same answer — the end of
            a chain does not change by being reached sooner — and the occurs
            check below is what says there is an end to reach. -}
        endpoint <- shallow found
        setVariable variable endpoint
        pure endpoint
      Just found -> pure found
  _ -> pure typeValue
