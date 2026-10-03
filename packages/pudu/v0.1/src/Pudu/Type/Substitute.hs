{-| @Type.Substitute — simultaneous substitution preserving complete type contracts -}
module Pudu.Type.Substitute (substituteRigid) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Type.Value (Type (..))

substituteRigid :: [(Text, Type)] -> Type -> Type
substituteRigid replacements = walk
 where
  bindings = Map.fromList replacements
  walk value = case value of
    RigidType name -> Map.findWithDefault value name bindings
    AppliedType head' arguments -> apply (walk head') (map walk arguments)
    NominalType owner arguments -> NominalType owner (map walk arguments)
    TupleTypeValue members -> TupleTypeValue (map walk members)
    FunctionTypeRequiring asynchronous inputs required result ->
      FunctionTypeRequiring asynchronous (map walk inputs) required (walk result)
    ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (walk target)
    RestrictedType capabilities target -> RestrictedType capabilities (walk target)
    other -> other
  apply head' arguments = case head' of
    _ | null arguments -> head'
    NominalType owner existing -> NominalType owner (existing <> arguments)
    AppliedType inner existing -> apply inner (existing <> arguments)
    _ -> AppliedType head' arguments
