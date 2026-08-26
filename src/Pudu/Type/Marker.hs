{-| @Type.Marker.Module — decides the compiler-controlled markers -}
module Pudu.Type.Marker
  ( isMarkerTrait
  , isUserImplementable
  , satisfiesMarker
  ) where

import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Type.Env
  ( Checker
  , lookupField
  , lookupOwnerVariants
  , lookupTypeParams
  , lookupVariant
  )
import Pudu.Type.Value (NominalId (..), Type (..), nominalName)

{-| The markers the compiler decides structurally rather than by declaration.

    [[grammar/pudu]] states the rule for each: a value is `Copy` when its
    representation holds only `Copy` components and owns no resource, and a
    value crosses into a task when it is `Send`, with shared references
    additionally requiring `Sync`. None of them is a table of implementations,
    so none of them can be answered by looking one up. -}
isMarkerTrait :: NominalId -> Bool
isMarkerTrait traitIdentity = nominalName traitIdentity `elem` markerNames

markerNames :: [Text]
markerNames = ["Copy", "Send", "Sync"]

{-| `Copy` is compiler-controlled: [[architecture/SEMANTICS]] rejects a
    user-written implementation of it, because ownership checking — not the
    program — decides which values duplicate. `Send` and `Sync` stay
    implementable so a wrapper can state a guarantee the structure cannot
    show. -}
isUserImplementable :: NominalId -> Bool
isUserImplementable traitIdentity = nominalName traitIdentity /= "Copy"

{-| Decide a marker for a type by walking its structure.

    The walk carries the nominal types already being decided, so a recursive
    declaration answers rather than looping. A rigid parameter is never
    satisfied here: its bounds are what decide it, and the caller consults
    those first. -}
satisfiesMarker :: NominalId -> Type -> Checker Bool
satisfiesMarker traitIdentity = decide (nominalName traitIdentity) Set.empty

decide :: Text -> Set NominalId -> Type -> Checker Bool
decide marker visiting typeValue = case typeValue of
  UnitTypeValue -> pure True
  NeverType -> pure True
  ErrorType -> pure True
  VariableType _ -> pure False
  RigidType _ -> pure False
  {-| A dynamic value carries whatever its concrete type carries, and that is
      not known here. Only the markers the trait itself guarantees can be
      claimed, and a trait guarantees none of them, so this answers no. -}
  DynamicTypeValue _ -> pure False
  TupleTypeValue members -> allDecide marker visiting members
  FunctionTypeValue{} -> pure (marker /= "Copy")
  ReferenceTypeValue mutable target -> reference marker visiting mutable target
  NominalType owner arguments -> nominal marker visiting owner arguments

{-| A shared reference duplicates freely, and crossing one into a task requires
    the referent to be shareable — which is exactly what `Sync` means. An
    exclusive reference never duplicates. -}
reference :: Text -> Set NominalId -> Bool -> Type -> Checker Bool
reference marker visiting mutable target = case marker of
  "Copy" -> pure (not mutable)
  "Send" -> decide (if mutable then "Send" else "Sync") visiting target
  _ -> decide "Sync" visiting target

nominal :: Text -> Set NominalId -> NominalId -> [Type] -> Checker Bool
nominal marker visiting owner arguments
  | Set.member owner visiting = pure True
  | isScalar name = pure True
  | name == "Str" = pure (marker /= "Copy")
  | name == "Array" = case arguments of
      [element] -> if marker == "Copy" then pure False else decide marker visiting element
      _ -> pure False
  | name == "Task" = pure False
  | otherwise = declared marker (Set.insert owner visiting) owner arguments
 where
  name = nominalName owner

{-| Integer, floating, boolean, and character values are scalars: they hold no
    resource and every marker admits them. -}
isScalar :: Text -> Bool
isScalar name =
  name
    `elem` [ "Int8", "Int16", "Int32", "Int64", "Int128", "Int"
           , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "UInt"
           , "Float32", "Float64", "Float"
           , "Bool", "Char", "BigInt", "Never"
           ]

{-| A declared aggregate satisfies a marker exactly when every component it
    stores does, with the use's type arguments substituted for the
    declaration's parameters. A declaration this module cannot see is not
    assumed to satisfy anything. -}
declared :: Text -> Set NominalId -> NominalId -> [Type] -> Checker Bool
declared marker visiting owner arguments = do
  params <- lookupTypeParams owner
  let substitution = zip (maybe [] id params) arguments
  fields <- lookupField owner
  case fields of
    Just declaredFields ->
      allDecide marker visiting (map (substitute substitution . snd) declaredFields)
    Nothing -> do
      variants <- lookupOwnerVariants owner
      case variants of
        Nothing -> pure False
        Just names -> do
          payloads <- mapM (payloadOf substitution) names
          allDecide marker visiting (concat payloads)

payloadOf :: [(Text, Type)] -> Text -> Checker [Type]
payloadOf substitution name = do
  found <- lookupVariant name
  pure $ case found of
    Nothing -> []
    Just (_, _, payload) -> map (substitute substitution) payload

substitute :: [(Text, Type)] -> Type -> Type
substitute substitution typeValue = case typeValue of
  RigidType name -> maybe typeValue id (lookup name substitution)
  NominalType owner arguments -> NominalType owner (map (substitute substitution) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substitute substitution) members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous
      (map (substitute substitution) inputs)
      (substitute substitution result)
  ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (substitute substitution target)
  other -> other

allDecide :: Text -> Set NominalId -> [Type] -> Checker Bool
allDecide marker visiting types = case types of
  [] -> pure True
  first : rest -> do
    satisfied <- decide marker visiting first
    if satisfied then allDecide marker visiting rest else pure False
