{-| @Type.Check.Import.Module — installs body-free imported type interfaces -}
module Pudu.Type.Check.Import
  ( collectImportedDeclared
  , declareImportedTypes
  ) where

import Control.Monad (foldM, when)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function (..)
  , Import (..)
  , Impl (..)
  , TypeParam (..)
  )
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Type.Check.Foreign (declareForeign)
import Pudu.Type.Check.Method
  ( declareInterfaceMethods
  , declareBounds
  , declareTraitMembers
  , functionRigid
  )
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , emptyDeclared
  , inheritRestrictions
  , lookupName
  , recordComptimeFunction
  , recordUnsafeFunction
  )
import Pudu.Type.Formation
  ( collectDeclaredFrom
  , declaredParameterType
  , formOptionalType
  , formTraitReference
  , formType
  )
import Pudu.Type.Interface
  ( ImportTypes (..)
  , TypeInterface
  , interfaceBindings
  , interfaceDeclarations
  , interfaceDefaults
  , interfaceImports
  , interfaceModule
  , interfacePrivateDeclarations
  )
import Pudu.Type.Value
  ( NominalId (..)
  , Type (..)
  , canonicalNominal
  , monotype
  , nominalKey
  , polytype
  , restrictedBy
  )

collectImportedDeclared :: ImportTypes -> Checker DeclaredTypes
collectImportedDeclared imported = do
  collected <- foldM collectOne emptyDeclared (importedInterfaces imported)
  let aliases = Map.fromList
        [ (localName, target)
        | (localName, identity) <- Map.toList (importedNames imported)
        , Just target <- [Map.lookup (nominalKey identity) (declaredAliases collected)]
        ]
  pure collected
    { declaredNames = importedNames imported <> declaredNames collected
    , declaredAliases = aliases <> declaredAliases collected
    , declaredQualifiers = importedQualifiers imported <> declaredQualifiers collected
    }
 where
  available = Map.fromList [(interfaceModule value, value) | value <- importedInterfaces imported]
  collectOne accumulated value =
    collectDeclaredFrom
      accumulated{declaredNames = interfaceNames available value <> declaredNames accumulated}
      (interfaceModule value)
      (interfacePrivateDeclarations value <> interfaceDeclarations value)

declareImportedTypes :: DeclaredTypes -> ImportTypes -> Checker ()
declareImportedTypes declared imported = do
  mapM_ (declareInterface declared (importedTraits imported) available traits defaults) interfaces
  mapM_ bindImportedValue (Map.toList (importedValues imported))
 where
  interfaces = importedInterfaces imported
  available = Map.fromList [(interfaceModule value, value) | value <- interfaces]
  traits = Map.unionsWith (<>) (map interfaceTraits interfaces)
  defaults = foldMap interfaceDefaults interfaces
  {-| The name this module reaches an imported value by, which an alias makes
      different from the name the value was declared under.

      The restrictions follow the binding for the same reason they follow the
      module qualifier: renaming a function at the import is a change of
      spelling, not a change of what it is allowed to do. -}
  bindImportedValue (localName, canonicalName) = do
    found <- lookupName canonicalName
    maybe (pure ()) (bindName localName) found
    inheritRestrictions canonicalName localName

declareInterface
  :: DeclaredTypes
  -> Set.Set NominalId
  -> Map.Map ModuleName TypeInterface
  -> Map.Map NominalId [Located Function]
  -> Set.Set (NominalId, Text)
  -> TypeInterface
  -> Checker ()
declareInterface declared visibleTraits available traits defaults value = do
  let declarations = interfaceDeclarations value
  mapM_ (declareOne traits) declarations
  mapM_ declareImportedBinding (interfaceBindings value)
 where
  interfaceDeclared = declared
    { declaredNames = interfaceNames available value <> declaredNames declared
    , declaredAliases = interfaceAliases declared value <> declaredAliases declared
    }

  declareOne traitMembers (Located _ declaration) = case declaration of
    FunctionDeclaration function -> declareFunction interfaceDeclared function >> publishValue (locatedValue (functionName function))
    TypeDeclaration typeValue -> do
      declareConstructors interfaceDeclared typeValue
      case locatedValue (Tree.typeDefinition typeValue) of
        Tree.SumDefinition variants ->
          mapM_ (publishValue . locatedValue . Tree.variantName . locatedValue) variants
        _ -> pure ()
    TraitDeclaration trait -> declareTraitMembers interfaceDeclared trait
    ForeignDeclaration foreignValue -> do
      declareForeign interfaceDeclared foreignValue
      mapM_ (publishValue . locatedValue . Tree.foreignName . locatedValue)
        (Tree.foreignFunctions foreignValue)
    ImplDeclaration implementation -> do
      formed <- formTraitReference interfaceDeclared [] (implTrait implementation)
      case formed of
        NominalType identity _ ->
          when (Set.member identity visibleTraits)
            (declareInterfaceMethods interfaceDeclared traitMembers defaults implementation)
        _ -> pure ()
    _ -> pure ()

  {-| The same function under the name its module gives it.

      The restrictions follow the binding, because what a function may do cannot
      depend on whether it was reached directly or through its module. -}
  publishValue name = do
    found <- lookupName name
    let qualified = moduleNameText (interfaceModule value) <> "." <> name
    maybe (pure ()) (bindName qualified) found
    inheritRestrictions name qualified

  declareImportedBinding (name, syntax) = do
    formed <- formType interfaceDeclared [] syntax
    bindName name (monotype formed)
    publishValue name

interfaceNames :: Map.Map ModuleName TypeInterface -> TypeInterface -> Map.Map Text NominalId
interfaceNames available value = interfaceLocalNames value <> interfaceReferenceNames available value

interfaceLocalNames :: TypeInterface -> Map.Map Text NominalId
interfaceLocalNames value = Map.fromList (concatMap one declarations)
 where
  declarations = interfacePrivateDeclarations value <> interfaceDeclarations value
  owner = interfaceModule value
  one (Located _ declaration) = case declaration of
    TypeDeclaration typeValue -> identity (locatedValue (Tree.typeName typeValue))
    TraitDeclaration trait -> identity (locatedValue (Tree.traitName trait))
    ForeignDeclaration foreignValue ->
      concatMap (identity . locatedValue) (Tree.foreignTypes foreignValue)
    _ -> []
  identity name = [(name, canonicalNominal owner name)]

interfaceReferenceNames :: Map.Map ModuleName TypeInterface -> TypeInterface -> Map.Map Text NominalId
interfaceReferenceNames available value = foldMap one (interfaceImports value)
 where
  one (Located _ imported) = case Map.lookup (locatedValue (importModule imported)) available of
    Nothing -> Map.empty
    Just dependency -> Map.fromList (concatMap (binding imported) (interfaceIdentities dependency))

  binding imported (name, identity)
    | null selected = [(qualifier imported <> "." <> name, identity)]
    | name `elem` selected = [(name, identity)]
    | otherwise = []
   where
    selected = map locatedValue (importItems imported)

  qualifier imported = maybe
    (lastSegment (moduleNameText (locatedValue (importModule imported))))
    locatedValue
    (importAlias imported)

interfaceTraits :: TypeInterface -> Map.Map NominalId [Located Function]
interfaceTraits value = Map.fromList
  [ (canonicalNominal (interfaceModule value) (locatedValue (Tree.traitName trait)), Tree.traitMembers trait)
  | Located _ (TraitDeclaration trait) <- interfaceDeclarations value
  ]

interfaceAliases :: DeclaredTypes -> TypeInterface -> Map.Map Text ([Text], Type)
interfaceAliases declared value = Map.fromList
  [ (name, target)
  | Located _ (TypeDeclaration typeValue) <- declarations
  , let name = locatedValue (Tree.typeName typeValue)
  , Just target <- [Map.lookup (moduleNameText (interfaceModule value) <> "." <> name) (declaredAliases declared)]
  ]
 where
  declarations = interfacePrivateDeclarations value <> interfaceDeclarations value

interfaceIdentities :: TypeInterface -> [(Text, NominalId)]
interfaceIdentities value = concatMap one (interfaceDeclarations value)
 where
  owner = interfaceModule value
  one (Located _ declaration) = case declaration of
    TypeDeclaration typeValue -> identity (locatedValue (Tree.typeName typeValue))
    TraitDeclaration trait -> identity (locatedValue (Tree.traitName trait))
    ForeignDeclaration foreignValue ->
      concatMap (identity . locatedValue) (Tree.foreignTypes foreignValue)
    _ -> []
  identity name = [(name, canonicalNominal owner name)]

lastSegment :: Text -> Text
lastSegment value = case reverse (Text.splitOn "." value) of
  first : _ -> first
  [] -> value

{-| An imported signature, with the restrictions it was declared under.

    The restrictions travel with it because they are properties of the function
    rather than of the file it was written in. Without them an unsafe function
    became ordinary the moment it was imported, which made the boundary hold
    everywhere except across the edge it exists to guard — and putting bindings
    in a module of their own is the arrangement this library recommends. -}
declareFunction :: DeclaredTypes -> Function -> Checker ()
declareFunction declared value = do
  let rigid = functionRigid value
      name = locatedValue (functionName value)
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters value)
  result <- formOptionalType declared rigid (functionReturn value)
  bindName name
    ( polytype rigid (declareBounds declared value)
        ( restrictedBy (map locatedValue <$> functionUnsafe value)
            (FunctionTypeValue (functionAsync value) inputs result)
        )
    )
  case functionUnsafe value of
    Nothing -> pure ()
    Just capabilities -> recordUnsafeFunction name (map locatedValue capabilities)
  recordComptimeFunction name (functionComptime value)

declareConstructors :: DeclaredTypes -> Tree.TypeDeclarationValue -> Checker ()
declareConstructors declared value = case locatedValue (Tree.typeDefinition value) of
  Tree.SumDefinition variants -> mapM_ declareVariant variants
  _ -> pure ()
 where
  ownerName = locatedValue (Tree.typeName value)
  owner = Map.findWithDefault (NominalId Nothing ownerName) ownerName (declaredNames declared)
  rigid =
    [ (locatedValue (typeParamName param), typeParamArity param)
    | Located _ param <- Tree.typeTypeParams value
    ]
  ownerType = NominalType owner (map (RigidType . fst) rigid)
  declareVariant (Located _ variant) = do
    payload <- variantPayload declared rigid variant
    let name = locatedValue (Tree.variantName variant)
        scheme
          | null payload = polytype rigid [] ownerType
          | otherwise = polytype rigid [] (FunctionTypeValue False payload ownerType)
    bindName name scheme

variantPayload :: DeclaredTypes -> [(Text, Int)] -> Tree.Variant -> Checker [Type]
variantPayload declared rigid variant = case Tree.variantPayload variant of
  Tree.UnitPayload -> pure []
  Tree.TuplePayload members -> mapM (formType declared rigid) members
  Tree.RecordPayload fields ->
    mapM (\(Located _ field) -> formType declared rigid (Tree.fieldType field)) fields
