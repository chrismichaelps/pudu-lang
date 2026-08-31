{-| @Type.Formation.Module — forms types from type syntax -}
module Pudu.Type.Formation
  ( collectDeclared
  , collectDeclaredFrom
  , declaredParameterType
  , formType
  , formTraitReference
  , formOptionalType
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Control.Monad (unless)
import qualified Data.Set as Set
import Pudu.Source (Span)
import Data.Text (Text)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments, moduleNameText)
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
import Pudu.Type.Env
  ( Checker
  , report
  , reportedAt
  , DeclaredTypes (..)
  , emptyDeclared
  , freshVariable
  )
import Pudu.Type.Value (NominalId (..), Type (..), canonicalNominal)

{-| Form a type from its syntax. Names that were declared as generic parameters
    become rigid; every other name is nominal, and an alias expands
    transparently as [[architecture/SEMANTICS]] requires. -}
formType :: DeclaredTypes -> [Text] -> Located TypeSyntax -> Checker Type
formType = formTypeWith True

{-| Form a type in a position where a trait name is what is meant: the head of
    an `impl`, or a bound. Nothing is rejected here. -}
formTraitReference :: DeclaredTypes -> [Text] -> Located TypeSyntax -> Checker Type
formTraitReference = formTypeWith False

formTypeWith :: Bool -> DeclaredTypes -> [Text] -> Located TypeSyntax -> Checker Type
formTypeWith valuePosition declared rigid (Located typeSpan syntax) = case syntax of
  {-| `dynamic Shape` is some value implementing `Shape`. Only a trait can stand
      here: `dynamic Circle` would be a dynamic type over a set with one member,
      which is `Circle` written the long way. -}
  DynamicType path -> case Map.lookup (moduleNameText path) (declaredNames declared) of
    Just identity
      | Set.member identity (declaredTraitNames declared) -> pure (DynamicTypeValue identity)
    Just _ -> do
      reportOnce typeSpan "E3031"
        (moduleNameText path <> " is not a trait, so dynamic cannot name it")
        "dynamic names a trait; write the type itself if you meant one type"
      pure ErrorType
    Nothing -> do
      reportOnce typeSpan "E3031" ("dynamic names no trait called " <> moduleNameText path)
        "declare the trait, import it, or check the spelling"
      pure ErrorType
  NamedType path arguments -> do
    formed <- mapM (formTypeWith valuePosition declared rigid) arguments
    refused <-
      if valuePosition then rejectTraitAsType declared typeSpan path else pure False
    unknown <- rejectUnknownQualifiedType declared typeSpan path
    applied <- rejectAppliedParameter rigid typeSpan path formed
    if refused || unknown || applied
      then pure ErrorType
      else pure (formNamed declared rigid path formed)
  ReferenceType mutable target ->
    ReferenceTypeValue mutable <$> formTypeWith valuePosition declared rigid target
  TupleType members ->
    TupleTypeValue <$> mapM (formTypeWith valuePosition declared rigid) members
  FunctionType asynchronous inputs result ->
    FunctionTypeValue asynchronous
      <$> mapM (formTypeWith valuePosition declared rigid) inputs
      <*> formTypeWith valuePosition declared rigid result
  UnitType -> pure UnitTypeValue
  InvalidType -> pure ErrorType

{-| A type parameter stands for a type, not for a type constructor, so it
    cannot be applied to arguments.

    Left unreported, the arguments were formed and then dropped: `F[Int]` and
    `F[Str]` both became `F`, so a signature could promise one and deliver the
    other and the two would unify. The reader was told nothing about a type the
    checker had not understood.

    The help names the two things a reader writing this means. Usually they want
    a generic type they can name — `Option[Int]` — and sometimes they want the
    argument to be a parameter of its own, which is a second parameter rather
    than an application of the first. -}
rejectAppliedParameter :: [Text] -> Span -> ModuleName -> [Type] -> Checker Bool
rejectAppliedParameter rigid typeSpan path arguments
  | null arguments = pure False
  | not unqualified = pure False
  | name `notElem` rigid = pure False
  | otherwise = do
      reportOnce typeSpan "E3038"
        (name <> " is a type parameter, so it cannot be given type arguments")
        ( "name the type you mean, as in Option[Int], or take the argument as its "
            <> "own parameter — fn f[" <> name <> ", A](value: " <> name <> ")"
        )
      pure True
 where
  pathText = moduleNameText path
  name = lastSegment path
  unqualified = pathText == name

{-| A trait names behaviour, not a value, and cannot stand where a type does.

    Left unreported, `fn draw(shape: Shape)` formed a nominal type that happened
    to share the trait's name, and the first value passed to it failed against
    that phantom: "expected Shape, found Circle". The reader is told the wrong
    thing about the wrong line — the mistake is in the signature, not the call.

    The help names the two forms that do work, because a reader writing this has
    a real intent and both of them serve it: a bounded parameter when one type
    is meant, and a sum when several are. -}
rejectTraitAsType :: DeclaredTypes -> Span -> ModuleName -> Checker Bool
rejectTraitAsType declared typeSpan path = case Map.lookup pathText (declaredNames declared) of
  Just identity
    | Set.member identity (declaredTraitNames declared) -> do
        reportOnce typeSpan "E3030"
          (pathText <> " is a trait, so it cannot be written as a type")
          ( "write dynamic " <> pathText <> " for a value whose type is not known here, "
              <> "or bound a type parameter by it — fn draw[T: " <> pathText <> "](shape: &T)"
          )
        pure True
  _ -> pure False
 where
  pathText = moduleNameText path

{-| A module cannot lend its name to a type it does not declare.

    Only the head of a type path is resolved, because a later segment selects
    through a module and that needs types to decide. Nothing decided them: an
    unfound qualified name became a nominal type of its own, named after what
    was written, so `M.Map[Str, Tally]` was a different type from
    `Map[Str, Tally]` and the reader was told "expected M.Map[Str, Tally], found
    Map[a, b]" — two names that read alike, about a type that never existed, at
    a line that was not the mistake.

    Judged only for a qualifier whose module was actually read. A qualifier that
    is not one of those is a module nothing could be known about, and an earlier
    attempt that skipped this distinction reported correct code — a type a
    module really declares looks exactly like one it does not when its interface
    was never available.

    This is the same mistake `E3033` reports for a value, and told apart the
    same way: a name that stands on its own is one the reader reached for
    through a module that does not have it — `Map` is built in, so it is written
    without a qualifier. -}
rejectUnknownQualifiedType :: DeclaredTypes -> Span -> ModuleName -> Checker Bool
rejectUnknownQualifiedType declared typeSpan path
  | unqualified = pure False
  | not (Set.member owner (declaredQualifiers declared)) = pure False
  | known pathText = pure False
  | otherwise = do
      reportOnce typeSpan "E3035"
        (owner <> " declares no type " <> name)
        ( if known name || name `elem` builtinTypeNames
            then name <> " stands on its own; write it without " <> owner <> "."
            else "check the spelling against what " <> owner <> " declares"
        )
      pure True
 where
  segments = NonEmpty.toList (moduleNameSegments path)
  pathText = moduleNameText path
  name = NonEmpty.last (moduleNameSegments path)
  owner = Text.intercalate "." (init segments)
  unqualified = pathText == name
  known key =
    Map.member key (declaredNames declared) || Map.member key (declaredAliases declared)

{-| The types the language itself provides, which belong to no module and are
    written without a qualifier.

    A reader who writes `M.Map` has reached for one of these through the module
    whose functions work on it. That is the commonest way to arrive at a
    qualified name nothing declares, and the one worth answering directly rather
    than sending them to read what the module exports. -}
builtinTypeNames :: [Text]
builtinTypeNames =
  [ "Array", "Str", "Map", "Set", "Char", "Bool", "Option", "Result", "Task"
  , "Int", "UInt", "BigInt", "Decimal", "Float", "Float32", "Float64"
  , "Int8", "Int16", "Int32", "Int64", "Int128"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128"
  ]

{-| Report a formation diagnostic at most once for a given span.

    A signature is formed both when it is declared and when its body is checked
    against it, and one mistake written in one signature is one mistake. -}
reportOnce :: Span -> Text -> Text -> Text -> Checker ()
reportOnce typeSpan code message help = do
  seen <- reportedAt typeSpan code
  unless seen (report code typeSpan message (Just help))

formNamed :: DeclaredTypes -> [Text] -> ModuleName -> [Type] -> Type
formNamed declared rigid path arguments
  | unqualified && name `elem` rigid = RigidType name
  | unqualified && name == "Never" = NeverType
  {-| An alias is a synonym, so writing it is writing what it stands for. A
      generic one substitutes its arguments: `type Boxed[T] = Option[T]` used as
      `Boxed[Int]` is `Option[Int]`, and before this it was a nominal type of
      its own that unified with nothing. An argument count that does not match
      is left nominal, so the mismatch is reported where the name is used
      rather than silently half-applied. -}
  | otherwise = case Map.lookup pathText (declaredAliases declared) of
      Just (parameters, aliased)
        | length parameters == length arguments ->
            expandAlias (zip parameters arguments) aliased
      _ -> NominalType (Map.findWithDefault fallback pathText (declaredNames declared)) arguments
 where
  pathText = moduleNameText path
  name = lastSegment path
  unqualified = pathText == name
  fallback = NominalId Nothing pathText

{-| Replace an alias's parameters with the arguments it was written with.

    Only the parameter names the alias declared are replaced, so a rigid name
    from the surrounding declaration keeps its own meaning. -}
expandAlias :: [(Text, Type)] -> Type -> Type
expandAlias replacements typeValue = case typeValue of
  RigidType name -> maybe typeValue id (lookup name replacements)
  NominalType identity arguments -> NominalType identity (map expand arguments)
  TupleTypeValue members -> TupleTypeValue (map expand members)
  FunctionTypeValue asynchronous inputs result ->
    FunctionTypeValue asynchronous (map expand inputs) (expand result)
  ReferenceTypeValue mutable target -> ReferenceTypeValue mutable (expand target)
  other -> other
 where
  expand = expandAlias replacements

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
builtinAliases :: Map Text ([Text], Type)
builtinAliases = Map.fromList [("Float", ([], NominalType "Float64" []))]

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
      , declaredTraitNames = Set.insert identity (declaredTraitNames declared)
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
  trait <- formTraitReference declared [] (implTrait value)
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
        let named =
              [ (variantName', fieldNames)
              | (variantName', _, Just fieldNames) <- entries
              ]
            payloads = [(variantName', shape) | (variantName', shape, _) <- entries]
        pure
          declared
            { declaredVariants = insertAll payloads (declaredVariants declared)
            , declaredVariantFields =
                foldr (\(key, value') acc -> Map.insert key value' acc)
                  (declaredVariantFields declared) named
            , declaredOwners = Map.insert identity (map fst payloads) (declaredOwners declared)
            }
      AliasDefinition aliased -> do
        {-| The alias body is formed with its own parameters rigid, so they can
            be found and replaced when the alias is written with arguments. -}
        let parameters = map (locatedValue . typeParamName . locatedValue) (typeTypeParams value)
        formed <- formType declared (parameters <> rigid) aliased
        let entry = (parameters, formed)
        pure
          declared
            { declaredAliases =
                Map.insert (moduleNameText owner <> "." <> name) entry
                  (Map.insert name entry (declaredAliases declared))
            }
      InvalidDefinition -> pure declared
  _ -> pure declared

formField :: DeclaredTypes -> [Text] -> Located FieldDeclaration -> Checker (Text, Type)
formField declared rigid (Located _ field) = do
  formed <- formType declared rigid (fieldType field)
  pure (locatedValue (fieldName field), formed)

{-| A variant is recorded under its own name together with the type it belongs
    to, which is how a constructor call and a pattern both find its payload.

    A variant written with field names carries the same positional payload as
    one written with types alone; the names come back alongside it so a
    construction and a pattern may say which element they mean. -}
formVariant
  :: DeclaredTypes
  -> [Text]
  -> NominalId
  -> Located Variant
  -> Checker (Text, (NominalId, [Text], [Type]), Maybe [Text])
formVariant declared rigid owner (Located _ variant) = do
  (payload, names) <- case variantPayload variant of
    UnitPayload -> pure ([], Nothing)
    TuplePayload members -> do
      formed <- mapM (formType declared rigid) members
      pure (formed, Nothing)
    RecordPayload fields -> do
      formed <- mapM (formField declared rigid) fields
      pure (map snd formed, Just (map fst formed))
  pure (locatedValue (variantName variant), (owner, rigid, payload), names)

insertAll
  :: [(Text, (NominalId, [Text], [Type]))]
  -> Map Text (NominalId, [Text], [Type])
  -> Map Text (NominalId, [Text], [Type])
insertAll entries existing = foldr (\(key, value) acc -> Map.insert key value acc) existing entries
