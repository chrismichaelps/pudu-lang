{-| @Type.Check.Module — checks declarations, statements, and expressions -}
module Pudu.Type.Check
  ( checkModule
  , checkModuleWith
  ) where

import Control.Monad (foldM, when)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments, moduleNameText)
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
  , recordExpression
  , report
  , withRigidBounds
  , runChecker
  , withDeclared
  )
import Pudu.Type.Check.Pattern (bindPattern)
import Pudu.Type.Check.Coherence (checkCoherence)
import Pudu.Type.Check.Rule
  ( binaryType
  , enclosingReturnType
  , instantiate
  , callType
  , elementType
  , literalType
  , memberType
  , nameType
  , qualifiedMemberType
  , tryType
  , unaryType
  )
import Pudu.Type.Check.Method
  ( declareBounds
  , declareMethods
  , declareBuiltinConstructors
  , declareTraitMembers
  , dischargeObligations
  , functionRigid
  , implAliases
  , methodScheme
  , traitTable
  )
import Pudu.Type.Exhaust (checkExhaustive)
import Pudu.Type.Formation
  ( collectDeclaredFrom
  , declaredParameterType
  , formOptionalType
  , formType
  )
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value
  ( NominalId (..)
  , monotype
  , polytype
  , Type (..)
  , boolType
  , integerType
  )
import Pudu.Type.Interface (ImportTypes)
import Pudu.Type.Check.Import (collectImportedDeclared, declareImportedTypes)

{-| Check one module. Signatures are collected before any body is checked, so a
    function may call one declared later without a forward declaration. -}
checkModule :: Module -> ([((Int, Int), Type)], [Diagnostic])
checkModule = checkModuleWith mempty

checkModuleWith :: ImportTypes -> Module -> ([((Int, Int), Type)], [Diagnostic])
checkModuleWith imported moduleValue =
  let products = runChecker (checkUnit imported moduleValue)
   in (producedTypes products, producedDiagnostics products)

checkUnit :: ImportTypes -> Module -> Checker ()
checkUnit imported moduleValue = do
  dependencyDeclared <- collectImportedDeclared imported
  declared <- collectDeclaredFrom dependencyDeclared
    (locatedValue (moduleName moduleValue))
    (moduleDeclarations moduleValue)
  withDeclared declared
  declareBuiltinConstructors
  declareImportedTypes declared imported
  let traits = traitTable declared (moduleDeclarations moduleValue)
  mapM_ (declareSignature declared traits) (moduleDeclarations moduleValue)
  checkCoherence (moduleDeclarations moduleValue)
  mapM_ (checkDeclaration declared) (moduleDeclarations moduleValue)
  dischargeObligations

{-| Give every module-scope declaration a type before bodies are checked. -}
declareSignature
  :: DeclaredTypes -> Map.Map NominalId [Located Function] -> Located Declaration -> Checker ()
declareSignature declared traits (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name annotation _ -> do
    formed <- formOptionalType declared [] annotation
    bindName (locatedValue name) (monotype formed)
  FunctionDeclaration value -> declareFunction declared value
  TypeDeclaration value -> declareConstructors declared value
  ImplDeclaration value -> declareMethods declared traits value
  TraitDeclaration value -> declareTraitMembers declared value
  _ -> pure ()
declareFunction :: DeclaredTypes -> Function -> Checker ()
declareFunction declared value = do
  let rigid = functionRigid value
  inputs <- mapM (declaredParameterType declared rigid) (functionParameters value)
  result <- formOptionalType declared rigid (functionReturn value)
  bindName (locatedValue (functionName value))
    ( polytype rigid (declareBounds declared value)
        (FunctionTypeValue (functionAsync value) inputs result)
    )

{-| A sum's variants become constructors: a payload-carrying variant is a
    function to its own type, a unit variant is a value of it. -}
declareConstructors :: DeclaredTypes -> Tree.TypeDeclarationValue -> Checker ()
declareConstructors declared value = case locatedValue (Tree.typeDefinition value) of
  Tree.SumDefinition variants -> mapM_ declareVariant variants
  _ -> pure ()
 where
  ownerName = locatedValue (Tree.typeName value)
  owner = Map.findWithDefault (NominalId Nothing ownerName) ownerName (declaredNames declared)
  rigid = map (locatedValue . typeParamName . locatedValue) (Tree.typeTypeParams value)
  ownerType = NominalType owner (map RigidType rigid)
  declareVariant (Located _ variant) = do
    payload <- variantPayload declared rigid variant
    let name = locatedValue (Tree.variantName variant)
        scheme
          | null payload = polytype rigid [] ownerType
          | otherwise = polytype rigid [] (FunctionTypeValue False payload ownerType)
    bindName name scheme

variantPayload :: DeclaredTypes -> [Text] -> Tree.Variant -> Checker [Type]
variantPayload declared rigid variant = case Tree.variantPayload variant of
  Tree.UnitPayload -> pure []
  Tree.TuplePayload members -> mapM (formType declared rigid) members
  Tree.RecordPayload fields ->
    mapM (\(Located _ field) -> formType declared rigid (Tree.fieldType field)) fields

checkDeclaration :: DeclaredTypes -> Located Declaration -> Checker ()
checkDeclaration declared (Located _ declaration) = case declaration of
  BindingDeclaration visibility _ name annotation value -> do
    when (visibility == Exported && annotation == Nothing) $
      report "E3010" (locatedSpan name)
        ("exported binding " <> locatedValue name <> " needs a type annotation")
        (Just "annotate the exported binding so importers can check it without its body")
    expected <- formOptionalType declared [] annotation
    actual <- checkExpression declared [] value
    _ <- unify (locatedSpan value) expected actual
    bindName (locatedValue name) (monotype expected)
  FunctionDeclaration value -> checkFunction declared Nothing value
  TraitDeclaration value ->
    let name = locatedValue (traitName value)
        identity = Map.findWithDefault (NominalId Nothing name) name (declaredNames declared)
     in do
       when (traitVisibility value == Exported) $
         mapM_ (requireInterfaceAnnotations "exported trait member" . locatedValue) (traitMembers value)
       mapM_ (checkMember (traitAliases declared) (Just identity)) (traitMembers value)
  ImplDeclaration value ->
    do
      mapM_ (requireInterfaceAnnotations "implementation method" . locatedValue) (implFunctions value)
      mapM_ (checkMember (implAliases declared value) Nothing) (implFunctions value)
  _ -> pure ()

{-| Check a trait member with a rigid `Self` bound, or an implementation member
    with `Self` aliased to its canonical target. -}
checkMember :: DeclaredTypes -> Maybe NominalId -> Located Function -> Checker ()
checkMember declared selfBound (Located _ value) = checkFunction declared selfBound value

{-| `Self` inside a trait is the implementing type, which is unknown while the
    trait itself is checked, so it stays a rigid parameter there. -}
traitAliases :: DeclaredTypes -> DeclaredTypes
traitAliases = id

{-| Check a function body against its declared result. Exported signatures are
    annotated interfaces; a trait member receives its canonical trait as the
    rigid `Self` bound used by default-body method calls. -}
checkFunction :: DeclaredTypes -> Maybe NominalId -> Function -> Checker ()
checkFunction declared selfBound value = do
  let rigid = functionRigid value <> foldMap selfRigid selfBound
      bounds = declareBounds declared value <> foldMap selfBoundAsBound selfBound
  requireExportedAnnotations value
  withRigidBounds bounds $ inTypeScope $ do
    inputs <- mapM (bindParameter declared rigid) (functionParameters value)
    result <- formOptionalType declared rigid (functionReturn value)
    bindName selfName (monotype (FunctionTypeValue (functionAsync value) inputs result))
    case functionBody value of
      Nothing -> pure ()
      Just (Located bodySpan body) -> do
        actual <- case body of
          BlockBody block -> checkBlock declared rigid block
          ExpressionBody expression -> checkExpression declared rigid expression
        _ <- unify bodySpan result actual
        pure ()
    dischargeObligations

{-| The bound a trait member adds: `Self` satisfies the trait it belongs to,
    which lets a default body call other trait methods on `self`. -}
selfBoundAsBound :: NominalId -> [(Text, [NominalId])]
selfBoundAsBound traitName = [("Self", [traitName])]

{-| `Self` is rigid inside a trait member so that `formType` produces
    `RigidType "Self"` rather than `NominalType "Self"`, routing method
    calls through `rigidMethod` and the trait bound installed by
    `selfBoundAsBound`. -}
selfRigid :: NominalId -> [Text]
selfRigid _ = ["Self"]

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

requireInterfaceAnnotations :: Text -> Function -> Checker ()
requireInterfaceAnnotations kind value = do
  mapM_ requireParameter (functionParameters value)
  case functionReturn value of
    Just _ -> pure ()
    Nothing ->
      report "E3010" (locatedSpan (functionName value))
        (kind <> " " <> locatedValue (functionName value) <> " needs a return type")
        (Just "annotate the complete signature because importers read it without its body")
 where
  requireParameter (Located parameterSpan parameter) = case Tree.parameterType parameter of
    Just _ -> pure ()
    Nothing ->
      report "E3010" parameterSpan
        (kind <> " parameter " <> locatedValue (Tree.parameterName parameter) <> " needs a type")
        (Just "annotate every interface-carried parameter")

bindParameter :: DeclaredTypes -> [Text] -> Located Parameter -> Checker Type
bindParameter declared rigid (Located _ parameter) = do
  formed <- formOptionalType declared rigid (Tree.parameterType parameter)
  case Tree.parameterDefault parameter of
    Nothing -> pure ()
    Just expression -> do
      actual <- checkExpression declared rigid expression
      _ <- unify (locatedSpan expression) formed actual
      pure ()
  bindName (locatedValue (Tree.parameterName parameter)) (monotype formed)
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
    bindName (locatedValue name) (monotype unified)
  DeclarationStatement other -> checkDeclaration declared other
  ExpressionStatement expression -> do
    _ <- checkExpression declared rigid expression
    pure ()
  ReturnStatement value -> do
    actual <- case value of
      Nothing -> pure UnitTypeValue
      Just expression -> checkExpression declared rigid expression
    expected <- enclosingReturnType selfName
    case value of
      Nothing -> pure ()
      Just expression -> do
        _ <- unify (locatedSpan expression) expected actual
        pure ()
  BreakStatement -> pure ()
  ContinueStatement -> pure ()
  InvalidStatement -> pure ()

{-| A member in callee position prefers a method over a field of the same
    name, because `value.name()` reads as a call and a field would have to be
    parenthesized to be called anyway. -}
checkCallee :: DeclaredTypes -> [Text] -> Located Expression -> Checker Type
checkCallee declared rigid located@(Located calleeSpan expression) = case expression of
  MemberExpression target member -> do
    qualified <- qualifiedMemberType calleeSpan (locatedValue target) (locatedValue member)
    case qualified of
      Just instantiated -> do
        recordExpression calleeSpan instantiated
        pure instantiated
      Nothing -> do
        targetType <- checkExpression declared rigid target
        resolved <- zonk targetType
        method <- methodScheme calleeSpan resolved (locatedValue member)
        case method of
          Nothing -> checkExpression declared rigid located
          Just scheme -> do
            instantiated <- instantiate calleeSpan scheme
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
    qualified <- qualifiedMemberType spanValue (locatedValue target) (locatedValue member)
    case qualified of
      Just value -> pure value
      Nothing -> do
        targetType <- checkExpression declared rigid target
        memberType spanValue targetType (locatedValue member)
  IndexExpression target index -> do
    targetType <- checkExpression declared rigid target
    indexType <- checkExpression declared rigid index
    _ <- unify (locatedSpan index) integerType indexType
    elementType spanValue targetType
  TryExpression target -> do
    targetType <- checkExpression declared rigid target
    declaredResult <- enclosingReturnType selfName
    tryType spanValue targetType declaredResult
  AwaitExpression target -> checkExpression declared rigid target
  TupleExpression members -> TupleTypeValue <$> mapM (checkExpression declared rigid) members
  ArrayExpression members -> do
    elementTypes <- mapM (checkExpression declared rigid) members
    inferredElementType <- case elementTypes of
      [] -> freshVariable
      first : rest -> foldM (unify spanValue) first rest
    pure (NominalType "Array" [inferredElementType])
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
      identity = Map.findWithDefault (NominalId Nothing (moduleNameText path))
        (moduleNameText path) (declaredNames declared)
  declaredFieldTypes <- lookupField identity
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
      pure (NominalType identity [])

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
