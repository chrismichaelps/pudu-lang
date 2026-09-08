{-| @Type.Check.Iteration — decides what a `for` loop's binder is -}
module Pudu.Type.Check.Iteration
  ( iterationElement
  ) where

import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , freshVariable
  , lookupOwnerVariants
  , lookupVariant
  , report
  )
import Pudu.Type.Check.Pattern (substituteRigid)
import Pudu.Type.Check.Rule
  ( instantiate
  )
import Pudu.Type.Check.Method
  ( methodScheme
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , Type (..)
  , charType
  , renderType
  )

{-| The type a `for` binds, taken from what is being iterated.

    This used to be an unconstrained fresh variable, so `for x in [1, 2, 3]`
    left `x` free and `x.length()` on a whole number passed the checker. The
    loop is the one place a binder's type is decided entirely by the value
    beside it, and deciding nothing there let every use of it through.

    A user type answers through its own `advance`, whose result shape
    `Option[(State, Item)]` is what `Std.Iter.Sequence` requires — the same
    method [[Evaluator]] calls to walk it, so the type a `for` binds is the type
    the loop will actually produce.

    An unresolved type stays unconstrained rather than reported: inference may
    still settle it, and refusing early would reject a program that is fine. -}
iterationElement :: Span -> Type -> Checker Type
iterationElement spanValue iteratedType = case throughReference iteratedType of
  ErrorType -> pure ErrorType
  VariableType _ -> freshVariable
  NominalType "Array" [element] -> pure element
  NominalType "Str" [] -> pure charType
  NominalType "Set" [element] -> pure element
  NominalType "Map" [key, held] -> pure (TupleTypeValue [key, held])
  UnitTypeValue -> freshVariable
  {-| A tuple's members must agree, because one binder cannot hold two types. -}
  TupleTypeValue [] -> freshVariable
  TupleTypeValue (first : rest) -> do
    mapM_ (unify spanValue first) rest
    pure first
  NominalType owner arguments -> do
    let receiver = NominalType owner arguments
        receiverReference = ReferenceTypeValue False receiver
    begun <- instantiateMethod receiver "begin"
    stepped <- instantiateMethod receiver "advance"
    case (begun, stepped) of
      (Nothing, Nothing) -> do
        {-| A sum walks the payload the matched variant carries, which is what
            makes an `Option` a sequence of nought or one. Every variant's
            payload must agree, because one binder cannot hold two types. -}
        variants <- lookupOwnerVariants owner
        case variants of
          Just names@(_ : _) -> do
            payloads <- mapM lookupVariant names
            let carried =
                  [ substituteRigid (zip variantParams arguments) payloadType
                  | Just (_, variantParams, declaredPayload) <- payloads
                  , length variantParams == length arguments
                  , payloadType <- declaredPayload
                  ]
            case carried of
              [] -> freshVariable
              first : rest -> do
                mapM_ (unify spanValue first) rest
                pure first
          _ -> do
            report "E3030" spanValue ("a " <> nominalName owner <> " cannot be iterated")
              ( Just
                  ( "implement Std.Iter.Sequence for it, which is begin and advance, "
                      <> "or iterate an array, a string, a map, or a set"
                  )
              )
            pure ErrorType
      (Just ErrorType, _) -> pure ErrorType
      (_, Just ErrorType) -> pure ErrorType
      ( Just (FunctionTypeValue False [beginReceiver] beginState)
        , Just
            ( FunctionTypeValue False [advanceReceiver, advanceState]
                (NominalType "Option" [TupleTypeValue [nextState, item]])
              )
        ) -> do
          _ <- unify spanValue receiverReference beginReceiver
          _ <- unify spanValue receiverReference advanceReceiver
          _ <- unify spanValue beginState advanceState
          _ <- unify spanValue beginState nextState
          zonk item
      _ -> do
        report "E3030" spanValue
          (nominalName owner <> " does not provide one coherent sequence")
          ( Just
              ( "begin must take &Self and answer State; advance must take "
                  <> "&Self and State and answer Option[(State, Item)]"
              )
          )
        pure ErrorType
  other -> do
    report "E3030" spanValue ("a " <> renderType other <> " cannot be iterated")
      (Just "iterate an array, a string, a map, a set, or a type implementing Std.Iter.Sequence")
    pure ErrorType
 where
  instantiateMethod receiver name = do
    found <- methodScheme spanValue receiver name
    mapM (instantiate spanValue) found

throughReference :: Type -> Type
throughReference typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReference target
  other -> other
