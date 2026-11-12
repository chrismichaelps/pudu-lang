{-| @Pudu.Compiler.Lower.Dynamic — `dynamic Trait` as a sum over the trait's
    implementing types, one variant each holding the value; a concrete value
    widens into its variant where a dynamic one is expected, and a method
    call selects the held type's implementation. -}
module Pudu.Compiler.Lower.Dynamic
  ( dynamicSums, isDynamic, widen, widenBlock, widenTo, writtenType, pathText ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Types (LowerTypes, dynamicIdentity, isDynamic, ownerKeyOf, recordFields, sumVariants)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( Declaration (..), Impl (..), Located (..), Module (..), TypeSyntax (..), moduleNameText )
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Type.Value (NominalId (..), Type (..))

{-| Every trait's implementing types as a sum, by the identity a dynamic
    type of that trait forms to. Only an implementation without parameters
    of its own names one type, so only those are variants. -}
dynamicSums :: [Module] -> Map NominalId ([Text], [(Text, [Type], Maybe [Text])])
dynamicSums modules = Map.map (\variants -> ([], dedupe variants)) $ Map.fromListWith (flip (<>))
  [ (dynamicIdentity (identityOf (qualified syntax trait)), [(pathText target, [owner], Nothing)])
  | syntax <- modules
  , Located _ (ImplDeclaration impl) <- moduleDeclarations syntax
  , null (implTypeParams impl)
  , NamedType trait _ <- [locatedValue (implTrait impl)]
  , NamedType target _ <- [locatedValue (implTarget impl)]
  , Just owner <- [writtenType [] (implTarget impl)] ]
 where
  qualified syntax trait
    | Text.isInfixOf "." (pathText trait) = pathText trait
    | otherwise = moduleNameText (locatedValue (moduleName syntax)) <> "." <> pathText trait
  dedupe = foldr (\variant@(name, _, _) kept -> if any (\(other, _, _) -> other == name) kept then kept else variant : kept) []

{-| A written type as checking forms it, with these names rigid. Resolution
    has already made every path canonical. -}
writtenType :: [Text] -> Located TypeSyntax -> Maybe Type
writtenType rigid (Located _ written) = case written of
  NamedType path arguments -> do
    formed <- traverse (writtenType rigid) arguments
    let name = pathText path
    pure $ if name `elem` rigid && null arguments then RigidType name
      else if name == "Never" then NeverType else NominalType (identityOf name) formed
  DynamicType path -> Just (DynamicTypeValue (identityOf (pathText path)))
  TupleType members -> TupleTypeValue <$> traverse (writtenType rigid) members
  ReferenceType mutable held -> ReferenceTypeValue mutable <$> writtenType rigid held
  FunctionType asynchronous inputs result -> FunctionTypeValue asynchronous
    <$> traverse (writtenType rigid) inputs <*> writtenType rigid result
  UnitType -> Just UnitTypeValue
  _ -> Nothing

identityOf :: Text -> NominalId
identityOf name = case reverse (Text.splitOn "." name) of
  member : owners -> NominalId (ModuleName <$> NonEmpty.nonEmpty (reverse owners)) member
  [] -> NominalId Nothing name

pathText :: ModuleName -> Text
pathText (ModuleName path) = Text.intercalate "." (NonEmpty.toList path)

{-| The value as the expected type holds it: itself when it already is one,
    its variant when the expected type is dynamic and the value's type
    implements the trait. A literal whose members are expected dynamic is
    built again with each member widened, to any depth. -}
widen :: LowerTypes -> CoreType -> CoreExpression -> CoreExpression
widen types expected core
  | actual == expected || actual == CoreNeverType = core
  | isDynamic expected = case (sumVariants types expected, ownerKeyOf actual) of
      (Just variants, Just owner)
        | any (\variant -> coreVariantName variant == owner && map snd (coreVariantFields variant) == [actual]) variants ->
            CoreExpression at expected (CoreConstruct owner [("0", core)])
      _ -> core
  | otherwise = maybe core (CoreExpression at expected) rebuilt
 where
  actual = coreExpressionType core
  at = coreExpressionSpan core
  settled member kind = coreExpressionType member `elem` [kind, CoreNeverType]
  members kinds given = do
    let widened = zipWith (widen types) kinds given
    if length kinds == length given && and (zipWith settled widened kinds) then Just widened else Nothing
  labelled declared given = do
    kinds <- traverse (\(label, _) -> lookup label declared) given
    zip (map fst given) <$> members kinds (map snd given)
  rebuilt = case (coreExpressionShape core, expected) of
    (CoreArray items, CoreArrayType element) -> CoreArray <$> members (map (const element) items) items
    (CoreTuple items, CoreTupleType kinds) -> CoreTuple <$> members kinds items
    (CoreRecord fields, CoreRecordType _ _) -> do
      declared <- recordFields types expected
      CoreRecord <$> labelled declared fields
    (CoreConstruct name fields, CoreSumType _ _) -> do
      variants <- sumVariants types expected
      variant <- lookup name [(coreVariantName variant, variant) | variant <- variants]
      CoreConstruct name <$> labelled (coreVariantFields variant) fields
    (CoreBlockValue block, _) | Just result <- coreBlockResult block ->
      let widened = widen types expected result
       in if settled widened expected then Just (CoreBlockValue block{coreBlockResult = Just widened}) else Nothing
    (CoreIfValue condition yes no, _) ->
      let taken = widenBlock types expected yes
          other = widen types expected no
       in if maybe True (`settled` expected) (coreBlockResult taken) && settled other expected
            then Just (CoreIfValue condition taken other) else Nothing
    (CoreMatch subject arms, _) ->
      let widened = [arm{coreArmBody = widen types expected (coreArmBody arm)} | arm <- arms]
       in if all ((`settled` expected) . coreArmBody) widened then Just (CoreMatch subject widened) else Nothing
    _ -> Nothing

{-| The same, with the type the value then has. -}
widenTo :: LowerTypes -> CoreType -> (CoreExpression, CoreType) -> (CoreExpression, CoreType)
widenTo types expected (core, _) = let widened = widen types expected core in (widened, coreExpressionType widened)

{-| A block whose result widens. -}
widenBlock :: LowerTypes -> CoreType -> CoreBlock -> CoreBlock
widenBlock types expected (CoreBlock statements result) = CoreBlock statements (widen types expected <$> result)
