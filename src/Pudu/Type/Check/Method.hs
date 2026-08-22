{-| @Type.Check.Method.Module — types trait and implementation methods -}
module Pudu.Type.Check.Method
  ( declareMethods
  , implAliases
  , traitTable
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function (..)
  , Impl (..)
  , Trait (..)
  , TypeParam (..)
  )
import Pudu.Type.Env (Checker, DeclaredTypes (..), bindName)
import Pudu.Type.Formation (declaredParameterType, formOptionalType, formType)
import Pudu.Type.Value (Scheme (..), Type (..))

{-| Trait members by trait name, so an implementation can inherit the defaults
    it does not override. -}
traitTable :: [Located Declaration] -> Map.Map Text [Located Function]
traitTable declarations =
  Map.fromList
    [ (locatedValue (traitName value), traitMembers value)
    | Located _ (TraitDeclaration value) <- declarations
    ]


{-| An impl's functions are methods of its target type, not module-scope names.
    They are bound under a qualified key so a member access on a value of that
    type finds them, and so one method may call another. -}
declareMethods :: DeclaredTypes -> Map.Map Text [Located Function] -> Impl -> Checker ()
declareMethods declared traits value = do
  target <- formType (implAliases declared value) [] (implTarget value)
  case targetName target of
    Nothing -> pure ()
    Just owner -> do
      mapM_ (declareMethod declared value owner) (implFunctions value)
      mapM_ (declareMethod declared value owner) (inheritedDefaults traits value)

{-| A trait member that carries a body is a default: an implementation that does
    not override it still has it. -}
inheritedDefaults :: Map.Map Text [Located Function] -> Impl -> [Located Function]
inheritedDefaults traits value = case implTraitName value of
  Nothing -> []
  Just traitText ->
    [ member
    | member@(Located _ method) <- maybe [] id (Map.lookup traitText traits)
    , functionBody method /= Nothing
    , locatedValue (functionName method) `notElem` provided
    ]
 where
  provided = map (locatedValue . functionName . locatedValue) (implFunctions value)

implTraitName :: Impl -> Maybe Text
implTraitName value = case locatedValue (implTrait value) of
  Tree.NamedType path _ -> Just (NonEmpty.last (moduleNameSegments path))
  _ -> Nothing

declareMethod :: DeclaredTypes -> Impl -> Text -> Located Function -> Checker ()
declareMethod declared value owner (Located _ method) = do
  let rigid = implRigid value <> functionRigid method
      aliases = implAliases declared value
  inputs <- mapM (declaredParameterType aliases rigid) (functionParameters method)
  result <- formOptionalType aliases rigid (functionReturn method)
  bindName (methodKey owner (locatedValue (functionName method)))
    (Scheme rigid (FunctionTypeValue (functionAsync method) inputs result))

{-| `Self` inside an implementation is its target type, which is what lets a
    method read the fields of the value it was called on. -}
implAliases :: DeclaredTypes -> Impl -> DeclaredTypes
implAliases declared value = case implTargetName value of
  Nothing -> declared
  Just name ->
    declared
      { declaredAliases =
          Map.insert "Self" (NominalType name []) (declaredAliases declared)
      }

implTargetName :: Impl -> Maybe Text
implTargetName value = case locatedValue (implTarget value) of
  Tree.NamedType path _ -> Just (NonEmpty.last (moduleNameSegments path))
  _ -> Nothing

functionRigid :: Function -> [Text]
functionRigid value = map (locatedValue . typeParamName . locatedValue) (functionTypeParams value)

implRigid :: Impl -> [Text]
implRigid value = map (locatedValue . typeParamName . locatedValue) (implTypeParams value)

targetName :: Type -> Maybe Text
targetName typeValue = case typeValue of
  NominalType name _ -> Just name
  _ -> Nothing

methodKey :: Text -> Text -> Text
methodKey owner method = owner <> "." <> method
