{-| @Type.Drop.Module — decides which values need drop -}
module Pudu.Type.Drop
  ( dropTrait
  , isDropTrait
  , needsDrop
  , implementsDrop
  , substituteParameters
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (fromMaybe)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Type.Env
  ( Checker
  , lookupDeclaredName
  , lookupField
  , lookupImplementations
  , lookupOwnerVariants
  , lookupTypeParams
  , lookupVariant
  )
import Pudu.Type.Value (NominalId (..), Type (..))

{-| The prelude `Drop` as the module being checked resolves it. A module that
    declares its own `Drop` trait names that one instead, and it is not the
    drop trait. -}
dropTrait :: Checker (Maybe NominalId)
dropTrait = do
  resolved <- lookupDeclaredName "Drop"
  let identity = fromMaybe (NominalId Nothing "Drop") resolved
  pure (if isDropTrait identity then Just identity else Nothing)

{-| The prelude declares `Drop`; only that declaration runs at the end of
    ownership. -}
isDropTrait :: NominalId -> Bool
isDropTrait identity = nominalName identity == "Drop" && case nominalModule identity of
  Nothing -> True
  Just (ModuleName segments) -> NonEmpty.toList segments == NonEmpty.toList preludeModule

preludeModule :: NonEmpty Text
preludeModule = "Core" :| ["Prelude"]

{-| Whether a nominal type itself implements `Drop`. -}
implementsDrop :: NominalId -> Checker Bool
implementsDrop owner = do
  trait <- dropTrait
  case trait of
    Nothing -> pure False
    Just identity -> not . null <$> lookupImplementations owner identity

{-| A type needs drop when it implements `Drop` or stores a value whose type
    does. References borrow and functions hold no stored component the
    ownership check admits, so neither needs drop; an unsettled or rigid type
    is decided by the instantiation the ownership check refuses. -}
needsDrop :: Type -> Checker Bool
needsDrop = decide Set.empty

decide :: Set NominalId -> Type -> Checker Bool
decide visiting typeValue = case typeValue of
  TupleTypeValue members -> anyDecide visiting members
  RestrictedType _ inner -> decide visiting inner
  NominalType owner arguments -> nominal visiting owner arguments
  _ -> pure False

nominal :: Set NominalId -> NominalId -> [Type] -> Checker Bool
nominal visiting owner arguments
  | Set.member owner visiting = pure False
  | otherwise = do
      own <- implementsDrop owner
      if own then pure True else components
 where
  components
    | nominalName owner `elem` holders = anyDecide visiting arguments
    | otherwise = declared (Set.insert owner visiting) owner arguments

{-| Wired-in types whose arguments are what they store. -}
holders :: [Text]
holders = ["Option", "Result", "Array", "Map", "Set", "Range", "Task", "Buckets"]

declared :: Set NominalId -> NominalId -> [Type] -> Checker Bool
declared visiting owner arguments = do
  params <- lookupTypeParams owner
  let substitution = zip (fromMaybe [] params) arguments
  fields <- lookupField owner
  case fields of
    Just written -> anyDecide visiting (map (substituteParameters substitution . snd) written)
    Nothing -> do
      variants <- lookupOwnerVariants owner
      case variants of
        Nothing -> pure False
        Just names -> do
          payloads <- mapM (payloadOf substitution) names
          anyDecide visiting (concat payloads)

payloadOf :: [(Text, Type)] -> Text -> Checker [Type]
payloadOf substitution name = do
  found <- lookupVariant name
  pure $ case found of
    Nothing -> []
    Just (_, _, payload) -> map (substituteParameters substitution) payload

{-| A declaration's component type with the use's type arguments in place of
    its parameters. -}
substituteParameters :: [(Text, Type)] -> Type -> Type
substituteParameters substitution typeValue = case typeValue of
  RigidType name -> fromMaybe typeValue (lookup name substitution)
  NominalType owner arguments -> NominalType owner (map (substituteParameters substitution) arguments)
  TupleTypeValue members -> TupleTypeValue (map (substituteParameters substitution) members)
  ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (substituteParameters substitution target)
  other -> other

anyDecide :: Set NominalId -> [Type] -> Checker Bool
anyDecide visiting types = case types of
  [] -> pure False
  first : rest -> do
    found <- decide visiting first
    if found then pure True else anyDecide visiting rest
