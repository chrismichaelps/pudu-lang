{-| @Type.Implementation — preserves concrete heads and conditional trait evidence. -}
module Pudu.Type.Implementation
  ( ImplementationRule (..), matchImplementation, selectImplementationTarget ) where

import Control.Monad (foldM, guard)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Value (Type (..))

{-| Canonical owners index these rules; complete heads and premises decide evidence. -}
data ImplementationRule = ImplementationRule
  { implementationParameters :: ![(Text, Int)]
  , implementationTarget :: !Type
  , implementationTrait :: !Type
  , implementationRequirements :: ![(Type, Type)]
  }
  deriving stock (Eq, Show)

matchImplementation :: Type -> Maybe Type -> ImplementationRule -> Maybe [(Type, Type)]
matchImplementation target trait rule = do
  completed <- matchSelection target trait rule
  guard (all (\(name, _) -> Map.member name completed) (implementationParameters rule))
  let replace = substituteRigid (Map.toList completed)
  pure [(replace subject, replace bound) | (subject, bound) <- implementationRequirements rule]

{-| Preserve target-head selections without claiming their conditional evidence. -}
selectImplementationTarget :: Type -> ImplementationRule -> Maybe [(Text, Type)]
selectImplementationTarget target rule = Map.toList <$> matchSelection target Nothing rule

matchSelection :: Type -> Maybe Type -> ImplementationRule -> Maybe (Map.Map Text Type)
matchSelection target trait rule = do
  selected <- case (implementationTarget rule, target) of
    (NominalType owner [], NominalType found _) | owner == found -> Just Map.empty
    (written, actual) -> match Map.empty written actual
  maybe (Just selected) (match selected (implementationTrait rule)) trait
 where
  parameters = Map.fromList (implementationParameters rule)
  bind selected name actual
    | unknown actual = Nothing
    | otherwise = case Map.lookup name selected of
        Just previous | previous /= actual -> Nothing
        _ -> Just (Map.insert name actual selected)
  match selected pattern' actual = case (pattern', actual) of
    (RigidType name, _) | Map.member name parameters -> bind selected name actual
    (NominalType owner arguments, NominalType found values) | owner == found ->
      members selected arguments values
    (ReferenceTypeValue mutable held, ReferenceTypeValue writable value) | mutable == writable ->
      match selected held value
    (TupleTypeValue held, TupleTypeValue values) -> members selected held values
    (FunctionTypeRequiring async inputs required result,
     FunctionTypeRequiring asynchronous values supplied answer)
      | async == asynchronous && required == supplied -> do
          next <- members selected inputs values
          match next result answer
    (RestrictedType capabilities held, RestrictedType granted value) | capabilities == granted ->
      match selected held value
    (AppliedType (RigidType name) arguments, NominalType owner values)
      | Just arity <- Map.lookup name parameters
      , arity == length arguments && length arguments == length values -> do
          next <- bind selected name (NominalType owner [])
          members next arguments values
    (AppliedType head' arguments, AppliedType found values) -> do
      next <- match selected head' found
      members next arguments values
    _ | pattern' == actual && not (unknown actual) -> Just selected
    _ -> Nothing
  members selected patterns values
    | length patterns /= length values = Nothing
    | otherwise = foldM (\active (pattern', actual) -> match active pattern' actual)
        selected (zip patterns values)

unknown :: Type -> Bool
unknown value = case value of
  ErrorType -> True
  VariableType _ -> True
  NominalType _ arguments -> any unknown arguments
  ReferenceTypeValue _ held -> unknown held
  TupleTypeValue members -> any unknown members
  FunctionTypeValue _ inputs result -> any unknown inputs || unknown result
  RestrictedType _ held -> unknown held
  AppliedType head' arguments -> unknown head' || any unknown arguments
  _ -> False
