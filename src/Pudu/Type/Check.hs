{-| @Type.Check.Module — checks declarations, statements, and expressions -}
module Pudu.Type.Check
  ( checkModule
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import qualified Pudu.Frontend.Syntax.Tree as Tree
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , Function (..)
  , FunctionBody (..)
  , Impl (..)
  , MatchArm (..)
  , Module (..)
  , Parameter
  , Statement (..)
  , Trait (..)
  , TypeParam (..)
  , Visibility (Exported)
  )
import Pudu.Source (Span)
import Pudu.Type.Env
  ( Checker
  , CheckerProducts (..)
  , DeclaredTypes (..)
  , bindName
  , freshVariable
  , inTypeScope
  , lookupField
  , lookupName
  , recordExpression
  , report
  , runChecker
  , withDeclared
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Rule
  ( binaryType
  , instantiate
  , callType
  , elementType
  , literalType
  , memberType
  , nameType
  , unaryType
  )
import Pudu.Type.Check.Method (declareMethods, implAliases, traitTable)
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation
  ( collectDeclared
  , declaredParameterType
  , formOptionalType
  , formType
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( Scheme (..)
  , Type (..)
  , boolType
  , integerType
  , renderType
  )

{-| Check one module. Signatures are collected before any body is checked, so a
    function may call one declared later without a forward declaration. -}
checkModule :: Module -> ([((Int, Int), Type)], [Diagnostic])
checkModule moduleValue =
  let products = runChecker (checkUnit moduleValue)
   in (producedTypes products, producedDiagnostics products)

checkUnit :: Module -> Checker ()
checkUnit moduleValue = do
  declared <- collectDeclared (moduleDeclarations moduleValue)
  withDeclared declared
  declareBuiltinConstructors
  let traits = traitTable (moduleDeclarations moduleValue)
  mapM_ (declareSignature declared traits) (moduleDeclarations moduleValue)
  mapM_ (checkDeclaration declared) (moduleDeclarations moduleValue)

{-| The constructors of the wired-in sums exist without any declaration, so
    they are bound before the module's own declarations are. A module that
    declares its own `Ok` shadows this binding rather than colliding with it. -}
declareBuiltinConstructors :: Checker ()
declareBuiltinConstructors = do
  bindName "Some"
    (Scheme ["T"] (FunctionTypeValue False [RigidType "T"] optionOf))
  bindName "None" (Scheme ["T"] optionOf)
  bindName "Ok"
    (Scheme ["T", "E"] (FunctionTypeValue False [RigidType "T"] resultOf))
  bindName "Err"
    (Scheme ["T", "E"] (FunctionTypeValue False [RigidType "E"] resultOf))
 where
  optionOf = NominalType "Option" [RigidType "T"]
  resultOf = NominalType "Result" [RigidType "T", RigidType "E"]

{-| Give every module-scope declaration a type before bodies are checked. -}
declareSignature
  :: DeclaredTypes -> Map.Map Text [Located Function] -> Located Declaration -> Checker ()
declareSignature declared traits (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name annotation _ -> do
    formed <- formOptionalType declared [] annotation
    bindName (locatedValue name) (Scheme [] formed)
  FunctionDeclaration value -> declareFunction declared value
  TypeDeclaration value -> declareConstructors declared value
  ImplDeclaration value -> declareMethods declared traits value
  _ -> pure ()


declareFunction :: DeclaredTypes -> Function -> Checker ()
declareFunction declared value = do
  let rigid = functionRigid value
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters value)
  result <- formOptionalType declared rigid (functionReturn value)
  bindName (locatedValue (functionName value))
    (Scheme rigid (FunctionTypeValue (functionAsync value) inputs result))

functionRigid :: Function -> [Text]
functionRigid value = map (locatedValue . typeParamName . locatedValue) (functionTypeParams value)


{-| A sum's variants become constructors: a payload-carrying variant is a
    function to its own type, a unit variant is a value of it. -}
declareConstructors :: DeclaredTypes -> Tree.TypeDeclarationValue -> Checker ()
declareConstructors declared value = case locatedValue (Tree.typeDefinition value) of
  Tree.SumDefinition variants -> mapM_ declareVariant variants
  _ -> pure ()
 where
  owner = locatedValue (Tree.typeName value)
  rigid = map (locatedValue . typeParamName . locatedValue) (Tree.typeTypeParams value)
  ownerType = NominalType owner (map RigidType rigid)
  declareVariant (Located _ variant) = do
    payload <- variantPayload declared rigid variant
    let name = locatedValue (Tree.variantName variant)
        scheme
          | null payload = Scheme rigid ownerType
          | otherwise = Scheme rigid (FunctionTypeValue False payload ownerType)
    bindName name scheme

variantPayload :: DeclaredTypes -> [Text] -> Tree.Variant -> Checker [Type]
variantPayload declared rigid variant = case Tree.variantPayload variant of
  Tree.UnitPayload -> pure []
  Tree.TuplePayload members -> mapM (formType declared rigid) members
  Tree.RecordPayload fields ->
    mapM (\(Located _ field) -> formType declared rigid (Tree.fieldType field)) fields

checkDeclaration :: DeclaredTypes -> Located Declaration -> Checker ()
checkDeclaration declared (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name annotation value -> do
    expected <- formOptionalType declared [] annotation
    actual <- checkExpression declared [] value
    _ <- unify (locatedSpan value) expected actual
    bindName (locatedValue name) (Scheme [] expected)
  FunctionDeclaration value -> checkFunction declared value
  TraitDeclaration value ->
    mapM_ (checkMember (traitAliases declared)) (traitMembers value)
  ImplDeclaration value ->
    mapM_ (checkMember (implAliases declared value)) (implFunctions value)
  _ -> pure ()

checkMember :: DeclaredTypes -> Located Function -> Checker ()
checkMember declared (Located _ value) = checkFunction declared value

{-| `Self` inside a trait is the implementing type, which is unknown while the
    trait itself is checked, so it stays a rigid parameter there. -}
traitAliases :: DeclaredTypes -> DeclaredTypes
traitAliases = id

{-| Check a function body against its declared result. An exported function
    must annotate what it promises, because [[grammar/pudu]] makes an exported
    signature a compatibility boundary that callers read without the body. -}
checkFunction :: DeclaredTypes -> Function -> Checker ()
checkFunction declared value = do
  let rigid = functionRigid value
  requireExportedAnnotations value
  inTypeScope $ do
    inputs <- mapM (bindParameter declared rigid) (functionParameters value)
    result <- formOptionalType declared rigid (functionReturn value)
    bindName selfName (Scheme [] (FunctionTypeValue (functionAsync value) inputs result))
    case functionBody value of
      Nothing -> pure ()
      Just (Located bodySpan body) -> do
        actual <- case body of
          BlockBody block -> checkBlock declared rigid block
          ExpressionBody expression -> checkExpression declared rigid expression
        _ <- unify bodySpan result actual
        pure ()

selfName :: Text
selfName = "__return"

requireExportedAnnotations :: Function -> Checker ()
requireExportedAnnotations value
  | functionVisibility value /= Exported = pure ()
  | otherwise = do
      mapM_ requireParameter (functionParameters value)
      case functionReturn value of
        Just _ -> pure ()
        Nothing ->
          report "E3010" (locatedSpan (functionName value))
            ("exported function " <> locatedValue (functionName value) <> " needs a return type")
            (Just "annotate the return type; an exported signature is read without its body")
 where
  requireParameter (Located parameterSpan parameter) = case Tree.parameterType parameter of
    Just _ -> pure ()
    Nothing ->
      report "E3010" parameterSpan
        ("exported parameter " <> locatedValue (Tree.parameterName parameter) <> " needs a type")
        (Just "annotate every parameter of an exported function")

bindParameter :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
bindParameter declared rigid (Located _ parameter) = do
  formed <- formOptionalType declared rigid (Tree.parameterType parameter)
  case Tree.parameterDefault parameter of
    Nothing -> pure ()
    Just expression -> do
      actual <- checkExpression declared rigid expression
      _ <- unify (locatedSpan expression) formed actual
      pure ()
  bindName (locatedValue (Tree.parameterName parameter)) (Scheme [] formed)
  pure formed

{-| A block's type is its trailing expression, or unit when it has none. -}
checkBlock :: DeclaredTypes -> [Text] -> Located Block -> Checker Type
checkBlock declared rigid (Located _ block) = do
  mapM_ (checkStatement declared rigid) (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitTypeValue
    Just expression -> checkExpression declared rigid expression

checkStatement :: DeclaredTypes -> [Text] -> Located Statement -> Checker ()
checkStatement declared rigid (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name annotation value)) -> do
    expected <- formOptionalType declared rigid annotation
    actual <- checkExpression declared rigid value
    unified <- unify (locatedSpan value) expected actual
    bindName (locatedValue name) (Scheme [] unified)
  DeclarationStatement other -> checkDeclaration declared other
  ExpressionStatement expression -> do
    _ <- checkExpression declared rigid expression
    pure ()
  ReturnStatement value -> do
    actual <- case value of
      Nothing -> pure UnitTypeValue
      Just expression -> checkExpression declared rigid expression
    expected <- returnType
    case value of
      Nothing -> pure ()
      Just expression -> do
        _ <- unify (locatedSpan expression) expected actual
        pure ()
  BreakStatement -> pure ()
  ContinueStatement -> pure ()
  InvalidStatement -> pure ()

{-| `?` unwraps a `Result` and propagates its failure, so it is admitted only
    inside a function that returns a `Result` carrying the same failure type.
    Conversion through `From` is the slice that introduces trait resolution. -}
tryType :: Span -> Type -> Checker Type
tryType spanValue targetType = do
  success <- freshVariable
  failure <- freshVariable
  _ <- unify spanValue (NominalType "Result" [success, failure]) targetType
  declaredResult <- returnType >>= zonk
  case declaredResult of
    NominalType "Result" [_, declaredFailure] -> do
      _ <- unify spanValue declaredFailure failure
      pure success
    VariableType _ -> do
      resultSuccess <- freshVariable
      _ <- unify spanValue declaredResult (NominalType "Result" [resultSuccess, failure])
      pure success
    ErrorType -> pure ErrorType
    _ -> do
      report "E3011" spanValue
        ("? needs a function returning Result, found " <> renderType declaredResult)
        (Just "declare the function's result as Result, or match the value instead")
      pure success

returnType :: Checker Type
returnType = do
  found <- lookupName selfName
  case found of
    Just (Scheme _ (FunctionTypeValue _ _ result)) -> pure result
    _ -> freshVariable

{-| A member in callee position prefers a method over a field of the same
    name, because `value.name()` reads as a call and a field would have to be
    parenthesized to be called anyway. -}
checkCallee :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkCallee declared rigid located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    targetType <- checkExpression declared rigid target
    resolved <- zonk targetType
    method <- case resolved of
      NominalType owner _ -> lookupName (owner <> "." <> locatedValue member)
      _ -> pure Nothing
    case method of
      Nothing -> checkExpression declared rigid located
      Just scheme -> do
        instantiated <- instantiate scheme
        let applied = case instantiated of
              FunctionTypeValue asynchronous (_ : rest) result ->
                FunctionTypeValue asynchronous rest result
              other -> other
        recordExpression calleeSpan applied
        pure applied
  _ -> checkExpression declared rigid located

{-| Check one expression and record the type it was given, so tooling can
    report it later. -}
checkExpression :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkExpression declared rigid (Located spanValue expression) = do
  typeValue <- inferExpression declared rigid spanValue expression
  resolved <- zonk typeValue
  recordExpression spanValue resolved
  pure typeValue

inferExpression :: DeclaredTypes -> [Text] -> Span -> Expression -> Checker Type
inferExpression declared rigid spanValue expression = case expression of
  LiteralExpression literal -> pure (literalType literal)
  NameExpression names -> nameType spanValue names
  UnaryExpression operator operand -> do
    actual <- checkExpression declared rigid operand
    unaryType spanValue operator actual
  BinaryExpression left operator right -> do
    leftType <- checkExpression declared rigid left
    rightType <- checkExpression declared rigid right
    binaryType spanValue operator leftType rightType
  CallExpression callee arguments -> do
    calleeType <- checkCallee declared rigid callee
    argumentTypes <- mapM (checkExpression declared rigid) arguments
    callType spanValue calleeType argumentTypes
  MemberExpression target member -> do
    targetType <- checkExpression declared rigid target
    memberType spanValue targetType (locatedValue member)
  IndexExpression target index -> do
    targetType <- checkExpression declared rigid target
    indexType <- checkExpression declared rigid index
    _ <- unify (locatedSpan index) integerType indexType
    elementType spanValue targetType
  TryExpression target -> do
    targetType <- checkExpression declared rigid target
    tryType spanValue targetType
  AwaitExpression target -> checkExpression declared rigid target
  TupleExpression members -> TupleTypeValue <$> mapM (checkExpression declared rigid) members
  RecordExpression path fields -> recordType declared rigid spanValue path fields
  BlockExpression block -> checkBlock declared rigid block
  IfExpression condition thenBlock elseBranch -> do
    conditionType <- checkExpression declared rigid condition
    _ <- unify (locatedSpan condition) boolType conditionType
    thenType <- checkBlock declared rigid thenBlock
    case elseBranch of
      Nothing -> pure UnitTypeValue
      Just branch -> do
        elseType <- checkExpression declared rigid branch
        unify spanValue thenType elseType
  MatchExpression scrutinee arms -> do
    subjectType <- checkExpression declared rigid scrutinee
    result <- checkArms declared rigid spanValue subjectType arms
    checkExhaustive spanValue subjectType arms
    pure result
  WhileExpression condition body -> do
    conditionType <- checkExpression declared rigid condition
    _ <- unify (locatedSpan condition) boolType conditionType
    _ <- checkBlock declared rigid body
    pure UnitTypeValue
  LoopExpression body -> do
    _ <- checkBlock declared rigid body
    pure UnitTypeValue
  ForExpression binder iterated body -> do
    _ <- checkExpression declared rigid iterated
    inTypeScope $ do
      element <- freshVariable
      bindPattern declared rigid binder element
      checkBlock declared rigid body
    pure UnitTypeValue
  InvalidExpression -> pure ErrorType

{-| A record construction is checked field by field against its declaration,
    and every declared field must be supplied. -}
recordType
  :: DeclaredTypes -> [Text] -> Span -> ModuleName -> [Located FieldInit] -> Checker Type
recordType declared rigid spanValue path fields = do
  let name = NonEmpty.last (moduleNameSegments path)
  declaredFieldTypes <- lookupField name
  case declaredFieldTypes of
    Nothing -> do
      report "E3007" spanValue (name <> " is not a record type")
        (Just "construct a record whose type declares fields")
      mapM_ (checkFieldInit declared rigid) fields
      pure ErrorType
    Just expected -> do
      mapM_ (checkField declared rigid expected) fields
      let supplied = map (locatedValue . fieldInitName . locatedValue) fields
          missing = [fieldName | (fieldName, _) <- expected, fieldName `notElem` supplied]
      case missing of
        [] -> pure ()
        _ ->
          report "E3008" spanValue
            (name <> " construction is missing " <> Text.intercalate ", " missing)
            (Just "supply every declared field")
      pure (NominalType name [])

checkField
  :: DeclaredTypes -> [Text] -> [(Text, Type)] -> Located FieldInit -> Checker ()
checkField declared rigid expected located@(Located fieldSpan field) = do
  actual <- checkFieldInit declared rigid located
  let name = locatedValue (fieldInitName field)
  case lookup name expected of
    Nothing ->
      report "E3005" fieldSpan ("no declared field " <> name)
        (Just "check the field name against the type declaration")
    Just declaredType -> do
      _ <- unify fieldSpan declaredType actual
      pure ()

checkFieldInit :: DeclaredTypes -> [Text] -> Located FieldInit -> Checker Type
checkFieldInit declared rigid (Located fieldSpan field) = case fieldInitValue field of
  Just value -> checkExpression declared rigid value
  Nothing -> nameType fieldSpan (locatedValue (fieldInitName field) NonEmpty.:| [])

checkArms :: DeclaredTypes -> [Text] -> Span -> Type -> [Located MatchArm] -> Checker Type
checkArms declared rigid spanValue subjectType arms = case arms of
  [] -> pure ErrorType
  _ -> do
    types <- mapM checkArm arms
    case types of
      [] -> pure ErrorType
      first : rest -> foldUnify first rest
 where
  checkArm (Located _ arm) = do
    result <- freshVariable
    inTypeScope $ do
      bindPattern declared rigid (armPattern arm) subjectType
      case armGuard arm of
        Nothing -> pure ()
        Just guard -> do
          guardType <- checkExpression declared rigid guard
          _ <- unify (locatedSpan guard) boolType guardType
          pure ()
      bodyType <- checkExpression declared rigid (armBody arm)
      _ <- unify (locatedSpan (armBody arm)) result bodyType
      pure ()
    pure result
  foldUnify current rest = case rest of
    [] -> pure current
    next : remaining -> do
      unified <- unify spanValue current next
      foldUnify unified remaining
