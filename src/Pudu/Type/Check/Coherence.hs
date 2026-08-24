{-| @Type.Check.Coherence.Module — enforces implementation ownership and identity -}
module Pudu.Type.Check.Coherence
  ( checkCoherence
  ) where

import Control.Monad (foldM, unless)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Located (Located (..), mapLocated)
import Pudu.Frontend.Syntax.Name (ModuleName, moduleNameSegments, moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..)
  , Impl (..)
  , Trait (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , TypeParam (..)
  , TypeSyntax (..)
  )
import Pudu.Source (Span)
import Pudu.Type.Env (Checker, report)
import Pudu.Type.Marker (isUserImplementable)
import Pudu.Type.Value (NominalId (..))

data ImplementationKey = ImplementationKey !TypeKey !TypeKey
  deriving stock (Eq, Ord)

data Alias = Alias ![Text] !(Located TypeSyntax)

data LocalDeclarations = LocalDeclarations
  { localTraits :: !(Set Text)
  , localNominals :: !(Set Text)
  , localAliases :: !(Map Text Alias)
  }

data TypeKey
  = NamedKey !ModuleName ![TypeKey]
  | ParameterKey !Int
  | ReferenceKey !Bool !TypeKey
  | TupleKey ![TypeKey]
  | FunctionKey !Bool ![TypeKey] !TypeKey
  | UnitKey
  | InvalidKey
  deriving stock (Eq, Ord)

{-| Reject orphan implementations and every implementation head after the
    first structurally identical head. Generic binders use positional
    identities, so alpha-renaming cannot evade the duplicate check. -}
checkCoherence :: [Located Declaration] -> Checker ()
checkCoherence declarations = do
  let local = collectLocalDeclarations declarations
  mapM_ checkCompilerControlled (implementations declarations)
  mapM_ (checkOwnership local) (implementations declarations)
  _ <- foldM checkDuplicate Set.empty (implementationHeads declarations)
  pure ()

{-| `Copy` is compiler-controlled: [[architecture/SEMANTICS]] rejects a
    user-written implementation of it, because ownership checking decides which
    values duplicate from their structure. Writing one would claim a guarantee
    the compiler is the only party able to give. -}
checkCompilerControlled :: Impl -> Checker ()
checkCompilerControlled value = case traitHeadName (locatedValue (implTrait value)) of
  Just name
    | not (isUserImplementable (NominalId Nothing name)) ->
        report "E3021" (locatedSpan (implTrait value))
          (name <> " is compiler-controlled and cannot be implemented")
          (Just "remove the implementation; the compiler decides this marker from the type's structure")
  _ -> pure ()

traitHeadName :: TypeSyntax -> Maybe Text
traitHeadName syntax = case syntax of
  NamedType path _ -> unqualifiedName path
  _ -> Nothing

implementations :: [Located Declaration] -> [Impl]
implementations declarations =
  [ value
  | Located _ (ImplDeclaration value) <- declarations
  ]

implementationHeads :: [Located Declaration] -> [(Span, ImplementationKey)]
implementationHeads declarations =
  [ (locatedSpan (implTarget value), implementationKey value)
  | value <- implementations declarations
  ]

collectLocalDeclarations :: [Located Declaration] -> LocalDeclarations
collectLocalDeclarations = foldl' collect emptyLocalDeclarations
 where
  collect local (Located _ declaration) = case declaration of
    TraitDeclaration value ->
      local
        { localTraits = Set.insert (locatedValue (traitName value)) (localTraits local)
        }
    TypeDeclaration value -> collectType value local
    _ -> local

emptyLocalDeclarations :: LocalDeclarations
emptyLocalDeclarations = LocalDeclarations Set.empty Set.empty Map.empty

collectType :: TypeDeclarationValue -> LocalDeclarations -> LocalDeclarations
collectType value local =
  let name = locatedValue (typeName value)
      parameters = map (locatedValue . typeParamName . locatedValue) (typeTypeParams value)
   in case locatedValue (typeDefinition value) of
        AliasDefinition target ->
          local{localAliases = Map.insert name (Alias parameters target) (localAliases local)}
        RecordDefinition _ ->
          local{localNominals = Set.insert name (localNominals local)}
        SumDefinition _ ->
          local{localNominals = Set.insert name (localNominals local)}
        InvalidDefinition -> local

checkOwnership :: LocalDeclarations -> Impl -> Checker ()
checkOwnership local value =
  let parameters = Set.fromList
        (map (locatedValue . typeParamName . locatedValue) (implTypeParams value))
   in unless (ownsRoot parameters (localTraits local) local (locatedValue (implTrait value))
        || ownsRoot parameters (localNominals local) local (locatedValue (implTarget value))) $
    report "E3014" (locatedSpan (implTarget value))
      "orphan implementation: neither the trait nor target type is declared in this module"
      (Just "move this implementation to the module that declares the trait or target nominal type; aliases do not confer ownership")

{-| Follow transparent local aliases before asking whether the resulting root
    declaration belongs to this module. The visited set makes malformed alias
    cycles total without granting them ownership. -}
ownsRoot :: Set Text -> Set Text -> LocalDeclarations -> TypeSyntax -> Bool
ownsRoot parameters owners local = go Set.empty
 where
  go visited syntax = case syntax of
    NamedType path arguments -> case unqualifiedName path of
      Just name
        | Set.member name parameters -> False
        | otherwise ->
            case Map.lookup name (localAliases local) of
              Just (Alias aliasParameters target)
                | length aliasParameters == length arguments
                , Set.notMember name visited ->
                    let bindings = Map.fromList (zip aliasParameters arguments)
                     in go (Set.insert name visited)
                          (substituteType bindings (locatedValue target))
              _ -> Set.member name owners
      Nothing -> False
    _ -> False

substituteType :: Map Text (Located TypeSyntax) -> TypeSyntax -> TypeSyntax
substituteType bindings syntax = case syntax of
  NamedType path arguments -> case (unqualifiedName path, arguments) of
    (Just name, []) -> maybe syntax locatedValue (Map.lookup name bindings)
    _ -> NamedType path (map (mapLocated (substituteType bindings)) arguments)
  ReferenceType mutable target ->
    ReferenceType mutable (mapLocated (substituteType bindings) target)
  TupleType members -> TupleType (map (mapLocated (substituteType bindings)) members)
  FunctionType asynchronous inputs result ->
    FunctionType asynchronous
      (map (mapLocated (substituteType bindings)) inputs)
      (mapLocated (substituteType bindings) result)
  UnitType -> UnitType
  InvalidType -> InvalidType

unqualifiedName :: ModuleName -> Maybe Text
unqualifiedName path = case NonEmpty.toList (moduleNameSegments path) of
  [name] -> Just name
  _ -> Nothing

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
  case (unqualifiedName path, arguments) of
    (Just name, []) -> Map.lookup name parameters
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
