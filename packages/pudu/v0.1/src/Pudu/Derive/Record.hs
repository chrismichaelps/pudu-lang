{-| @Derive.Record — residualizes generically checked record templates. -}
module Pudu.Derive.Record
  ( instantiateRecord, instantiateRecordIn, instantiateAggregateIn ) where

import Control.Monad (foldM)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Derive.Build
  ( Gather (..), Walkers (..), answerNone, exitWith, propagateTo, unrollCallback )
import Pudu.Derive.Context
  ( Context (..), Exits (..), Propagation (..)
  , attributes, descriptor, fieldLabel, foldBinary, reflectedName, shadow, typeArguments
  , variantDescriptor, variantLabel, writtenLiteral
  )
import Pudu.Derive.Reflection (ReflectionBinding (..))
import Pudu.Derive.State
  ( ExpansionFailure, FieldObligation, Residual, generated, iteration
  , noteExit, refuse, requireFields, runResidual, withinDepth )
import Pudu.Derive.Sum
  ( SelectedVariant (..), matchesVariant, readField, variantFields )
import Pudu.Derive.Syntax
  ( instantiatePattern, isStaticValue, patternNames, retag, sameTypeShape )
import Pudu.Frontend.Syntax.Inline (inlineStatements)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import Pudu.Frontend.Syntax.Tree
  ( Attribute (..), Block (..), ComptimeFor (..), Constraint (..)
  , Declaration (..), Derive (..), DeriveShape (..), Expression (..)
  , FieldDeclaration (..), FieldInit (..), Function (..)
  , FunctionBody (..), Impl (..), Literal (..), MatchArm (..), Parameter (..)
  , Statement (..), TypeDeclarationValue (..), TypeDefinition (..)
  , TypeParam (..), TypeSyntax (..), Variant (..), VariantPayload (..) )
import Pudu.Source (Span)

{-| The caller validates the template once and proves the returned obligations
    before publishing this ordinary implementation in graph interfaces. -}
instantiateRecord
  :: Map Span ReflectionBinding -> Span -> Located Derive -> TypeDeclarationValue
  -> Located TypeSyntax -> Located TypeSyntax
  -> Either ExpansionFailure (Impl, [FieldObligation])
instantiateRecord reflected request template target trait writtenTarget =
  runResidual request (instantiateRecordIn reflected template target trait writtenTarget)

instantiateRecordIn
  :: Map Span ReflectionBinding -> Located Derive -> TypeDeclarationValue
  -> Located TypeSyntax -> Located TypeSyntax -> Residual Impl
instantiateRecordIn reflected template target trait writtenTarget =
  case (locatedValue (deriveShape (locatedValue template)), locatedValue (typeDefinition target)) of
    (RecordShape, RecordDefinition _) -> instantiateAggregateIn reflected template target trait writtenTarget
    _ -> refuse (locatedSpan template) "a record derive requires a record target"

instantiateAggregateIn
  :: Map Span ReflectionBinding -> Located Derive -> TypeDeclarationValue
  -> Located TypeSyntax -> Located TypeSyntax -> Residual Impl
instantiateAggregateIn reflected (Located at template) target trait writtenTarget = do
  (shape, fields, variants) <- case (locatedValue (deriveShape template), locatedValue (typeDefinition target)) of
    (RecordShape, RecordDefinition selected) -> pure (RecordShape, selected, [])
    (SumShape, SumDefinition selected) ->
      pure (SumShape, [], zipWith SelectedVariant [0..] selected)
    _ -> refuse at "the derive shape does not match its aggregate target"
  let context = Context reflected writtenTarget fields shape variants Map.empty Map.empty Map.empty
        (Map.singleton (locatedValue (deriveParameter template)) writtenTarget) Map.empty Nothing
  methods <- mapM (locatedFunction 0 context) (deriveFunctions template)
  parameters <- mapM (typeParameter 0 context{substitutions = Map.empty}) (typeTypeParams target)
  pure (Impl parameters trait writtenTarget [] methods)

locatedFunction :: Int -> Context -> Located Function -> Residual (Located Function)
locatedFunction depth context (Located at value) =
  function depth context value >>= generated at

function :: Int -> Context -> Function -> Residual Function
function depth context value = do
  withinDepth depth (locatedSpan (functionName value))
  let active = shadow (map (locatedValue . parameterName . locatedValue) (functionParameters value))
        context{exits = Nothing, substitutions = foldr Map.delete (substitutions context)
          (map (locatedValue . typeParamName . locatedValue) (functionTypeParams value))}
  name <- retag (functionName value)
  params <- mapM (parameter depth active) (functionParameters value)
  types <- mapM (typeParameter depth active) (functionTypeParams value)
  result <- mapM (syntax depth active) (functionReturn value)
  constraints <- mapM (constraint depth active) (functionConstraints value)
  body <- mapM (functionBody' depth active) (functionBody value)
  unsafe <- mapM (mapM retag) (functionUnsafe value)
  pure value{functionName = name, functionParameters = params, functionTypeParams = types,
    functionReturn = result, functionConstraints = constraints, functionBody = body, functionUnsafe = unsafe}

parameter :: Int -> Context -> Located Parameter -> Residual (Located Parameter)
parameter depth context (Located at value) = do
  name <- retag (parameterName value)
  written <- mapM (syntax depth context) (parameterType value)
  fallback <- mapM (expression (depth + 1) context) (parameterDefault value)
  generated at value{parameterName = name, parameterType = written, parameterDefault = fallback}

typeParameter :: Int -> Context -> Located TypeParam -> Residual (Located TypeParam)
typeParameter depth context (Located at value) = do
  name <- retag (typeParamName value)
  bounds <- mapM (syntax depth context) (typeParamBounds value)
  generated at value{typeParamName = name, typeParamBounds = bounds}

constraint :: Int -> Context -> Located Constraint -> Residual (Located Constraint)
constraint depth context (Located at value) = do
  subject <- retag (constraintSubject value)
  bounds <- mapM (syntax depth context) (constraintBounds value)
  generated at value{constraintSubject = subject, constraintBounds = bounds}

syntax :: Int -> Context -> Located TypeSyntax -> Residual (Located TypeSyntax)
syntax depth context (Located at written) = do
  withinDepth depth at
  case written of
    NamedType (ModuleName (name :| [])) []
      | Just replacement <- Map.lookup name (substitutions context) ->
          syntax (depth + 1) context{substitutions = Map.empty}
            (Located at (locatedValue replacement))
    NamedType path arguments -> mapM recurse arguments >>= generated at . NamedType path
    DynamicType path -> generated at (DynamicType path)
    ReferenceType mutable target -> recurse target >>= generated at . ReferenceType mutable
    TupleType members -> mapM recurse members >>= generated at . TupleType
    FunctionType async inputs output -> FunctionType async <$> mapM recurse inputs <*> recurse output >>= generated at
    UnsafeType capabilities target -> do
      caps <- mapM retag capabilities
      recurse target >>= generated at . UnsafeType caps
    UnitType -> generated at UnitType
    InvalidType -> refuse at "an invalid type cannot be instantiated"
 where
  recurse = syntax (depth + 1) context

functionBody' :: Int -> Context -> Located FunctionBody -> Residual (Located FunctionBody)
functionBody' depth context (Located at body) = case body of
  BlockBody held -> block (depth + 1) context held >>= generated at . BlockBody
  ExpressionBody held -> expression (depth + 1) context held >>= generated at . ExpressionBody

block :: Int -> Context -> Located Block -> Residual (Located Block)
block depth context (Located at value) = do
  withinDepth depth at
  (reversed, final) <- foldM step ([], context) (blockStatements value)
  result <- mapM (expression (depth + 1) final) (blockResult value)
  generated at (Block (inlineStatements (reverse reversed)) result)
 where
  step (previous, active) held = do
    (next, after) <- statement (depth + 1) active held
    pure (next : previous, after)

statement :: Int -> Context -> Located Statement -> Residual (Located Statement, Context)
statement depth context (Located at value) = do
  withinDepth depth at
  (next, after) <- case value of
    DeclarationStatement (Located declarationAt (BindingDeclaration visibility kind name written initial)) -> do
      initialized <- expression (depth + 1) context initial
      annotated <- mapM (syntax depth context) written
      renamed <- retag name
      declaration <- generated declarationAt (BindingDeclaration visibility kind renamed annotated initialized)
      pure (DeclarationStatement declaration, shadow [locatedValue name] context)
    DeclarationStatement (Located declarationAt (FunctionDeclaration held)) -> do
      held' <- function (depth + 1) context held
      declaration <- generated declarationAt (FunctionDeclaration held')
      pure (DeclarationStatement declaration, shadow [locatedValue (functionName held)] context)
    DeclarationStatement _ -> refuse at "this local declaration cannot occur in a derive"
    ExpressionStatement held -> ordinary . ExpressionStatement <$> expression (depth + 1) context held
    ReturnStatement held -> do
      held' <- mapM (expression (depth + 1) context) held
      case (exits context, held') of
        (Just exit, Just answer) -> do
          noteExit
          leave <- exitWith at (valueExit exit) answer
          pure (locatedValue leave, context)
        _ -> pure (ordinary (ReturnStatement held'))
    BreakStatement label held -> do
      label' <- mapM retag label
      ordinary . BreakStatement label' <$> mapM (expression (depth + 1) context) held
    ContinueStatement label -> ordinary . ContinueStatement <$> mapM retag label
    LetElseStatement pat held fallback -> do
      held' <- expression (depth + 1) context held
      fallback' <- block (depth + 1) context fallback
      pat' <- instantiatePattern depth pat
      pure (LetElseStatement pat' held' fallback', shadow (patternNames pat) context)
    LetPatternStatement kind pat written held -> do
      held' <- expression (depth + 1) context held
      written' <- mapM (syntax depth context) written
      pat' <- instantiatePattern depth pat
      pure (LetPatternStatement kind pat' written' held', shadow (patternNames pat) context)
    InvalidStatement -> refuse at "an invalid statement cannot be instantiated"
  located <- generated at next
  pure (located, after)
 where
  ordinary held = (held, context)

expression :: Int -> Context -> Located Expression -> Residual (Located Expression)
expression depth context original@(Located at value) = do
  withinDepth depth at
  case value of
    LiteralExpression held -> out (LiteralExpression held)
    NameExpression (name :| []) | Just held <- Map.lookup name (knownValues context) ->
      expression (depth + 1) context{knownValues = Map.empty} held
    NameExpression (name :| []) | Map.member name (descriptors context) || Map.member name (variantDescriptors context) ->
      refuse at "a field descriptor cannot escape into generated runtime code"
    NameExpression _ | Map.member at (reflectedCalls context) ->
      refuse at "metadata cannot escape into generated runtime code"
    NameExpression path -> out (NameExpression path)
    UnaryExpression operator held -> do
      held' <- recurse held
      out $ case (operator, locatedValue held') of
        ("!", LiteralExpression (BoolValue known)) -> LiteralExpression (BoolValue (not known))
        _ -> UnaryExpression operator held'
    BinaryExpression left operator right -> do
      left' <- recurse left
      case (locatedValue left', operator) of
        (LiteralExpression (BoolValue False), "&&") -> literal (BoolValue False)
        (LiteralExpression (BoolValue True), "||") -> literal (BoolValue True)
        _ -> do
          right' <- recurse right
          out (foldBinary left' operator right')
    CallExpression callee arguments -> case reflectedName context callee of
      Just "nameOf" -> case (typeArguments callee, arguments) of
        ([written], []) -> do
          resolved <- syntax depth context written
          case locatedValue resolved of
            NamedType path _ -> literal (StringValue (NonEmpty.last (moduleNameSegments path)))
            _ -> refuse at "nameOf requires a declared nominal type"
        _ -> refuse at "nameOf requires one type and no value arguments"
      Just gathering | gathering `elem` ["build", "collect"] -> case arguments of
        [callback] -> do
          matchingTarget depth context at callee RecordShape
          unrollCallback walkers (gatherOf gathering) depth context at callback Nothing (targetFields context)
        _ -> refuse at "a field callback call takes one callback"
      Just _ -> refuse at "this metadata call must be consumed by a compile-time construct"
      Nothing -> case locatedValue callee of
        MemberExpression receiver member | Just field <- descriptor context receiver ->
          fieldCall field (locatedValue member) arguments
        MemberExpression receiver member | Just selected <- variantDescriptor context receiver ->
          variantCall selected (locatedValue member) arguments
        _ -> CallExpression <$> recurse callee <*> mapM recurse arguments >>= out
    MemberExpression receiver member | Just field <- descriptor context receiver ->
      case locatedValue member of
        "name" -> literal (StringValue (locatedValue (fieldName (locatedValue field))))
        _ -> refuse at "a metadata accessor cannot escape as a runtime method value"
    MemberExpression receiver member | Just selected <- variantDescriptor context receiver ->
      case locatedValue member of
        "name" -> literal (StringValue (locatedValue (variantName (locatedValue (selectedSyntax selected)))))
        "index" -> literal (IntegerValue (Text.pack (show (selectedIndex selected))))
        "positional" -> literal (BoolValue (case variantPayload (locatedValue (selectedSyntax selected)) of
          RecordPayload _ -> False
          _ -> True))
        _ -> refuse at "a variant accessor cannot escape into generated runtime code"
    MemberExpression (Located _ (NameExpression (name :| []))) member
      | Just written <- Map.lookup name (substitutions context) -> do
          resolved <- syntax depth context{substitutions = Map.empty} written
          case locatedValue resolved of
            NamedType path arguments -> do
              owner <- generated at (NameExpression (moduleNameSegments path))
              target <- if null arguments then pure owner else generated at (TypeApplication owner arguments)
              selected <- retag member
              out (MemberExpression target selected)
            _ -> refuse at "a static trait call needs a nominal type"
    MemberExpression receiver member -> MemberExpression <$> recurse receiver <*> retag member >>= out
    IndexExpression target index -> IndexExpression <$> recurse target <*> recurse index >>= out
    RangeExpression from inclusive to -> RangeExpression <$> mapM recurse from <*> pure inclusive <*> mapM recurse to >>= out
    TryExpression held -> do
      held' <- recurse held
      case propagation <$> exits context of
        Just (FailBuild label) -> propagateTo at label held'
        Just AnswerNone | Just exit <- exits context -> noteExit >> answerNone at (valueExit exit) held'
        _ -> out (TryExpression held')
    AwaitExpression held -> recurse held >>= out . AwaitExpression
    TupleExpression members -> mapM recurse members >>= out . TupleExpression
    ArrayExpression members -> mapM recurse members >>= out . ArrayExpression
    SetExpression members -> mapM recurse members >>= out . SetExpression
    UnsafeExpression capabilities held -> UnsafeExpression <$> mapM retag capabilities <*> recurseBlock held >>= out
    ScopeExpression held -> recurseBlock held >>= out . ScopeExpression
    LambdaExpression held -> function (depth + 1) context held >>= out . LambdaExpression
    TypeApplication held arguments -> case reflectedName context original of
      Just _ -> refuse at "a metadata function cannot escape into generated runtime code"
      Nothing -> TypeApplication <$> recurse held <*> mapM (syntax depth context) arguments >>= out
    RecordExpression path fields -> RecordExpression path <$> mapM fieldInit fields >>= out
    RecordUpdateExpression path held fields -> RecordUpdateExpression path <$> recurse held <*> mapM fieldInit fields >>= out
    BlockExpression held -> recurseBlock held >>= out . BlockExpression
    IfExpression condition success failure -> do
      condition' <- recurse condition
      case locatedValue condition' of
        LiteralExpression (BoolValue True) -> recurseBlock success >>= out . BlockExpression
        LiteralExpression (BoolValue False) -> case failure of
          Just held -> recurse held
          Nothing -> generated at (Block [] Nothing) >>= out . BlockExpression
        _ -> IfExpression condition' <$> recurseBlock success <*> mapM recurse failure >>= out
    IfLetExpression pat subject success failure -> do
      subject' <- recurse subject
      success' <- block (depth + 1) (shadow (patternNames pat) context) success
      pat' <- instantiatePattern depth pat
      IfLetExpression pat' subject' success' <$> mapM recurse failure >>= out
    MatchExpression subject arms -> MatchExpression <$> recurse subject <*> mapM arm arms >>= out
    WhileExpression label condition body -> WhileExpression <$> mapM retag label <*> recurse condition <*> recurseBlock body >>= out
    WhileLetExpression label pat subject body -> do
      label' <- mapM retag label
      pat' <- instantiatePattern depth pat
      subject' <- recurse subject
      body' <- block (depth + 1) (shadow (patternNames pat) context) body
      out (WhileLetExpression label' pat' subject' body')
    LoopExpression label body -> LoopExpression <$> mapM retag label <*> recurseBlock body >>= out
    ForExpression label pat subject body -> do
      label' <- mapM retag label
      pat' <- instantiatePattern depth pat
      subject' <- recurse subject
      body' <- block (depth + 1) (shadow (patternNames pat) context) body
      out (ForExpression label' pat' subject' body')
    ComptimeForExpression loop -> unroll depth context at loop
    MacroCall {} -> refuse at "macro expansion must precede derive instantiation"
    InvalidExpression -> refuse at "an invalid expression cannot be instantiated"
 where
  recurse = expression (depth + 1) context
  recurseBlock = block (depth + 1) context
  out = generated at
  literal = out . LiteralExpression
  fieldInit (Located fieldAt field) = do
    name <- retag (fieldInitName field)
    held <- mapM recurse (fieldInitValue field)
    generated fieldAt (FieldInit name held)
  arm (Located armAt held) = do
    let active = shadow (patternNames (armPattern held)) context
    pat <- instantiatePattern depth (armPattern held)
    guard' <- mapM (expression (depth + 1) active) (armGuard held)
    body <- expression (depth + 1) active (armBody held)
    generated armAt (MatchArm pat guard' body)
  fieldCall field member arguments = case (member, arguments) of
    ("get", [target]) -> do
      held <- recurse target
      case Map.lookup (locatedSpan field) (fieldVariants context) of
        Just selected -> readField at (targetSyntax context) selected field held
        Nothing -> do
          name <- generated at (locatedValue (fieldName (locatedValue field)))
          out (MemberExpression held name)
    ("set", [target, replacement]) -> do
      if Map.member (locatedSpan field) (fieldVariants context)
        then refuse at "sum payload writes require the aggregate builder" else pure ()
      held <- recurse target
      replaced <- recurse replacement
      name <- generated at (locatedValue (fieldName (locatedValue field)))
      projection <- out (MemberExpression held name)
      out (BinaryExpression projection "=" replaced)
    _ -> attributeCall (fieldAttributes (locatedValue field)) member arguments
  variantCall selected member arguments = case (member, arguments) of
    ("matches", [target]) -> recurse target >>= matchesVariant at (targetSyntax context) selected
    (gathering, [callback]) | gathering `elem` ["build", "collect"] ->
      unrollCallback walkers (gatherOf gathering) depth context at callback (Just selected) (variantFields selected)
    _ -> attributeCall (variantAttributes (locatedValue (selectedSyntax selected))) member arguments
  attributeCall values member arguments = case (member, arguments) of
    ("has", [name]) -> do
      key <- stringArgument name
      literal (BoolValue (not (null (attributes values key))))
    ("attributeOr", [name, fallback]) -> do
      key <- stringArgument name
      case attributes values key of
        [] -> recurse fallback
        [Located _ attribute] -> case attributeArguments attribute of
          [Located _ held] -> do
            fallback' <- recurse fallback
            result <- literal $ case locatedValue fallback' of
              LiteralExpression (StringValue _) -> writtenLiteral held
              _ -> held
            case locatedValue fallback' of
              LiteralExpression _ -> pure result
              _ -> do
                evaluated <- generated at (ExpressionStatement fallback')
                preserved <- generated at (Block [evaluated] (Just result))
                out (BlockExpression preserved)
          _ -> refuse at "attributeOr requires exactly one attribute literal"
        _ -> refuse at "attributeOr requires an unambiguous attribute"
    _ -> refuse at "invalid compile-time field accessor"
  stringArgument held = do
    result <- recurse held
    case locatedValue result of
      LiteralExpression (StringValue key) -> pure key
      _ -> refuse (locatedSpan held) "a reflected attribute name must be known at compile time"

unroll :: Int -> Context -> Span -> ComptimeFor -> Residual (Located Expression)
unroll depth context at loop = case locatedValue (comptimeForSource loop) of
  CallExpression callee [] | reflectedName context callee == Just "fields" -> do
    matchingTarget depth context at callee RecordShape
    emit =<< mapM (one Nothing) (targetFields context)
  CallExpression callee [] | reflectedName context callee == Just "variants" -> do
    matchingTarget depth context at callee SumShape
    emit =<< mapM oneVariant (targetVariants context)
  CallExpression (Located _ (MemberExpression receiver member)) []
    | locatedValue member == "fields", Just selected <- variantDescriptor context receiver ->
      emit =<< mapM (one (Just selected)) (variantFields selected)
  _ -> do
    source <- expression (depth + 1) context (comptimeForSource loop)
    case locatedValue source of
      ArrayExpression members | all isStaticValue members -> emit =<< mapM oneValue members
      _ -> refuse at "the compile-time sequence must be known at instantiation"
 where
  emit chunks = generated at (Block chunks Nothing) >>= generated at . BlockExpression
  oneVariant selected = do
    iteration at
    let element = locatedValue (comptimeForElement loop)
        active = (shadow [element] context)
          {variantDescriptors = Map.insert element selected (variantDescriptors context)}
    mapM_ (requireConstraint depth (locatedSpan (selectedSyntax selected), variantLabel context selected) active)
      (comptimeForConstraints loop)
    held <- block (depth + 1) active (comptimeForBody loop)
    value <- generated at (BlockExpression held)
    generated at (ExpressionStatement value)
  oneValue value = do
    iteration at
    let element = locatedValue (comptimeForElement loop)
        active = (shadow [element] context){knownValues = Map.insert element value (knownValues context)}
    mapM_ (requireConstraint depth (locatedSpan value, "a compile-time element") active) (comptimeForConstraints loop)
    held <- block (depth + 1) active (comptimeForBody loop)
    result <- generated at (BlockExpression held)
    generated at (ExpressionStatement result)
  one origin field = do
    iteration at
    let element = locatedValue (comptimeForElement loop)
        selected = locatedValue field
        freshTypes = case locatedValue (comptimeForType loop) of
          NamedType _ [_, Located _ (NamedType (ModuleName (fieldTypeName :| [])) [])] ->
            Map.insert fieldTypeName (fieldType selected) (substitutions context)
          _ -> substitutions context
        active = (shadow [element] context){substitutions = freshTypes,
          descriptors = Map.insert element field (descriptors context),
          fieldVariants = maybe (fieldVariants context)
            (\variant -> Map.insert (locatedSpan field) variant (fieldVariants context)) origin}
    mapM_ (requireConstraint depth (locatedSpan field, fieldLabel context origin field) active)
      (comptimeForConstraints loop)
    held <- block (depth + 1) active (comptimeForBody loop)
    value <- generated at (BlockExpression held)
    generated at (ExpressionStatement value)

requireConstraint :: Int -> (Span, Text) -> Context -> Located Constraint -> Residual ()
requireConstraint depth (fieldAt, label) active (Located constraintAt required) =
  case Map.lookup (locatedValue (constraintSubject required)) (substitutions active) of
    Nothing -> refuse constraintAt "a compile-time constraint has no selected concrete type"
    Just written -> do
      bounds <- mapM (syntax depth active) (constraintBounds required)
      if null bounds then pure () else requireFields fieldAt label written bounds

matchingTarget :: Int -> Context -> Span -> Located Expression -> DeriveShape -> Residual ()
matchingTarget depth context at callee shape = case typeArguments callee of
  [written] -> do
    resolved <- syntax depth context written
    target <- syntax depth context{substitutions = Map.empty} (targetSyntax context)
    if targetShape context == shape && sameTypeShape (locatedValue resolved) (locatedValue target)
      then pure () else refuse at "metadata requires the matching aggregate target"
  _ -> refuse at "metadata requires one target type"

walkers :: Walkers Context
walkers = Walkers block expression syntax requireConstraint

gatherOf :: Text -> Gather
gatherOf name = if name == "collect" then Collect else Construct

