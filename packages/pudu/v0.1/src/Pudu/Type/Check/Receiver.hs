{-| @Type.Check.Receiver — specializes a method to its bound receiver once -}
module Pudu.Type.Check.Receiver (bindReceiver) where

import Pudu.Source (Span)
import Pudu.Type.Env (Checker)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (NominalId, Required (..), Type (..), requiredCount)

bindReceiver :: Span -> Type -> Type -> Checker Type
bindReceiver at receiver signature = case signature of
  RestrictedType capabilities inner -> do
    bound <- bindReceiver at receiver inner
    pure (if bound == ErrorType then ErrorType else RestrictedType capabilities bound)
  FunctionTypeRequiring asynchronous (self : inputs) required result -> do
    actual <- referent receiver
    expected <- referent self
    let applied = case (expected, actual) of
          (NominalType owner [], NominalType held (_ : _)) | owner == held ->
            specializeBareSelf owner actual signature
          _ -> signature
        (selfHere, inputsHere, resultHere) = case applied of
          FunctionTypeRequiring _ (bound : remaining) _ answer -> (bound, remaining, answer)
          _ -> (self, inputs, result)
    expectedHere <- referent selfHere
    matched <- unify at expectedHere actual
    if matched == ErrorType
      then pure ErrorType
      else zonk (FunctionTypeRequiring asynchronous inputsHere
        (Required (max 0 (requiredCount required - 1))) resultHere)
  other -> pure other
 where
  referent value = do
    resolved <- zonk value
    case resolved of
      ReferenceTypeValue _ inner -> referent inner
      other -> pure other

specializeBareSelf :: NominalId -> Type -> Type -> Type
specializeBareSelf owner receiver = go
 where
  go value = case value of
    NominalType identity [] | identity == owner -> receiver
    NominalType identity arguments -> NominalType identity (map go arguments)
    TupleTypeValue members -> TupleTypeValue (map go members)
    FunctionTypeRequiring asynchronous inputs required result ->
      FunctionTypeRequiring asynchronous (map go inputs) required (go result)
    ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (go target)
    AppliedType head' arguments -> AppliedType (go head') (map go arguments)
    RestrictedType capabilities target -> RestrictedType capabilities (go target)
    other -> other
