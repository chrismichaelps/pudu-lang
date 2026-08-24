{-| @Type.Check.Method.Module — types trait and implementation methods -}
module Pudu.Type.Check.Method
  ( declareBounds
  , declareMethods
  , declareInterfaceMethods
  , declareBuiltinConstructors
  , dischargeObligations
  , methodScheme
  , functionRigid
  , declareTraitMembers
  , implAliases
  , traitTable
  ) where

import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Constraint (..)
  , Declaration (..)
  , Function (..)
  , Impl (..)
  , Trait (..)
  , TypeParam (..)
  )
import Control.Monad (filterM, unless, when)
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindImportedMethod
  , bindName
  , implementsTrait
  , ambiguousProviders
  , markAmbiguousMethod
  , methodProvider
  , recordMethodProvider
  , lookupName
  , isImportedMethod
  , report
  , rigidBoundsOf
  , rigidSatisfies
  , takeObligations
  )
import Pudu.Type.Marker (isMarkerTrait, satisfiesMarker)
import Pudu.Type.Unify (zonk)
import Pudu.Type.Formation (declaredParameterType, formOptionalType, formType)
import Pudu.Type.Value
  ( NominalId (..)
  , Scheme
  , Type (..)
  , monotype
  , nominalKey
  , nominalName
  , polytype
  , renderType
  )

{-| Trait members by trait name, so an implementation can inherit the defaults
    it does not override. -}
traitTable :: DeclaredTypes -> [Located Declaration] -> Map.Map NominalId [Located Function]
traitTable declared declarations =
  Map.fromList
    [ (identity (locatedValue (traitName value)), traitMembers value)
    | Located _ (TraitDeclaration value) <- declarations
    ]
 where
  identity name = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)


{-| A trait's members are bound under the trait's own name, so a call on a value
    whose type is a parameter bounded by that trait can find them. `Self` stays
    rigid: the implementing type is not known here. -}
declareTraitMembers :: DeclaredTypes -> Trait -> Checker ()
declareTraitMembers declared value =
  mapM_ (declareTraitMember declared owner) (traitMembers value)
 where
  name = locatedValue (traitName value)
  owner = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)

declareTraitMember :: DeclaredTypes -> NominalId -> Located Function -> Checker ()
declareTraitMember declared owner (Located _ method) = do
  let rigid = "Self" : functionRigid method
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters method)
  result <- formOptionalType declared rigid (functionReturn method)
  bindName (methodKey owner (locatedValue (functionName method)))
    (polytype rigid [] (FunctionTypeValue (functionAsync method) inputs result))

{-| An impl's functions are methods of its target type, not module-scope names.
    They are bound under a qualified key so a member access on a value of that
    type finds them, and so one method may call another. -}
declareMethods :: DeclaredTypes -> Map.Map NominalId [Located Function] -> Impl -> Checker ()
declareMethods = declareMethodsWith Nothing

declareInterfaceMethods
  :: DeclaredTypes
  -> Map.Map NominalId [Located Function]
  -> Set (NominalId, Text)
  -> Impl
  -> Checker ()
declareInterfaceMethods declared traits defaults =
  declareMethodsWith (Just defaults) declared traits

declareMethodsWith
  :: Maybe (Set (NominalId, Text))
  -> DeclaredTypes
  -> Map.Map NominalId [Located Function]
  -> Impl
  -> Checker ()
declareMethodsWith defaults declared traits value = do
  target <- formType (implAliases declared value) [] (implTarget value)
  case targetName target of
    Nothing -> pure ()
    Just owner -> do
      mapM_ (declareMethod (defaults /= Nothing) declared value owner) (implFunctions value)
      mapM_ (declareMethod (defaults /= Nothing) declared value owner) (inheritedDefaults defaults declared traits value)

{-| A trait member that carries a body is a default: an implementation that does
    not override it still has it. -}
inheritedDefaults
  :: Maybe (Set (NominalId, Text))
  -> DeclaredTypes
  -> Map.Map NominalId [Located Function]
  -> Impl
  -> [Located Function]
inheritedDefaults defaults declared traits value = case implTraitName declared value of
  Nothing -> []
  Just traitText ->
    [ member
    | member@(Located _ method) <- maybe [] id (Map.lookup traitText traits)
    , isDefault traitText method
    , locatedValue (functionName method) `notElem` provided
    ]
 where
  provided = map (locatedValue . functionName . locatedValue) (implFunctions value)
  isDefault traitIdentity method = case defaults of
    Nothing -> functionBody method /= Nothing
    Just known -> Set.member (traitIdentity, locatedValue (functionName method)) known

implTraitName :: DeclaredTypes -> Impl -> Maybe NominalId
implTraitName declared value = case locatedValue (implTrait value) of
  Tree.NamedType path _ -> Map.lookup (moduleNameText path) (declaredNames declared)
  _ -> Nothing

declareMethod :: Bool -> DeclaredTypes -> Impl -> NominalId -> Located Function -> Checker ()
declareMethod rejectCollision declared value owner (Located methodSpan method) = do
  let rigid = implRigid value <> functionRigid method
      aliases = implAliases declared value
      key = methodKey owner (locatedValue (functionName method))
  inputs <- mapM (declaredParameterType aliases rigid) (functionParameters method)
  result <- formOptionalType aliases rigid (functionReturn method)
  existing <- lookupName key
  importedCollision <- if rejectCollision then pure (existing /= Nothing) else isImportedMethod key
  provider <- methodProvider key
  let providing = implTraitName declared value
      localCollision =
        not rejectCollision
          && maybe False (\earlier -> Just earlier /= providing) provider
  let scheme = polytype rigid [] (FunctionTypeValue (functionAsync method) inputs result)
  if importedCollision
    then do
      report "E3013" methodSpan
        (locatedValue (functionName method) <> " is ambiguous for " <> nominalName owner)
        (Just "import only one providing trait or use a qualified call")
      bindName key (monotype ErrorType)
    else do
      when localCollision $
        markAmbiguousMethod key (maybe [] pure provider <> maybe [] pure providing)
      mapM_ (recordMethodProvider key) providing
      if rejectCollision then bindImportedMethod key scheme else bindName key scheme

{-| `Self` inside an implementation is its target type, which is what lets a
    method read the fields of the value it was called on. -}
implAliases :: DeclaredTypes -> Impl -> DeclaredTypes
implAliases declared value = case implTargetName declared value of
  Nothing -> declared
  Just name ->
    declared
      { declaredAliases =
          Map.insert "Self" (NominalType name []) (declaredAliases declared)
      }

implTargetName :: DeclaredTypes -> Impl -> Maybe NominalId
implTargetName declared value = case locatedValue (implTarget value) of
  Tree.NamedType path _ -> Map.lookup (moduleNameText path) (declaredNames declared)
  _ -> Nothing

functionRigid :: Function -> [Text]
functionRigid value = map (locatedValue . typeParamName . locatedValue) (functionTypeParams value)

implRigid :: Impl -> [Text]
implRigid value = map (locatedValue . typeParamName . locatedValue) (implTypeParams value)

targetName :: Type -> Maybe NominalId
targetName typeValue = case typeValue of
  NominalType name _ -> Just name
  _ -> Nothing

methodKey :: NominalId -> Text -> Text
methodKey owner method = nominalKey owner <> "." <> method

{-| Prove every trait obligation a call registered.

    Obligations are discharged at the end of the function that raised them,
    while its own parameters' bounds are still in scope and after inference has
    solved what the argument types are.

    A rigid parameter satisfies a bound its own declaration declared, which is
    how a generic body may call another generic that demands the same trait. A
    variable that is still unsolved proves nothing and is left alone rather than
    guessed at. -}
dischargeObligations :: Checker ()
dischargeObligations = do
  obligations <- takeObligations
  mapM_ discharge obligations
 where
  discharge (spanValue, typeValue, traitText) = do
    resolved <- zonk typeValue
    case resolved of
      ErrorType -> pure ()
      VariableType _ -> pure ()
      RigidType name -> do
        satisfied <- rigidSatisfies name traitText
        unless satisfied (unsatisfied spanValue resolved traitText)
      NominalType owner _ -> do
        implemented <- implementsTrait owner traitText
        satisfied <- if implemented then pure True else marker traitText resolved
        unless satisfied (unsatisfied spanValue resolved traitText)
      _ -> do
        satisfied <- marker traitText resolved
        unless satisfied (unsatisfied spanValue resolved traitText)

  {-| A compiler-controlled marker is decided by the value's structure, not by
      a declaration, so it is consulted when no implementation was written. -}
  marker traitIdentity resolved
    | isMarkerTrait traitIdentity = satisfiesMarker traitIdentity resolved
    | otherwise = pure False
  {-| A marker cannot be implemented by hand, so telling the reader to write an
      implementation would send them at a diagnostic that rejects it. -}
  unsatisfied spanValue resolved traitIdentity =
    report "E3012" spanValue
      (renderType resolved <> " does not implement " <> nominalName traitIdentity)
      ( Just
          ( if isMarkerTrait traitIdentity
              then
                "this marker follows the type's structure; a value that owns a resource does not satisfy it"
              else "implement the trait for this type, or relax the bound"
          )
      )

{-| The constructors of the wired-in sums exist without any declaration, so
    they are bound before the module's own declarations are. A module that
    declares its own `Ok` shadows this binding rather than colliding with it. -}
declareBuiltinConstructors :: Checker ()
declareBuiltinConstructors = do
  bindName "Some"
    (polytype ["T"] [] (FunctionTypeValue False [RigidType "T"] optionOf))
  bindName "None" (polytype ["T"] [] optionOf)
  bindName "Ok"
    (polytype ["T", "E"] [] (FunctionTypeValue False [RigidType "T"] resultOf))
  bindName "Err"
    (polytype ["T", "E"] [] (FunctionTypeValue False [RigidType "E"] resultOf))
 where
  optionOf = NominalType "Option" [RigidType "T"]
  resultOf = NominalType "Result" [RigidType "T", RigidType "E"]

{-| The trait bounds a function's generic parameters carry, from the parameter
    list and from its `where` clause alike: both are obligations a call must
    satisfy, and [[grammar/pudu]] gives them the same meaning. -}
declareBounds :: DeclaredTypes -> Function -> [(Text, [NominalId])]
declareBounds declared value =
  [ (locatedValue (typeParamName param), map (boundName declared) (typeParamBounds param))
  | Located _ param <- functionTypeParams value
  ]
    <> [ (locatedValue (constraintSubject constraint), map (boundName declared) (constraintBounds constraint))
       | Located _ constraint <- functionConstraints value
       ]

boundName :: DeclaredTypes -> Located Tree.TypeSyntax -> NominalId
boundName declared (Located _ syntax) = case syntax of
  Tree.NamedType path _ ->
    Map.findWithDefault (NominalId Nothing (moduleNameText path))
      (moduleNameText path) (declaredNames declared)
  _ -> NominalId Nothing Text.empty

{-| Find a method for a receiver: on a nominal type through its
    implementations, on a rigid parameter through the traits its bounds
    declared. When two or more bounds provide the same member, the lookup is
    ambiguous and reports `E3013` once and returns an error scheme, so the
    caller does not fall through to `rigidMethod` and report it a second
    time. -}
methodScheme :: Span -> Type -> Text -> Checker (Maybe Scheme)
methodScheme spanValue receiver member = case receiver of
  NominalType owner _ -> do
    let key = nominalKey owner <> "." <> member
    providers <- ambiguousProviders key
    case providers of
      [] -> lookupName key
      _ -> do
        report "E3013" spanValue
          (member <> " is ambiguous for " <> nominalName owner)
          (Just ("call it qualified: " <> Text.intercalate " or " (map qualifiedForm providers)))
        pure (Just (monotype ErrorType))
   where
    qualifiedForm traitIdentity = nominalName traitIdentity <> "." <> member <> "(value)"
  RigidType name -> do
    bounds <- rigidBoundsOf name
    providers <- filterM provides bounds
    case providers of
      [] -> pure Nothing
      [traitText] -> lookupName (nominalKey traitText <> "." <> member)
      _ -> do
        report "E3013" spanValue
          (member <> " is ambiguous: provided by " <> Text.intercalate ", " (map nominalName providers))
          (Just "disambiguate with a qualified call or remove a trait bound")
        pure (Just (monotype ErrorType))
  _ -> pure Nothing
 where
  provides traitText = do
    found <- lookupName (nominalKey traitText <> "." <> member)
    pure (case found of Nothing -> False; Just _ -> True)
