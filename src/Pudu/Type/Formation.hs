{-| @Type.Formation.Module — forms types from type syntax -}
module Pudu.Type.Formation
  ( collectDeclared
  , collectDeclaredFrom
  , declaredParameterType
  , formType
  , formOptionalType
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Impl (..)
  , Parameter (..)
  , FieldDeclaration (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  , Trait (..)
  , Variant (..)
  , VariantPayload (..)
  )
import Pudu.Source (Span)
import Control.Monad (unless)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , emptyDeclared
  , freshVariable
  , report
  , reportedReserved
  )
import Pudu.Type.Value (NominalId (..), Type (..), canonicalNominal)

{-| Form a type from its syntax. Names that were declared as generic parameters
    become rigid; every other name is nominal, and an alias expands
    transparently as [[architecture/SEMANTICS]] requires. -}
formType :: DeclaredTypes -> [Text] -> Located TypeSyntax -> Checker Type
formType declared rigid (Located typeSpan syntax) = case syntax of
  NamedType path arguments -> do
    formed <- mapM (formType declared rigid) arguments
    reserved <- rejectReserved declared typeSpan path
    if reserved then pure ErrorType else pure (formNamed declared rigid path formed)
  ReferenceType mutable target -> ReferenceTypeValue mutable <$> formType declared rigid target
  TupleType members -> TupleTypeValue <$> mapM (formType declared rigid) members
  FunctionType asynchronous inputs result ->
    FunctionTypeValue asynchronous
      <$> mapM (formType declared rigid) inputs
      <*> formType declared rigid result
  UnitType -> pure UnitTypeValue
  InvalidType -> pure ErrorType

{-| `Decimal` is reserved. [[architecture/SEMANTICS]] gives it no semantics
    until its precision and rounding ADR is accepted, and rejects it in the
    meantime — admitting it would mean inventing the rounding rule that ADR
    exists to decide. A module that declares its own `Decimal` keeps it. -}
rejectReserved :: DeclaredTypes -> Span -> ModuleName -> Checker Bool
rejectReserved declared typeSpan path
  | pathText /= reservedDecimal = pure False
  | Map.member pathText (declaredNames declared) = pure False
  | otherwise = do
      seen <- reportedReserved typeSpan
      unless seen $
        report "E3022" typeSpan "Decimal is reserved and has no semantics yet"
          (Just "use Float64 or BigInt; Decimal waits on its precision and rounding decision")
      pure True
 where
  pathText = moduleNameText path

reservedDecimal :: Text
reservedDecimal = "Decimal"

formNamed :: DeclaredTypes -> [Text] -> ModuleName -> [Type] -> Type
formNamed declared rigid path arguments
  | unqualified && name `elem` rigid = RigidType name
  | unqualified && name == "Never" = NeverType
  | otherwise = case Map.lookup pathText (declaredAliases declared) of
      Just aliased | null arguments -> aliased
      _ -> NominalType (Map.findWithDefault fallback pathText (declaredNames declared)) arguments
 where
  pathText = moduleNameText path
  name = lastSegment path
  unqualified = pathText == name
  fallback = NominalId Nothing pathText

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
builtinVariants :: Map Text (NominalId, [Text], [Type])
builtinVariants =
  Map.fromList
    [ ("Some", ("Option", ["T"], [RigidType "T"]))
    , ("None", ("Option", ["T"], []))
    , ("Ok", ("Result", ["T", "E"], [RigidType "T"]))
    , ("Err", ("Result", ["T", "E"], [RigidType "E"]))
    ]

builtinOwners :: Map NominalId [Text]
builtinOwners = Map.fromList [("Option", ["Some", "None"]), ("Result", ["Ok", "Err"])]

{-| Type aliases the compiler wires in. `Float` aliases `Float64` because
    [[grammar/pudu]] makes the alias transparent at the type level, and a
    reader who writes `Float` expects the same type as `Float64`. -}
builtinAliases :: Map Text Type
builtinAliases = Map.fromList [("Float", NominalType "Float64" [])]

{-| Collect what every type declaration contributes before any body is checked,
    so a declaration may refer to one that appears later in the file. -}
collectDeclared :: ModuleName -> [Located Declaration] -> Checker DeclaredTypes
collectDeclared = collectDeclaredFrom emptyDeclared

collectDeclaredFrom :: DeclaredTypes -> ModuleName -> [Located Declaration] -> Checker DeclaredTypes
collectDeclaredFrom initial owner declarations = do
  let shells =
        (foldr (addShell owner) initial declarations)
          { declaredVariants = builtinVariants
              <> declaredVariants initial
          , declaredOwners = builtinOwners <> declaredOwners initial
          , declaredAliases = builtinAliases <> declaredAliases initial
          }
  foldCollect owner shells declarations

addShell :: ModuleName -> Located Declaration -> DeclaredTypes -> DeclaredTypes
addShell owner (Located _ declaration) declared = case declaration of
  TypeDeclaration value ->
    let name = locatedValue (typeName value)
        identity = canonicalNominal owner name
     in declared
      { declaredNames =
          Map.insert (moduleNameText owner <> "." <> name) identity
            (Map.insert name identity (declaredNames declared))
      , declaredParams = Map.insert identity (paramNames value) (declaredParams declared)
      }
  TraitDeclaration value ->
    let name = locatedValue (traitName value)
        identity = canonicalNominal owner name
     in declared
      { declaredNames =
          Map.insert (moduleNameText owner <> "." <> name) identity
            (Map.insert name identity (declaredNames declared))
      }
  _ -> declared

paramNames :: TypeDeclarationValue -> [Text]
paramNames value =
  map (locatedValue . typeParamName . locatedValue) (typeTypeParams value)

foldCollect :: ModuleName -> DeclaredTypes -> [Located Declaration] -> Checker DeclaredTypes
foldCollect owner declared declarations = case declarations of
  [] -> pure declared
  first : rest -> do
    extended <- collectOne owner declared first
    foldCollect owner extended rest

{-| Which traits a type implements, read from the module's implementations.
    Bound satisfaction consults it; coherence across modules is a later
    slice. -}
recordImpl :: DeclaredTypes -> Impl -> Checker DeclaredTypes
recordImpl declared value = do
  target <- formType declared [] (implTarget value)
  trait <- formType declared [] (implTrait value)
  pure $ case (identityOf target, identityOf trait) of
    (Just owner, Just traitIdentity) ->
      declared
        { declaredImpls =
            Map.insertWith (<>) owner [traitIdentity] (declaredImpls declared)
        }
    _ -> declared
 where
  identityOf formed = case formed of
    NominalType identity _ -> Just identity
    _ -> Nothing

collectOne :: ModuleName -> DeclaredTypes -> Located Declaration -> Checker DeclaredTypes
collectOne owner declared (Located _ declaration) = case declaration of
  ImplDeclaration value -> recordImpl declared value
  TypeDeclaration value -> do
    let name = locatedValue (typeName value)
        identity = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)
        rigid = paramNames value
    case locatedValue (typeDefinition value) of
      RecordDefinition fields -> do
        formed <- mapM (formField declared rigid) fields
        pure declared{declaredFields = Map.insert identity formed (declaredFields declared)}
      SumDefinition variants -> do
        entries <- mapM (formVariant declared rigid identity) variants
        pure
          declared
            { declaredVariants = insertAll entries (declaredVariants declared)
            , declaredOwners = Map.insert identity (map fst entries) (declaredOwners declared)
            }
      AliasDefinition aliased -> do
        formed <- formType declared rigid aliased
        pure
          declared
            { declaredAliases =
                Map.insert (moduleNameText owner <> "." <> name) formed
                  (Map.insert name formed (declaredAliases declared))
            }
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
  -> NominalId
  -> Located Variant
  -> Checker (Text, (NominalId, [Text], [Type]))
formVariant declared rigid owner (Located _ variant) = do
  payload <- case variantPayload variant of
    UnitPayload -> pure []
    TuplePayload members -> mapM (formType declared rigid) members
    RecordPayload fields -> map snd <$> mapM (formField declared rigid) fields
  pure (locatedValue (variantName variant), (owner, rigid, payload))

insertAll
  :: [(Text, (NominalId, [Text], [Type]))]
  -> Map Text (NominalId, [Text], [Type])
  -> Map Text (NominalId, [Text], [Type])
insertAll entries existing = foldr (\(key, value) acc -> Map.insert key value acc) existing entries
