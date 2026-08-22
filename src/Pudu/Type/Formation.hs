{-| @Type.Formation.Module — forms types from type syntax -}
module Pudu.Type.Formation
  ( collectDeclared
  , declaredParameterType
  , formType
  , formOptionalType
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Impl (..)
  , Parameter (..)
  , FieldDeclaration (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Variant (..)
  , VariantPayload (..)
  )
import Pudu.Type.Env (Checker, DeclaredTypes (..), emptyDeclared, freshVariable)
import Pudu.Type.Value (Type (..))

{-| Form a type from its syntax. Names that were declared as generic parameters
    become rigid; every other name is nominal, and an alias expands
    transparently as [[architecture/SEMANTICS]] requires. -}
formType :: DeclaredTypes -> [Text] -> Located TypeSyntax -> Checker Type
formType declared rigid (Located _ syntax) = case syntax of
  NamedType path arguments -> do
    formed <- mapM (formType declared rigid) arguments
    pure (formNamed declared rigid (lastSegment path) formed)
  ReferenceType mutable target -> ReferenceTypeValue mutable <$> formType declared rigid target
  TupleType members -> TupleTypeValue <$> mapM (formType declared rigid) members
  FunctionType asynchronous inputs result ->
    FunctionTypeValue asynchronous
      <$> mapM (formType declared rigid) inputs
      <*> formType declared rigid result
  UnitType -> pure UnitTypeValue
  InvalidType -> pure ErrorType

formNamed :: DeclaredTypes -> [Text] -> Text -> [Type] -> Type
formNamed declared rigid name arguments
  | name `elem` rigid = RigidType name
  | name == "Never" = NeverType
  | otherwise = case Map.lookup name (declaredAliases declared) of
      Just aliased | null arguments -> aliased
      _ -> NominalType name arguments

{-| An absent annotation becomes a fresh inference variable, which is how a
    private binding or parameter participates in local inference. -}
{-| A parameter's declared type, or a fresh variable when it has none. -}
declaredParameterType :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
declaredParameterType declared rigid (Located _ parameter) =
  formOptionalType declared rigid (parameterType parameter)

formOptionalType :: DeclaredTypes -> [Text] -> Maybe (Located TypeSyntax) -> Checker Type
formOptionalType declared rigid annotation = case annotation of
  Nothing -> freshVariable
  Just syntax -> formType declared rigid syntax

lastSegment :: ModuleName -> Text
lastSegment (ModuleName segments) = NonEmpty.last segments

{-| The sums the compiler wires in. `Option` and `Result` are the language's
    absence and failure carriers, so their constructors exist without any
    declaration, exactly as their types do. -}
builtinVariants :: Map Text (Text, [Text], [Type])
builtinVariants =
  Map.fromList
    [ ("Some", ("Option", ["T"], [RigidType "T"]))
    , ("None", ("Option", ["T"], []))
    , ("Ok", ("Result", ["T", "E"], [RigidType "T"]))
    , ("Err", ("Result", ["T", "E"], [RigidType "E"]))
    ]

builtinOwners :: Map Text [Text]
builtinOwners = Map.fromList [("Option", ["Some", "None"]), ("Result", ["Ok", "Err"])]

{-| Collect what every type declaration contributes before any body is checked,
    so a declaration may refer to one that appears later in the file. -}
collectDeclared :: [Located Declaration] -> Checker DeclaredTypes
collectDeclared declarations = do
  let shells =
        (foldr addShell emptyDeclared declarations)
          { declaredVariants = builtinVariants
          , declaredOwners = builtinOwners
          }
  foldCollect shells declarations

addShell :: Located Declaration -> DeclaredTypes -> DeclaredTypes
addShell (Located _ declaration) declared = case declaration of
  TypeDeclaration value ->
    declared
      { declaredParams =
          Map.insert (locatedValue (typeName value)) (paramNames value) (declaredParams declared)
      }
  _ -> declared

paramNames :: TypeDeclarationValue -> [Text]
paramNames value =
  map (locatedValue . typeParamName . locatedValue) (typeTypeParams value)

foldCollect :: DeclaredTypes -> [Located Declaration] -> Checker DeclaredTypes
foldCollect declared declarations = case declarations of
  [] -> pure declared
  first : rest -> do
    extended <- collectOne declared first
    foldCollect extended rest

{-| Which traits a type implements, read from the module's implementations.
    Bound satisfaction consults it; coherence across modules is a later
    slice. -}
recordImpl :: DeclaredTypes -> Impl -> DeclaredTypes
recordImpl declared value = case (nameOf (implTarget value), nameOf (implTrait value)) of
  (Just owner, Just traitText) ->
    declared
      { declaredImpls =
          Map.insertWith (<>) owner [traitText] (declaredImpls declared)
      }
  _ -> declared
 where
  nameOf (Located _ syntax) = case syntax of
    NamedType path _ -> Just (lastSegment path)
    _ -> Nothing

collectOne :: DeclaredTypes -> Located Declaration -> Checker DeclaredTypes
collectOne declared (Located _ declaration) = case declaration of
  ImplDeclaration value -> pure (recordImpl declared value)
  TypeDeclaration value -> do
    let name = locatedValue (typeName value)
        rigid = paramNames value
    case locatedValue (typeDefinition value) of
      RecordDefinition fields -> do
        formed <- mapM (formField declared rigid) fields
        pure declared{declaredFields = Map.insert name formed (declaredFields declared)}
      SumDefinition variants -> do
        entries <- mapM (formVariant declared rigid name) variants
        pure
          declared
            { declaredVariants = insertAll entries (declaredVariants declared)
            , declaredOwners = Map.insert name (map fst entries) (declaredOwners declared)
            }
      AliasDefinition aliased -> do
        formed <- formType declared rigid aliased
        pure declared{declaredAliases = Map.insert name formed (declaredAliases declared)}
      InvalidDefinition -> pure declared
  _ -> pure declared

formField :: DeclaredTypes -> [Text] -> Located FieldDeclaration -> Checker (Text, Type)
formField declared rigid (Located _ field) = do
  formed <- formType declared rigid (fieldType field)
  pure (locatedValue (fieldName field), formed)

{-| A variant is recorded under its own name together with the type it belongs
    to, which is how a constructor call and a pattern both find its payload. -}
formVariant
  :: DeclaredTypes
  -> [Text]
  -> Text
  -> Located Variant
  -> Checker (Text, (Text, [Text], [Type]))
formVariant declared rigid owner (Located _ variant) = do
  payload <- case variantPayload variant of
    UnitPayload -> pure []
    TuplePayload members -> mapM (formType declared rigid) members
    RecordPayload fields -> map snd <$> mapM (formField declared rigid) fields
  pure (locatedValue (variantName variant), (owner, rigid, payload))

insertAll
  :: [(Text, (Text, [Text], [Type]))]
  -> Map Text (Text, [Text], [Type])
  -> Map Text (Text, [Text], [Type])
insertAll entries existing = foldr (\(key, value) acc -> Map.insert key value acc) existing entries
