{-| @Type.Check.Method.Module — types trait and implementation methods -}
module Pudu.Type.Check.Method
  ( declareBounds
  , declareMethods
  , declareBuiltinConstructors
  , dischargeObligations
  , methodScheme
  , functionRigid
  , declareTraitMembers
  , implAliases
  , traitTable
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameSegments)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Constraint (..)
  , Declaration (..)
  , Function (..)
  , Impl (..)
  , Trait (..)
  , TypeParam (..)
  )
import Control.Monad (filterM, unless)
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , DeclaredTypes (..)
  , bindName
  , implementsTrait
  , lookupName
  , report
  , rigidBoundsOf
  , rigidSatisfies
  , takeObligations
  )
import Pudu.Type.Unify (zonk)
import Pudu.Type.Formation (declaredParameterType, formOptionalType, formType)
import Pudu.Type.Value (Scheme, Type (..), polytype, renderType)

{-| Trait members by trait name, so an implementation can inherit the defaults
    it does not override. -}
traitTable :: [Located Declaration] -> Map.Map Text [Located Function]
traitTable declarations =
  Map.fromList
    [ (locatedValue (traitName value), traitMembers value)
    | Located _ (TraitDeclaration value) <- declarations
    ]


{-| A trait's members are bound under the trait's own name, so a call on a value
    whose type is a parameter bounded by that trait can find them. `Self` stays
    rigid: the implementing type is not known here. -}
declareTraitMembers :: DeclaredTypes -> Trait -> Checker ()
declareTraitMembers declared value =
  mapM_ (declareTraitMember declared (locatedValue (traitName value))) (traitMembers value)

declareTraitMember :: DeclaredTypes -> Text -> Located Function -> Checker ()
declareTraitMember declared owner (Located _ method) = do
  let rigid = "Self" : functionRigid method
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters method)
  result <- formOptionalType declared rigid (functionReturn method)
  bindName (methodKey owner (locatedValue (functionName method)))
    (polytype rigid [] (FunctionTypeValue (functionAsync method) inputs result))

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
    (polytype rigid [] (FunctionTypeValue (functionAsync method) inputs result))

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
        satisfied <- implementsTrait owner traitText
        unless satisfied (unsatisfied spanValue resolved traitText)
      _ -> unsatisfied spanValue resolved traitText
  unsatisfied spanValue resolved traitText =
    report "E3012" spanValue
      (renderType resolved <> " does not implement " <> traitText)
      (Just "implement the trait for this type, or relax the bound")

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
declareBounds :: Function -> [(Text, [Text])]
declareBounds value =
  [ (locatedValue (typeParamName param), map boundName (typeParamBounds param))
  | Located _ param <- functionTypeParams value
  ]
    <> [ (locatedValue (constraintSubject constraint), map boundName (constraintBounds constraint))
       | Located _ constraint <- functionConstraints value
       ]

boundName :: Located Tree.TypeSyntax -> Text
boundName (Located _ syntax) = case syntax of
  Tree.NamedType path _ -> NonEmpty.last (moduleNameSegments path)
  _ -> Text.empty

{-| Find a method for a receiver: on a nominal type through its
    implementations, on a rigid parameter through the traits its bounds
    declared. When two or more bounds provide the same member, the lookup is
    ambiguous and reports `E3013` rather than silently picking the first. -}
methodScheme :: Span -> Type -> Text -> Checker (Maybe Scheme)
methodScheme spanValue receiver member = case receiver of
  NominalType owner _ -> lookupName (owner <> "." <> member)
  RigidType name -> do
    bounds <- rigidBoundsOf name
    providers <- filterM provides bounds
    case providers of
      [] -> pure Nothing
      [traitText] -> lookupName (traitText <> "." <> member)
      _ -> do
        report "E3013" spanValue
          (member <> " is ambiguous: provided by " <> Text.intercalate ", " providers)
          (Just "disambiguate with a qualified call or remove a trait bound")
        pure Nothing
  _ -> pure Nothing
 where
  provides traitText = do
    found <- lookupName (traitText <> "." <> member)
    pure (case found of Nothing -> False; Just _ -> True)
