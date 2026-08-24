{-| @Type.Check.Coherence.Module — rejects duplicate implementation heads -}
module Pudu.Type.Check.Coherence
  ( checkCoherence
  ) where

import Control.Monad (foldM)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameSegments, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Impl (..)
  , TypeParam (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, report)

data ImplementationKey = ImplementationKey !TypeKey !TypeKey
  deriving stock (Eq, Ord)

data TypeKey
  = NamedKey !ModuleName ![TypeKey]
  | ParameterKey !Int
  | ReferenceKey !Bool !TypeKey
  | TupleKey ![TypeKey]
  | FunctionKey !Bool ![TypeKey] !TypeKey
  | UnitKey
  | InvalidKey
  deriving stock (Eq, Ord)

{-| Reject every implementation head after the first structurally identical
    head. Generic binders use positional identities, so alpha-renaming cannot
    evade the duplicate check. -}
checkCoherence :: [Located Declaration] -> Checker ()
checkCoherence declarations = do
  _ <- foldM checkDuplicate Set.empty (implementationHeads declarations)
  pure ()

implementationHeads :: [Located Declaration] -> [(Span, ImplementationKey)]
implementationHeads declarations =
  [ (locatedSpan (implTarget value), implementationKey value)
  | Located _ (ImplDeclaration value) <- declarations
  ]

implementationKey :: Impl -> ImplementationKey
implementationKey value =
  let parameters = Map.fromList
        (zip (map (locatedValue . typeParamName . locatedValue) (implTypeParams value)) [0 ..])
   in ImplementationKey
        (typeKey parameters (locatedValue (implTrait value)))
        (typeKey parameters (locatedValue (implTarget value)))

typeKey :: Map.Map Text Int -> TypeSyntax -> TypeKey
typeKey parameters syntax = case syntax of
  NamedType path arguments ->
    case parameterIndex parameters path arguments of
      Just index -> ParameterKey index
      Nothing -> NamedKey path (map (typeKey parameters . locatedValue) arguments)
  ReferenceType mutable target ->
    ReferenceKey mutable (typeKey parameters (locatedValue target))
  TupleType members ->
    TupleKey (map (typeKey parameters . locatedValue) members)
  FunctionType asynchronous inputs result ->
    FunctionKey asynchronous
      (map (typeKey parameters . locatedValue) inputs)
      (typeKey parameters (locatedValue result))
  UnitType -> UnitKey
  InvalidType -> InvalidKey

parameterIndex :: Map.Map Text Int -> ModuleName -> [Located TypeSyntax] -> Maybe Int
parameterIndex parameters path arguments =
  case (NonEmpty.toList (moduleNameSegments path), arguments) of
    ([name], []) -> Map.lookup name parameters
    _ -> Nothing

{-| Retain the first key. A later identical key reports once and does not
    perturb the set used to classify subsequent declarations. -}
checkDuplicate
  :: Set ImplementationKey
  -> (Span, ImplementationKey)
  -> Checker (Set ImplementationKey)
checkDuplicate seen (spanValue, key@(ImplementationKey traitKey targetKey))
  | Set.member key seen = do
      report "E3015" spanValue
        ("duplicate implementation: " <> renderTypeKey traitKey
          <> " is already implemented for " <> renderTypeKey targetKey)
        (Just "remove one implementation; duplicate implementation heads are prohibited")
      pure seen
  | otherwise = pure (Set.insert key seen)

renderTypeKey :: TypeKey -> Text
renderTypeKey key = case key of
  NamedKey path arguments ->
    moduleNameText path <> renderArguments arguments
  ParameterKey index -> "$" <> Text.pack (show index)
  ReferenceKey mutable target ->
    (if mutable then "&mut " else "&") <> renderTypeKey target
  TupleKey members -> "(" <> Text.intercalate ", " (map renderTypeKey members) <> ")"
  FunctionKey asynchronous inputs result ->
    (if asynchronous then "async " else "") <> "fn("
      <> Text.intercalate ", " (map renderTypeKey inputs) <> ") -> "
      <> renderTypeKey result
  UnitKey -> "()"
  InvalidKey -> "<invalid>"

renderArguments :: [TypeKey] -> Text
renderArguments arguments
  | null arguments = ""
  | otherwise = "[" <> Text.intercalate ", " (map renderTypeKey arguments) <> "]"
