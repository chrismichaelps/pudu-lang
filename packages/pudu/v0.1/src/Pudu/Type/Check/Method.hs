{-| @Type.Check.Method.Module — types trait and implementation methods -}
module Pudu.Type.Check.Method
  ( declareBounds
  , declareBoundsWith
  , declareMethods
  , declareInterfaceMethods
  , declareBuiltinConstructors
  , effectNames
  , dischargeObligations
  , implBounds
  , implRigid
  , methodScheme
  , traitMethodScheme
  , targetName
  , traitBounds
  , traitRigid
  , functionRigid
  , declareTraitMembers
  , implAliases
  , traitTable
  ) where

import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Set (Set)
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
import Pudu.Type.Check.Inherit (inheritedMembers, renameApart, selfArguments)
import Pudu.Type.Check.Prelude (declareBuiltinConstructors, effectSignatures)
import Pudu.Type.Env
  ( noteStaticTrait
  , Checker
  , DeclaredTypes (..)
  , bindImportedMethod
  , bindName
  , recordDeclaredMethod
  , ambiguousProviders
  , markAmbiguousMethod
  , methodProvider
  , recordMethodProvider
  , lookupName
  , isImportedMethod
  , isMethodKey
  , report
  , rigidBoundsOf
  , lookupTypeParams
  , addObligation
  , takeObligations
  , TraitObligation (..)
  , ObligationKind (..)
  )
import Pudu.Semantic.Prelude (wiredInTypeNames)
import Pudu.Type.Marker (isMarkerTrait)
import Pudu.Type.Proof (TraitProof (..), implementsTrait, inferBound)
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Formation (declaredParameterType, formBoundFor, formOptionalType, formTraitReference, formType)
import Pudu.Type.Value
  ( NominalId (..)
  , Scheme (..)
  , Type (..)
  , monotype
  , nominalKey
  , nominalName
  , polytype
  , renderType
  )

{-| Traits by name, so an implementation can inherit the defaults
    it does not override. -}
traitTable :: DeclaredTypes -> [Located Declaration] -> Map.Map NominalId Trait
traitTable declared declarations =
  Map.fromList
    [ (identity (locatedValue (traitName value)), value)
    | Located _ (TraitDeclaration value) <- declarations
    ]
 where
  identity name = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)


{-| A trait's members are bound under the trait's own name, so a call on a value
    whose type is a parameter bounded by that trait can find them. `Self` stays
    rigid: the implementing type is not known here. -}
declareTraitMembers :: DeclaredTypes -> Trait -> Checker ()
declareTraitMembers declared value =
  mapM_
    (declareTraitMember declared owner (traitRigid value) (traitBounds declared value))
    (traitMembers value)
 where
  name = locatedValue (traitName value)
  owner = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)

{-| A trait's own type parameters are rigid inside its members, exactly as a
    function's are inside its body.

    Without this they were formed as nominal types named after the parameter,
    so `trait Holds[T] { fn get(self: &Self) -> T }` gave `get` a result of some
    type literally called `T` that nothing could ever be, and every use reported
    `expected Int, found T`. -}
traitRigid :: Trait -> [(Text, Int)]
traitRigid value = map rigidEntry (traitTypeParams value)

declareTraitMember
  :: DeclaredTypes
  -> NominalId
  -> [(Text, Int)]
  -> [(Text, [Type])]
  -> Located Function
  -> Checker ()
declareTraitMember declared owner traitParams bounds (Located _ method) = do
  let rigid = ("Self", 0) : traitParams <> functionRigid method
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters method)
  result <- formOptionalType declared rigid (functionReturn method)
  let scheme =
        polytype rigid (bounds <> declareBoundsWith declared traitParams method)
          (FunctionTypeValue (functionAsync method) inputs result)
  bindName (methodKey owner (locatedValue (functionName method))) scheme
  recordDeclaredMethod owner (functionName method) scheme
  case functionParameters method of
    Located _ first : _ | locatedValue (Tree.parameterName first) == "self" -> pure ()
    _ -> noteStaticTrait owner

{-| An impl's functions are methods of its target type, not module-scope names.
    They are bound under a qualified key so a member access on a value of that
    type finds them, and so one method may call another. -}
declareMethods
  :: DeclaredTypes
  -> Map.Map NominalId Trait
  -> Set (NominalId, Text)
  -> Impl
  -> Checker ()
declareMethods = declareMethodsWith False

declareInterfaceMethods
  :: DeclaredTypes
  -> Map.Map NominalId Trait
  -> Set (NominalId, Text)
  -> Impl
  -> Checker ()
declareInterfaceMethods = declareMethodsWith True

{-| `traits` holds every trait an implementation here may name, its own module's
    and the ones it imports; `defaults` names the imported members that carry a
    body the interface stripped. -}
declareMethodsWith
  :: Bool
  -> DeclaredTypes
  -> Map.Map NominalId Trait
  -> Set (NominalId, Text)
  -> Impl
  -> Checker ()
declareMethodsWith rejectCollision declared traits defaults value = do
  target <- formType (implAliases declared value) [] (implTarget value)
  case targetName target of
    Nothing -> pure ()
    Just owner -> do
      mapM_ (declareMethod rejectCollision declared value owner Nothing) (implFunctions value)
      case implTraitName declared value >>= \identity -> fmap ((,) identity) (Map.lookup identity traits) of
        Nothing -> pure ()
        Just (identity, trait) -> do
          formed <- formTraitReference declared (implRigid value) (implTrait value)
          let arguments = case formed of
                NominalType _ held -> held
                _ -> []
              replacements =
                ("Self", NominalType owner (selfArguments (map fst (implRigid value)) value))
                  : zip (map fst (traitRigid trait)) arguments
          mapM_
            (declareMethod rejectCollision declared value owner (Just (identity, replacements)))
            (inheritedMembers defaults identity trait value)

implTraitName :: DeclaredTypes -> Impl -> Maybe NominalId
implTraitName declared value = case locatedValue (implTrait value) of
  Tree.NamedType path _ -> Map.lookup (moduleNameText path) (declaredNames declared)
  _ -> Nothing

{-| Declare one method of an implementation's target.

    An inherited default takes the scheme its trait member was given, formed
    once in the trait module's own names with `Self` and the trait's parameters
    rigid, and replaces each of those by what this implementation gives it, all
    at once: `twice` from `trait Holds[T]` is `(Int, Int)` on an
    `impl Holds[Int]`. -}
declareMethod
  :: Bool
  -> DeclaredTypes
  -> Impl
  -> NominalId
  -> Maybe (NominalId, [(Text, Type)])
  -> Located Function
  -> Checker ()
declareMethod rejectCollision declared value owner inherited (Located methodSpan method) = do
  let aliases = implAliases declared value
      key = methodKey owner (locatedValue (functionName method))
  (rigid, bounds, signature) <- case inherited of
    Nothing -> do
      let rigid = implRigid value <> functionRigid method
      inputs <- mapM (declaredParameterType aliases rigid) (functionParameters method)
      result <- formOptionalType aliases rigid (functionReturn method)
      pure (rigid, declareBoundsWith aliases (implRigid value) method, FunctionTypeValue (functionAsync method) inputs result)
    Just (trait, replacements) -> do
      declaredScheme <- lookupName (methodKey trait (locatedValue (functionName method)))
      let ownNames = map fst (functionRigid method)
          (own, renamed) = renameApart (map fst (implRigid value)) (functionRigid method)
          replace = substituteRigid (replacements <> renamed)
          renamedTo name = fromMaybe name (lookup name (zip ownNames (map fst own)))
      pure $ case declaredScheme of
        Just declaredAs ->
          ( implRigid value <> own
          , [(renamedTo name, map replace held) | (name, held) <- schemeBounds declaredAs, name `elem` ownNames]
          , replace (schemeType declaredAs)
          )
        Nothing -> (implRigid value, [], ErrorType)
  existing <- lookupName key
  importedCollision <- if rejectCollision then pure (existing /= Nothing) else isImportedMethod key
  provider <- methodProvider key
  let providing = implTraitName declared value
      localCollision =
        not rejectCollision
          && maybe False (\earlier -> Just earlier /= providing) provider
  let scheme = polytype rigid (implBounds declared value <> bounds) signature
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
      if rejectCollision
        then bindImportedMethod key scheme
        else do
          bindName key scheme
          recordDeclaredMethod owner (functionName method) scheme

{-| `Self` inside an implementation is its target type, which is what lets a
    method read the fields of the value it was called on. -}
implAliases :: DeclaredTypes -> Impl -> DeclaredTypes
implAliases declared value = case implTargetName declared value of
  Nothing -> declared
  Just name ->
    declared
      { declaredAliases =
          Map.insert "Self" ([], NominalType name (selfArguments (map fst (implRigid value)) value)) (declaredAliases declared)
      }

{-| The nominal type an implementation is for.

    A wired-in type is not in `declaredNames` — no module declared it — so a
    name that is not there but is one the compiler wires in becomes its own
    nominal identity. Without this, `impl Ord for Str` leaves `Self` unaliased
    and its own body fails to check against the type it was written for. -}
implTargetName :: DeclaredTypes -> Impl -> Maybe NominalId
implTargetName declared value = case locatedValue (implTarget value) of
  Tree.NamedType path _ ->
    let name = moduleNameText path
     in case Map.lookup name (declaredNames declared) of
          Just found -> Just found
          Nothing
            | name `elem` wiredInTypeNames -> Just (NominalId Nothing name)
            | otherwise -> Nothing
  _ -> Nothing

functionRigid :: Function -> [(Text, Int)]
functionRigid value = map rigidEntry (functionTypeParams value)

implRigid :: Impl -> [(Text, Int)]
implRigid value = map rigidEntry (implTypeParams value)

{-| A parameter's name beside how many arguments it takes, which is what type
    formation needs to tell an application apart from a mistake. -}
rigidEntry :: Located TypeParam -> (Text, Int)
rigidEntry (Located _ param) = (locatedValue (typeParamName param), typeParamArity param)

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
  dischargeAll [] obligations
 where
  dischargeAll _ [] = pure ()
  dischargeAll seen (TraitObligation kind spanValue typeValue written : rest) = do
    resolved <- zonk typeValue
    bound <- zonk written
    let key = (kind, spanValue, resolved, bound)
    unless (key `elem` seen) (discharge kind spanValue resolved bound)
    dischargeAll (key : seen) rest

  discharge kind spanValue resolved bound =
    case resolved of
      ErrorType -> pure ()
      VariableType _ -> pure ()
      _ -> do
        case (kind, bound) of
          (DynamicWidening, NominalType owner _) -> do
            satisfied <- implementsTrait resolved owner
            unless satisfied (unsatisfied kind spanValue resolved bound)
          _ -> do
            (answer, proposals) <- inferBound resolved bound
            case answer of
              Proven -> mapM_ (\(variable, selected) -> () <$ unify spanValue (VariableType variable) selected) proposals
              ProofAmbiguous -> report "E3012" spanValue
                ("cannot determine a unique " <> renderType bound <> " implementation for " <> renderType resolved)
                (Just "state the missing type argument explicitly")
              _ -> unsatisfied kind spanValue resolved bound
  {-| A marker cannot be implemented by hand, so telling the reader to write an
      implementation would send them at a diagnostic that rejects it. -}
  unsatisfied DynamicWidening spanValue resolved bound =
    report "E3032" spanValue
      (renderType resolved <> " does not implement " <> renderType bound)
      (Just ("implement it for this type, or use a type that does; a dynamic "
        <> renderType bound <> " holds only values that implement it"))
  unsatisfied CallBound spanValue resolved bound =
    report "E3012" spanValue
      (renderType resolved <> " does not implement " <> renderType bound)
      ( Just
          ( if maybe False isMarkerTrait (targetName bound)
              then
                "this marker follows the type's structure; a value that owns a resource does not satisfy it"
              else "implement the trait for this type, or relax the bound"
          )
      )

effectNames :: [Text]
effectNames = map fst effectSignatures

{-| The trait bounds a function's generic parameters carry, from the parameter
    list and from its `where` clause alike: both are obligations a call must
    satisfy, and [[grammar/pudu]] gives them the same meaning. -}
declareBounds :: DeclaredTypes -> Function -> [(Text, [Type])]
declareBounds declared = declareBoundsWith declared []

declareBoundsWith :: DeclaredTypes -> [(Text, Int)] -> Function -> [(Text, [Type])]
declareBoundsWith declared enclosing value =
  [ (locatedValue (typeParamName param), map (form (locatedValue (typeParamName param))) (typeParamBounds param))
  | Located _ param <- functionTypeParams value
  ]
    <> [ (locatedValue (constraintSubject constraint), map (form (locatedValue (constraintSubject constraint))) (constraintBounds constraint))
       | Located _ constraint <- functionConstraints value
       ]
 where
  form = formBoundFor declared (enclosing <> functionRigid value)

{-| The bounds an implementation's own type parameters carry, so a method may
    call what those bounds promise. `impl[N: Ord + Add] Sequence[N, N] for
    Range[N]` means `N` has `before` and `plus` inside every method here, and
    without installing them the methods were told `N has no method before`
    about a parameter whose declaration says it does. -}
implBounds :: DeclaredTypes -> Impl -> [(Text, [Type])]
implBounds declared value =
  [ (locatedValue (typeParamName param), map (form (locatedValue (typeParamName param))) (typeParamBounds param))
  | Located _ param <- implTypeParams value
  ]
    <> [ (locatedValue (constraintSubject constraint), map (form (locatedValue (constraintSubject constraint))) (constraintBounds constraint))
       | Located _ constraint <- implConstraints value
       ]
 where
  form = formBoundFor declared (implRigid value)

{-| The bounds a trait's own type parameters carry. -}
traitBounds :: DeclaredTypes -> Trait -> [(Text, [Type])]
traitBounds declared value =
  [ (locatedValue (typeParamName param), map (form (locatedValue (typeParamName param))) (typeParamBounds param))
  | Located _ param <- traitTypeParams value
  ]
    <> [ (locatedValue (constraintSubject constraint), map (form (locatedValue (constraintSubject constraint))) (constraintBounds constraint))
       | Located _ constraint <- traitConstraints value
       ]
 where
  form = formBoundFor declared (traitRigid value)

{-| Find a method for a receiver: on a nominal type through its
    implementations, on a rigid parameter through the traits its bounds
    declared. When two or more bounds provide the same member, the lookup is
    ambiguous and reports `E3013` once and returns an error scheme, so the
    caller does not fall through to `rigidMethod` and report it a second
    time. -}
methodScheme :: Span -> Type -> Text -> Checker (Maybe Scheme)
methodScheme spanValue receiver member = case receiver of
  {-| A dynamic value answers with the trait's own declaration, which is the
      only thing known about it. `Self` stays rigid there, so a member that
      returns `Self` is not callable through a `dynamic` — the caller would have no
      type to give the result. That is a real restriction and it is the honest
      one: the concrete type is exactly what a dynamic value does not carry. -}
  DynamicTypeValue traitIdentity ->
    lookupName (nominalKey traitIdentity <> "." <> member)
  NominalType owner _ -> do
    let key = nominalKey owner <> "." <> member
    providers <- ambiguousProviders key
    case providers of
      -- A built-in type's key has no module in it, so a module imported under
      -- the type's own name puts its functions at the key a method would have;
      -- only a declared method answers for the type.
      [] | nominalModule owner == Nothing -> do
        method <- isMethodKey key
        if method then lookupName key else pure Nothing
      [] -> lookupName key
      _ -> do
        report "E3013" spanValue
          (member <> " is ambiguous for " <> nominalName owner)
          (Just ("call it qualified: " <> Text.intercalate " or " (map qualifiedForm providers)))
        pure (Just (monotype ErrorType))
   where
    qualifiedForm traitIdentity = nominalName traitIdentity <> "." <> member <> "(value)"
  {-| A parameter of higher kind carries its bounds on the parameter itself, so
      a receiver of type `F[A]` finds its members exactly where a receiver of
      type `F` would. The arguments say what the container holds and never which
      trait provides a member. -}
  AppliedType head' _ -> methodScheme spanValue head' member
  RigidType name -> rigidBoundsOf name >>= selectBounds spanValue receiver member
  _ -> pure Nothing

traitMethodScheme :: Span -> Type -> NominalId -> Text -> Checker (Maybe Scheme)
traitMethodScheme at receiver owner member = case receiver of
  RigidType name -> rigidBoundsOf name >>= selectBounds at receiver member . filter owns
  AppliedType (RigidType name) _ -> rigidBoundsOf name >>= selectBounds at receiver member . filter owns
  _ -> pure Nothing
 where
  owns (NominalType identity _) = identity == owner
  owns _ = False

selectBounds :: Span -> Type -> Text -> [Type] -> Checker (Maybe Scheme)
selectBounds at receiver member bounds = do
  providers <- filterM provides bounds
  case providers of
    [] -> pure Nothing
    [bound@(NominalType owner _)] -> do
      found <- lookupName (nominalKey owner <> "." <> member)
      traverse (specializeBound at receiver bound) found
    _ -> do
      report "E3013" at
        (member <> " is ambiguous: provided by " <> Text.intercalate ", " (map renderType providers))
        (Just "disambiguate with a qualified call or remove a trait bound")
      pure (Just (monotype ErrorType))
 where
  provides (NominalType owner _) = do
    found <- lookupName (nominalKey owner <> "." <> member)
    pure (case found of Nothing -> False; Just _ -> True)
  provides _ = pure False

specializeBound :: Span -> Type -> Type -> Scheme -> Checker Scheme
specializeBound at receiver (NominalType owner arguments) scheme = do
  parameters <- maybe [] id <$> lookupTypeParams owner
  let replacements = ("Self", receiver) : zip parameters arguments
      replace = substituteRigid replacements
  mapM_ (\(name, bounds) -> case lookup name replacements of
    Just subject -> mapM_ (addObligation at subject . replace) bounds
    Nothing -> pure ()) (schemeBounds scheme)
  pure scheme
    { schemeParams = filter (\(name, _) -> name `notElem` map fst replacements) (schemeParams scheme)
    , schemeBounds = [(name, map replace bounds) | (name, bounds) <- schemeBounds scheme
        , name `notElem` map fst replacements]
    , schemeType = replace (schemeType scheme) }
specializeBound _ _ _ scheme = pure scheme
