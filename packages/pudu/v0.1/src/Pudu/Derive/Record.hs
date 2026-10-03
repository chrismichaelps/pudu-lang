{-| @Derive.Record — residualizes generically checked record templates. -}
module Pudu.Derive.Record (instantiateRecord) where

import Control.Monad (foldM)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Pudu.Derive.Reflection (ReflectionBinding (..))
import Pudu.Derive.State
  ( ExpansionFailure, FieldObligation, Residual, generated, iteration, refuse
  , requireFields, runResidual, withinDepth )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (ModuleName (..), moduleNameSegments)
import Pudu.Frontend.Syntax.Tree
  ( ArrayRest (..), Attribute (..), Block (..), Capability, ComptimeFor (..), Constraint (..)
  , Declaration (..), Derive (..), DeriveShape (..), Expression (..)
  , FieldDeclaration (..), FieldInit (..), FieldPattern (..), Function (..)
  , FunctionBody (..), Impl (..), Literal (..), MatchArm (..), Parameter (..)
  , Pattern (..), Statement (..), TypeDeclarationValue (..), TypeDefinition (..)
  , TypeParam (..), TypeSyntax (..) )
import Pudu.Source (Span)

data Context = Context
  { reflectedCalls :: !(Map Span ReflectionBinding)
  , targetSyntax :: !(Located TypeSyntax)
  , targetFields :: ![Located FieldDeclaration]
  , substitutions :: !(Map Text (Located TypeSyntax))
  , descriptors :: !(Map Text (Located FieldDeclaration))
  }

{-| The caller validates the template once and proves the returned obligations
    before publishing this ordinary implementation in graph interfaces. -}
instantiateRecord
  :: Map Span ReflectionBinding -> Span -> Located Derive -> TypeDeclarationValue
  -> Located TypeSyntax -> Located TypeSyntax
  -> Either ExpansionFailure (Impl, [FieldObligation])
instantiateRecord reflected request (Located at template) target trait writtenTarget =
  runResidual request $ case (locatedValue (deriveShape template), locatedValue (typeDefinition target)) of
    (RecordShape, RecordDefinition fields) -> do
      let context = Context reflected writtenTarget fields
            (Map.singleton (locatedValue (deriveParameter template)) writtenTarget) Map.empty
      methods <- mapM (locatedFunction 0 context) (deriveFunctions template)
      parameters <- mapM (typeParameter 0 context) (typeTypeParams target)
      pure (Impl parameters trait writtenTarget [] methods)
    _ -> refuse at "a record derive requires a record target"

locatedFunction :: Int -> Context -> Located Function -> Residual (Located Function)
locatedFunction depth context (Located at value) =
  function depth context value >>= generated at

function :: Int -> Context -> Function -> Residual Function
function depth context value = do
  withinDepth depth (locatedSpan (functionName value))
  let active = shadow (map (locatedValue . parameterName . locatedValue) (functionParameters value))
        context{substitutions = foldr Map.delete (substitutions context)
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
          syntax (depth + 1) context{substitutions = Map.delete name (substitutions context)}
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
  generated at (Block (reverse reversed) result)
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
    ReturnStatement held -> ordinary . ReturnStatement <$> mapM (expression (depth + 1) context) held
    BreakStatement label held -> do
      label' <- mapM retag label
      ordinary . BreakStatement label' <$> mapM (expression (depth + 1) context) held
    ContinueStatement label -> ordinary . ContinueStatement <$> mapM retag label
    LetElseStatement pat held fallback -> do
      held' <- expression (depth + 1) context held
      fallback' <- block (depth + 1) context fallback
      pat' <- pattern' depth pat
      pure (LetElseStatement pat' held' fallback', shadow (patternNames pat) context)
    LetPatternStatement kind pat written held -> do
      held' <- expression (depth + 1) context held
      written' <- mapM (syntax depth context) written
      pat' <- pattern' depth pat
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
    NameExpression (name :| []) | Map.member name (descriptors context) ->
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
      Just _ -> refuse at "this metadata call must be consumed by a compile-time construct"
      Nothing -> case locatedValue callee of
        MemberExpression receiver member | Just field <- descriptor context receiver ->
          fieldCall field (locatedValue member) arguments
        _ -> CallExpression <$> recurse callee <*> mapM recurse arguments >>= out
    MemberExpression receiver member | Just field <- descriptor context receiver ->
      case locatedValue member of
        "name" -> literal (StringValue (locatedValue (fieldName (locatedValue field))))
        _ -> refuse at "a metadata accessor cannot escape as a runtime method value"
    MemberExpression receiver member -> MemberExpression <$> recurse receiver <*> retag member >>= out
    IndexExpression target index -> IndexExpression <$> recurse target <*> recurse index >>= out
    RangeExpression from inclusive to -> RangeExpression <$> mapM recurse from <*> pure inclusive <*> mapM recurse to >>= out
    TryExpression held -> recurse held >>= out . TryExpression
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
      pat' <- pattern' depth pat
      IfLetExpression pat' subject' success' <$> mapM recurse failure >>= out
    MatchExpression subject arms -> MatchExpression <$> recurse subject <*> mapM arm arms >>= out
    WhileExpression label condition body -> WhileExpression <$> mapM retag label <*> recurse condition <*> recurseBlock body >>= out
    WhileLetExpression label pat subject body -> do
      label' <- mapM retag label
      pat' <- pattern' depth pat
      subject' <- recurse subject
      body' <- block (depth + 1) (shadow (patternNames pat) context) body
      out (WhileLetExpression label' pat' subject' body')
    LoopExpression label body -> LoopExpression <$> mapM retag label <*> recurseBlock body >>= out
    ForExpression label pat subject body -> do
      label' <- mapM retag label
      pat' <- pattern' depth pat
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
    pat <- pattern' depth (armPattern held)
    guard' <- mapM (expression (depth + 1) active) (armGuard held)
    body <- expression (depth + 1) active (armBody held)
    generated armAt (MatchArm pat guard' body)
  fieldCall field member arguments = case (member, arguments) of
    ("get", [target]) -> do
      held <- recurse target
      name <- generated at (locatedValue (fieldName (locatedValue field)))
      out (MemberExpression held name)
    ("set", [target, replacement]) -> do
      held <- recurse target
      replaced <- recurse replacement
      name <- generated at (locatedValue (fieldName (locatedValue field)))
      projection <- out (MemberExpression held name)
      out (BinaryExpression projection "=" replaced)
    ("has", [name]) -> do
      key <- stringArgument name
      literal (BoolValue (not (null (attributes field key))))
    ("attributeOr", [name, fallback]) -> do
      key <- stringArgument name
      case attributes field key of
        [] -> recurse fallback
        [Located _ attribute] -> case attributeArguments attribute of
          [Located _ held] -> do
            fallback' <- recurse fallback
            result <- literal held
            case locatedValue fallback' of
              LiteralExpression _ -> pure result
              _ -> do
                evaluated <- generated at (ExpressionStatement fallback')
                preserved <- generated at (Block [evaluated] (Just result))
                out (BlockExpression preserved)
          _ -> refuse (locatedSpan field) "attributeOr requires exactly one attribute literal"
        _ -> refuse (locatedSpan field) "attributeOr requires an unambiguous attribute"
    _ -> refuse at "invalid compile-time field accessor"
  stringArgument held = do
    result <- recurse held
    case locatedValue result of
      LiteralExpression (StringValue key) -> pure key
      _ -> refuse (locatedSpan held) "a reflected attribute name must be known at compile time"

unroll :: Int -> Context -> Span -> ComptimeFor -> Residual (Located Expression)
unroll depth context at loop = case locatedValue (comptimeForSource loop) of
  CallExpression callee [] | reflectedName context callee == Just "fields" -> do
    case typeArguments callee of
      [written] -> do
        resolved <- syntax depth context written
        target <- syntax depth context (targetSyntax context)
        if typeShape (locatedValue resolved) == typeShape (locatedValue target)
          then pure () else refuse at "this record kernel requires fields of its target"
      _ -> refuse at "fields requires the target type"
    chunks <- mapM one (targetFields context)
    held <- generated at (Block chunks Nothing)
    generated at (BlockExpression held)
  _ -> refuse at "the compile-time field sequence must be known at instantiation"
 where
  one field = do
    iteration at
    let element = locatedValue (comptimeForElement loop)
        selected = locatedValue field
        freshTypes = case locatedValue (comptimeForType loop) of
          NamedType _ [_, Located _ (NamedType (ModuleName (fieldTypeName :| [])) [])] ->
            Map.insert fieldTypeName (fieldType selected) (substitutions context)
          _ -> substitutions context
        active = context{substitutions = freshTypes,
          descriptors = Map.insert element field (descriptors context)}
    mapM_ (requireConstraint field active) (comptimeForConstraints loop)
    held <- block (depth + 1) active (comptimeForBody loop)
    value <- generated at (BlockExpression held)
    generated at (ExpressionStatement value)
  requireConstraint field active (Located constraintAt required) =
    case Map.lookup (locatedValue (constraintSubject required)) (substitutions active) of
      Nothing -> refuse constraintAt "a loop constraint has no selected concrete type"
      Just written -> do
        bounds <- mapM (syntax depth active) (constraintBounds required)
        if null bounds then pure () else requireFields (locatedSpan field) written bounds

descriptor :: Context -> Located Expression -> Maybe (Located FieldDeclaration)
descriptor context (Located _ value) = case value of
  NameExpression (name :| []) -> Map.lookup name (descriptors context)
  UnaryExpression "&" held -> descriptor context held
  _ -> Nothing

reflectedName :: Context -> Located Expression -> Maybe Text
reflectedName context held = case locatedValue held of
  TypeApplication target _ -> reflectedName context target
  MemberExpression target name
    | Map.lookup (locatedSpan target) (reflectedCalls context) == Just MetadataModule ->
        Just (locatedValue name)
  _ -> case Map.lookup (locatedSpan held) (reflectedCalls context) of
    Just (MetadataFunction name) -> Just name
    _ -> Nothing

typeArguments :: Located Expression -> [Located TypeSyntax]
typeArguments (Located _ (TypeApplication _ arguments)) = arguments
typeArguments _ = []

attributes :: Located FieldDeclaration -> Text -> [Located Attribute]
attributes field key = filter ((== key) . locatedValue . attributeName . locatedValue)
  (fieldAttributes (locatedValue field))

shadow :: [Text] -> Context -> Context
shadow names context = context{descriptors = foldr Map.delete (descriptors context) names}

retag :: Located a -> Residual (Located a)
retag (Located at value) = generated at value

foldBinary :: Located Expression -> Text -> Located Expression -> Expression
foldBinary left operator right = case (locatedValue left, operator, locatedValue right) of
  (LiteralExpression (BoolValue a), "&&", LiteralExpression (BoolValue b)) -> known (BoolValue (a && b))
  (LiteralExpression (BoolValue a), "||", LiteralExpression (BoolValue b)) -> known (BoolValue (a || b))
  (LiteralExpression (BoolValue a), "==", LiteralExpression (BoolValue b)) -> known (BoolValue (a == b))
  (LiteralExpression (BoolValue a), "!=", LiteralExpression (BoolValue b)) -> known (BoolValue (a /= b))
  (LiteralExpression (StringValue a), "==", LiteralExpression (StringValue b)) -> known (BoolValue (a == b))
  (LiteralExpression (StringValue a), "!=", LiteralExpression (StringValue b)) -> known (BoolValue (a /= b))
  (LiteralExpression (StringValue a), "+", LiteralExpression (StringValue b)) -> known (StringValue (a <> b))
  _ -> BinaryExpression left operator right
 where
  known = LiteralExpression

data TypeShape
  = NamedShape !ModuleName ![TypeShape]
  | DynamicShape !ModuleName
  | BorrowedShape !Bool !TypeShape
  | TupleShape ![TypeShape]
  | FunctionShape !Bool ![TypeShape] !TypeShape
  | UnsafeShape ![Capability] !TypeShape
  | UnitShape
  | InvalidShape
  deriving stock (Eq)

-- Compare nominal spellings and full structure, never authored locations.
typeShape :: TypeSyntax -> TypeShape
typeShape written = case written of
  NamedType path arguments -> NamedShape path (map recurse arguments)
  DynamicType path -> DynamicShape path
  ReferenceType mutable target -> BorrowedShape mutable (recurse target)
  TupleType members -> TupleShape (map recurse members)
  FunctionType async inputs result -> FunctionShape async (map recurse inputs) (recurse result)
  UnsafeType capabilities target -> UnsafeShape (map locatedValue capabilities) (recurse target)
  UnitType -> UnitShape
  InvalidType -> InvalidShape
 where
  recurse = typeShape . locatedValue

patternNames :: Located Pattern -> [Text]
patternNames (Located _ value) = case value of
  BindingPattern name -> [locatedValue name]
  TuplePattern members -> concatMap patternNames members
  ArrayPattern prefix rest suffix -> concatMap patternNames (prefix <> suffix) <> case rest of
    Just (BoundRest name) -> [locatedValue name]
    _ -> []
  ConstructorPattern _ members -> concatMap patternNames members
  RecordPattern _ fields _ -> concatMap names fields
  AlternativePattern alternatives -> concatMap patternNames alternatives
  _ -> []
 where
  names (Located _ field) = maybe [locatedValue (fieldPatternName field)] patternNames (fieldPatternValue field)

pattern' :: Int -> Located Pattern -> Residual (Located Pattern)
pattern' depth (Located at value) = do
  withinDepth depth at
  rewritten <- case value of
    BindingPattern name -> BindingPattern <$> retag name
    TuplePattern members -> TuplePattern <$> mapM recurse members
    ArrayPattern prefix rest suffix -> ArrayPattern <$> mapM recurse prefix <*> mapM arrayRest rest <*> mapM recurse suffix
    ConstructorPattern path members -> ConstructorPattern path <$> mapM recurse members
    RecordPattern path fields rest -> RecordPattern path <$> mapM fieldPattern fields <*> pure rest
    AlternativePattern alternatives -> AlternativePattern <$> mapM recurse alternatives
    other -> pure other
  generated at rewritten
 where
  recurse = pattern' (depth + 1)
  arrayRest rest = case rest of
    BoundRest name -> BoundRest <$> retag name
    IgnoredRest held -> IgnoredRest . locatedSpan <$> generated held ()
  fieldPattern (Located fieldAt field) = do
    name <- retag (fieldPatternName field)
    held <- mapM recurse (fieldPatternValue field)
    generated fieldAt (FieldPattern name held)
