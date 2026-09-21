{-| @Type.Check.Install.Module — declares body-free interface signatures into a checker -}
module Pudu.Type.Check.Install
  ( installShared
  , installWanted
  , interfaceScope
  ) where

import Control.Monad (when)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Function (..)
  , Impl (..)
  , TypeParam (..)
  )
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Foreign.Crossing (RecordLayouts, recordLayouts)
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
  , inheritRestrictions
  , lookupName
  , recordComptimeFunction
  , recordUnsafeFunction
  )
import Pudu.Type.Formation
  ( declaredParameterType
  , formOptionalType
  , formTraitReference
  , formType
  )
import Pudu.Type.Interface
  ( TypeInterface
  , interfaceBindings
  , interfaceDeclarations
  , interfaceModule
  , interfacePrivateDeclarations
  )
import Pudu.Type.Value
  ( NominalId (..)
  , Required (..)
  , Type (..)
  , monotype
  , polytype
  , restrictedBy
  )

{-| The declarations an interface's types are formed against: its own names
    and the exported names of what it imports, over everything else known. -}
interfaceScope :: DeclaredTypes -> Map.Map Text NominalId -> TypeInterface -> DeclaredTypes
interfaceScope declared names value = declared
  { declaredNames = names <> declaredNames declared
  , declaredAliases = interfaceAliases declared value <> declaredAliases declared
  }

{-| What an interface declares whoever imports it: its constructors, its
    traits' members, and its foreign functions, each under its bare name and
    under its module's.

    None of these depends on the consumer's import list, which is why a graph
    installs them once for all of its modules; see [[Type Interface Graph]]. -}
installShared :: DeclaredTypes -> TypeInterface -> Checker ()
installShared scope value = mapM_ declareOne (interfaceDeclarations value)
 where
  declareOne (Located _ declaration) = case declaration of
    TypeDeclaration typeValue -> do
      declareConstructors scope typeValue
      case locatedValue (Tree.typeDefinition typeValue) of
        Tree.SumDefinition variants ->
          mapM_ (publishValue value . locatedValue . Tree.variantName . locatedValue) variants
        _ -> pure ()
    TraitDeclaration trait -> declareTraitMembers scope trait
    ForeignDeclaration foreignValue -> do
      declareForeign scope (interfaceLayouts value) foreignValue
      mapM_ (publishValue value . locatedValue . Tree.foreignName . locatedValue)
        (Tree.foreignFunctions foreignValue)
    _ -> pure ()

{-| What only a particular consumer receives from an interface: the functions
    and constants it imported, and the implementation methods of the traits it
    can see. -}
installWanted
  :: DeclaredTypes
  -> Set.Set NominalId
  -> Set.Set Text
  -> Map.Map NominalId [Located Function]
  -> Set.Set (NominalId, Text)
  -> TypeInterface
  -> Checker ()
installWanted scope visibleTraits wantedValues traits defaults value = do
  mapM_ declareOne (interfaceDeclarations value)
  mapM_ declareImportedBinding (interfaceBindings value)
 where
  wanted name = Set.member (moduleNameText (interfaceModule value) <> "." <> name) wantedValues

  declareOne (Located _ declaration) = case declaration of
    FunctionDeclaration function
      | wanted (locatedValue (functionName function)) ->
          declareFunction scope function >> publishValue value (locatedValue (functionName function))
    ImplDeclaration implementation -> do
      formed <- formTraitReference scope [] (implTrait implementation)
      case formed of
        NominalType identity _ ->
          when (Set.member identity visibleTraits)
            (declareInterfaceMethods scope traits defaults implementation)
        _ -> pure ()
    _ -> pure ()

  declareImportedBinding (name, syntax) =
    when (wanted name) $ do
      formed <- formType scope [] syntax
      bindName name (monotype formed)
      publishValue value name

{-| A record crossing by value must be declared beside the block that names it,
    so the layouts an interface contributes are its own. -}
interfaceLayouts :: TypeInterface -> RecordLayouts
interfaceLayouts value =
  recordLayouts (interfacePrivateDeclarations value <> interfaceDeclarations value)

{-| The same value under the name its module gives it.

    The restrictions follow the binding, because what a function may do cannot
    depend on whether it was reached directly or through its module. -}
publishValue :: TypeInterface -> Text -> Checker ()
publishValue value name = do
  found <- lookupName name
  let qualified = moduleNameText (interfaceModule value) <> "." <> name
  maybe (pure ()) (bindName qualified) found
  inheritRestrictions name qualified

interfaceAliases :: DeclaredTypes -> TypeInterface -> Map.Map Text ([Text], Type)
interfaceAliases declared value = Map.fromList
  [ (name, target)
  | Located _ (TypeDeclaration typeValue) <- declarations
  , let name = locatedValue (Tree.typeName typeValue)
  , Just target <- [Map.lookup (moduleNameText (interfaceModule value) <> "." <> name) (declaredAliases declared)]
  ]
 where
  declarations = interfacePrivateDeclarations value <> interfaceDeclarations value

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
            ( FunctionTypeRequiring (functionAsync value) inputs
                (Required (Tree.requiredParameterCount value))
                result
            )
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
