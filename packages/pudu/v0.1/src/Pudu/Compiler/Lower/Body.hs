{-| @Pudu.Compiler.Lower.Body — mutually recursive block/expression traversal.
    State and signature admission remain independently owned. -}
module Pudu.Compiler.Lower.Body (lowerEntryBody, lowerFunctionBody, lowerExpression) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Set as Set
import Pudu.Compiler.Lower.Scalar (lowerUnary, lowerBinary)
import Pudu.Compiler.Lower.Types (ownerKeyOf, recordFields, selectedMember, typeForSpan, nativeIntegerKind, nativeValueType, treeType, unformed, withFacts, writtenLabel)
import Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinBranchValues
  , ConditionUse (StrictCondition), lowerCondition
  , expressionIsPrintValued )
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..)
  , bindLocal, halt, isModuleQualifier, lookupConstant, lookupLocal
  , observeMutableLayout, refuse, refused, resolveFunction )
import Pudu.Compiler.Lower.Text (lowerSelectedMember, lowerTextMethod)
import Pudu.Compiler.Lower.Method (lowerHeldMethod, lowerMethodCall, lowerOwnedMethod, lowerQualifiedMethod)
import Pudu.Compiler.Lower.Call (lowerFunctionCall, lowerPrint, lowerRendered)
import Pudu.Compiler.Lower.FunctionBody (lowerEntryBodyWith, lowerFunctionBodyWith)
import Pudu.Compiler.Lower.Array (lowerArrayLiteral, lowerArrayMethod, takeReceiver)
import Pudu.Compiler.Lower.Slice (lowerBracketIndex)
import Pudu.Compiler.Lower.Markup (keepMarkup)
import Pudu.Compiler.Lower.Convert (lowerCharFromCode, lowerConvertInteger, lowerFittingUnwrap)
import Pudu.Compiler.Lower.Keyed (lowerKeyedBuilder, lowerKeyedMethod, lowerSetLiteral)
import Pudu.Compiler.Lower.Range (lowerRangeMethod, lowerRangeValue)
import Pudu.Compiler.Lower.Bytes (lowerBytesOf)
import Control.Applicative ((<|>))
import Pudu.Compiler.Lower.Try (lowerTry, unwrapOrLeave)
import Pudu.Compiler.Lower.Scope (leaving, leavingLoop, lowerScope, released)
import Pudu.Compiler.Lower.Decimal (decimalLiteral)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, mapRuntimeChoice, normalizeAggregateValue, projectRuntimeValue, runtimeCarriers, storageCarrier)
import Pudu.Compiler.Lower.Generic (writtenCoreType, writtenTypeArguments)
import Pudu.Compiler.Lower.For (lowerFor)
import Pudu.Compiler.Lower.Intrinsic (annotatedPanic, lowerIntrinsicValue)
import Pudu.Compiler.Lower.Foreign
  (lowerQualifiedForeignCall, lowerForeignValue, lowerCallbackRegistration, lowerCallbackUnregister
  , lowerCallbackValue, lowerCallbackUnregisterValue )
import Pudu.Compiler.Lower.Primitive (lowerPrimitiveCall)
import Pudu.Compiler.Lower.MethodValue (lowerMethodValue, lowerTraitMethodValue)
import Pudu.Compiler.Lower.Stop (lowerPanic, lowerUntypedConvert)
import Pudu.Compiler.Lower.Lambda (lowerFunctionValue, lowerFunctionValueWithInputs, lowerLambda, lowerLambdaWithInputs, lowerValueCall, specializeCallable, specializeTraversalCallback)
import Pudu.Compiler.Lower.Tuple (lowerTuple, lowerTuplePattern)
import Pudu.Compiler.Lower.Place (declareLocal, lowerPlaceAssignment)
import Pudu.Compiler.Lower.Loan (loanedReturn)
import Pudu.Compiler.Lower.Record (lowerField, lowerRecord, lowerRecordUpdate)
import Pudu.Compiler.Lower.Sum (lowerConstructorValue, lowerVariant)
import Pudu.Compiler.Lower.Constant (lowerConstant)
import Pudu.Compiler.Lower.Match (hasSequencePattern, ifLetArms, lowerLetElse, lowerLetSequence, lowerMatch, whileLetLoop)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Core
import Pudu.Eval.Operator.Access (builtinMethodNamesFor)
import Pudu.Frontend.Syntax
  ( Block (..), Declaration (..), Expression (..)
  , Function, Literal (..), Located (..), Statement (..), TypeSyntax (NamedType) )
import GHC.Float (castDoubleToWord64)
import Pudu.FloatLiteral (ParsedFloat (..), parseFloatLiteral)
import Pudu.IntegerLiteral (integerKindFits)
import Pudu.Source (Span)

{-| The entry and named-function boundaries live in [[Compiler Lower
    Function Body]]; this module supplies the block and expression traversals
    they call back into. -}
lowerEntryBody :: Located Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerEntryBody = lowerEntryBodyWith lowerExpression lowerBlock

lowerFunctionBody :: Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)
lowerFunctionBody = lowerFunctionBodyWith lowerExpression lowerBlock

{-| Lower one block: a fresh scope, statements in order, then the trailing
    expression as the result. The scope is popped on exit, so C block scoping
    and Pudu scoping agree. -}
lowerBlock :: LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
lowerBlock state (Located _ block) =
  (popped, CoreBlock{coreBlockStatements = statements <> resultStatements, coreBlockResult = coreResult}, blockType (statements <> resultStatements) coreResult)
  where
    pushed = state{lowerScopes = [] : lowerScopes state}
    (afterStatements, statements, stopped) = foldStatements pushed (blockStatements block)
    (afterResult, resultStatements, coreResult, _) = case blockResult block of
      _ | stopped -> (afterStatements, [], Nothing, CoreUnitType)
      Nothing -> (afterStatements, [], Nothing, blockType statements Nothing)
      Just located -> lowerBlockResult afterStatements located
    popped = afterResult{lowerScopes = drop 1 (lowerScopes afterResult)}

{-| A block's trailing expression. An assignment there is a statement and the
    block's result is empty, as the evaluator reads it. -}
lowerBlockResult :: LowerState -> Located Expression -> (LowerState, [CoreStatement], Maybe CoreExpression, CoreType)
lowerBlockResult state located@(Located expressionSpan expression) = case expression of
  BinaryExpression target "=" right
    | Just (after, assigned) <- lowerPlaceAssignment lowerExpression state expressionSpan target right ->
        (after, maybe [] pure assigned, Nothing, CoreUnitType)
  BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
    | Just local <- lookupLocal state name -> case lowerLocalReplacement state local right of
        (after, Just (coreRight, coreType))
          | expressionIsPrintValued coreRight ->
              (refuse expressionSpan "assigning a Result[(), Str] value" after, [], Nothing, CoreUnitType)
          | coreType == coreLocalType local || coreType == CoreNeverType ->
              ( after
              , [CoreStatement{coreStatementSpan = expressionSpan, coreStatementShape = CoreAssign local (takeReceiver local coreRight)}]
              , Nothing
              , CoreUnitType
              )
          | otherwise ->
              ( refuse expressionSpan "an assignment whose value has a different type" after
              , []
              , Nothing
              , CoreUnitType
              )
        (after, Nothing) -> (after, [], Nothing, CoreUnitType)
  _ -> case lowerExpression state located of
    (after, Just (coreExpression, coreType)) -> (after, [], Just coreExpression, coreType)
    (after, Nothing) -> (unexplained state expressionSpan after, [], Nothing, CoreUnitType)

{-| Every construct that stops lowering says why. One that stops without a
    refusal would leave the block short a statement and still compile, so it
    is refused here instead. -}
unexplained :: LowerState -> Span -> LowerState -> LowerState
unexplained before at after
  | length (contextRefusals (lowerContext after)) > length (contextRefusals (lowerContext before)) = after
  | otherwise = refuse at "this construct" after

foldStatements :: LowerState -> [Located Statement] -> (LowerState, [CoreStatement], Bool)
foldStatements state = go state []
  where
    go current collected [] = (current, reverse collected, False)
    go current collected (one@(Located statementSpan statement) : rest) = case statement of
      LetPatternStatement kind pattern _ subject | hasSequencePattern pattern ->
        case lowerLetSequence lowerExpression current statementSpan kind pattern subject of
          (after, Just statements) -> binding after collected statements rest
          (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)
      LetPatternStatement kind pattern _ subject
        -> case lowerTuplePattern lowerExpression current statementSpan kind pattern subject of
            (after, Just statements) -> binding after collected statements rest
            (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)
      LetElseStatement pattern' subject fallback ->
        case lowerLetElse lowerExpression current statementSpan pattern' subject fallback of
          (after, Just statements) -> binding after collected statements rest
          (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)
      _ -> case lowerStatement current one of
        (after, Just lowered) -> go after (lowered : collected) rest
        (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)

    binding after collected statements rest
      | blockType statements Nothing == CoreNeverType = (after, reverse collected <> statements, True)
      | otherwise = go after (reverse statements <> collected) rest

lowerLocalReplacement :: LowerState -> CoreLocal -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerLocalReplacement state local value = case lowerExpression state value of
  (after, Just (core, _)) ->
    let types = contextTypes (lowerContext after)
        expected = coreLocalType local
        (ready, projected) = projectRuntimeValue types after expected core
        actual = coreExpressionType projected
        recorded
          | expected /= actual, nativeValueType actual =
              observeMutableLayout ready local (storageCarrier types expected [actual])
          | otherwise = ready
     in (recorded, Just (projected, actual))
  (after, Nothing) -> (after, Nothing)

lowerBindingValue :: LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerBindingValue state written = case lowerExpression state written of
  (after, Just (core, _)) ->
    let types = contextTypes (lowerContext after)
        (ready, held) = normalizeAggregateValue types (typeForSpan types (locatedSpan written)) after core
     in (ready, Just (held, coreExpressionType held))
  (after, Nothing) -> refused after

lowerStatement :: LowerState -> Located Statement -> (LowerState, Maybe CoreStatement)
lowerStatement state (Located statementSpan statement) = case statement of
  DeclarationStatement (Located declarationSpan (BindingDeclaration _ binding (Located _ name) annotation value))
    -> let panicked = annotatedPanic state annotation value in case maybe (lowerBindingValue state value) id panicked of
        (after, Just (coreValue, coreType))
          | expressionIsPrintValued coreValue -> halt declarationSpan "binding a Result[(), Str] value" after
          -- A binding annotated dynamic holds the value widened.
          | Just written <- annotation, Just declared <- writtenCoreType after written, declared /= coreType
          , let (ready, widened) = projectRuntimeValue (contextTypes (lowerContext after)) after declared coreValue
          , coreExpressionType widened == declared ->
              declareLocal binding ready declarationSpan name widened
          | Just _ <- annotation
          , Nothing <- panicked
          , not (hasRuntimeChoice coreType)
          , let solved = typeForSpan (contextTypes (lowerContext state)) (locatedSpan value)
          , solved == Nothing || (coreType /= CoreNeverType && solved /= Just coreType) ->
              halt declarationSpan "a binding without matching solved native type facts" after
          | nativeValueType coreType || coreType == CoreNeverType ->
              declareLocal binding after declarationSpan name coreValue
          | otherwise -> halt declarationSpan ("bindings of type " <> coreTypeName coreType) after
        (after, Nothing) -> refused after
  DeclarationStatement (Located declarationSpan _) ->
    halt declarationSpan "this declaration" state
  ExpressionStatement locatedExpression -> case locatedValue locatedExpression of
    -- A match as a statement drops each arm's value, as the evaluator does.
    MatchExpression subject arms -> case lowerMatch lowerExpression True state (locatedSpan locatedExpression) subject arms of
      (after, Just (core, _)) -> (after, Just CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = CoreEvaluate core})
      (after, Nothing) -> refused after
    IfLetExpression pattern' subject taken otherwise' ->
      case lowerMatch lowerExpression True state (locatedSpan locatedExpression) subject (ifLetArms (locatedSpan locatedExpression) pattern' taken otherwise') of
        (after, Just (core, _)) -> (after, Just CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = CoreEvaluate core})
        (after, Nothing) -> refused after
    BinaryExpression target "=" right
      | Just lowered <- lowerPlaceAssignment lowerExpression state statementSpan target right -> lowered
    BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
      | Just local <- lookupLocal state name -> case lowerLocalReplacement state local right of
          (after, Just (coreRight, coreType))
            | expressionIsPrintValued coreRight -> halt statementSpan "assigning a Result[(), Str] value" after
            | coreType == coreLocalType local || coreType == CoreNeverType ->
                ( after
                , Just
                    CoreStatement
                      { coreStatementSpan = statementSpan
                      , coreStatementShape = CoreAssign local (takeReceiver local coreRight)
                      }
                )
            | otherwise -> halt statementSpan "an assignment whose value has a different type" after
          (after, Nothing) -> refused after
    -- Expression lowering hands `=` back here; refuse rather than loop.
    BinaryExpression _ "=" _ -> halt statementSpan "this assignment target" state
    IfExpression condition thenBlock elseExpression ->
      case lowerCondition StrictCondition (locatedSpan locatedExpression) lowerExpression state condition of
        (after, Just (coreCondition, CoreNeverType)) ->
          (after, Just (CoreStatement statementSpan (CoreIf coreCondition (CoreBlock [] Nothing) Nothing)))
        (afterCondition, Just (coreCondition, _)) ->
          let (afterThen, coreThen, _) = lowerBlock afterCondition thenBlock
           in case elseExpression of
                Nothing ->
                  ( afterThen
                  , Just
                      CoreStatement
                        { coreStatementSpan = statementSpan
                        , coreStatementShape = CoreIf coreCondition coreThen Nothing
                        }
                  )
                Just locatedElse -> case lowerExpression afterThen locatedElse of
                  (afterElse, Just (coreElse, _)) ->
                    ( afterElse
                    , Just
                        CoreStatement
                          { coreStatementSpan = statementSpan
                          , coreStatementShape = CoreIf coreCondition coreThen (Just coreElse)
                          }
                    )
                  (afterElse, Nothing) -> refused afterElse
        (afterCondition, Nothing) -> refused afterCondition
    _ -> case lowerExpression state locatedExpression of
      (after, Just (coreExpression, _)) ->
        ( after
        , Just
            CoreStatement
              { coreStatementSpan = statementSpan
              , coreStatementShape = CoreEvaluate coreExpression
              }
        )
      (after, Nothing) -> refused after
  ReturnStatement Nothing ->
    let (joined, joins) = leaving state statementSpan
        (after, shape) = loanedReturn joined statementSpan Nothing
     in (observeReturn CoreUnitType after, Just (afterJoins statementSpan joins CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = shape}))
  ReturnStatement (Just located) -> case projectedReturn state located of
    (after, Just (coreValue, _))
      | expressionIsPrintValued coreValue ->
          halt (locatedSpan located) "returning a Result[(), Str] value" after
    (after, Just (coreValue, coreType))
      | allowedReturn coreType, null (lowerOpenScopes after) || coreType == CoreNeverType ->
          let (left, shape) = loanedReturn after statementSpan (Just coreValue)
           in (observeReturn coreType left, Just CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = shape})
      -- The value is in hand before the scopes the return leaves are joined.
      | allowedReturn coreType ->
          let (withKept, kept) = bindLocal after "" coreType
              (joined, joins) = leaving withKept statementSpan
              (left, shape) = loanedReturn joined statementSpan (Just (CoreExpression statementSpan coreType (CoreReadLocal kept)))
              held = CoreStatement statementSpan (CoreDeclare kept coreValue)
           in (observeReturn coreType left, Just (afterJoins statementSpan (held : joins) (CoreStatement statementSpan shape)))
    (after, Just (_, coreType)) ->
      halt (locatedSpan located) ("returning a " <> coreTypeName coreType <> " value") after
    (after, Nothing) -> refused after
  BreakStatement label operand -> joiningTransfer (lowerTransfer lowerExpression statementSpan label (Just operand) state)
  ContinueStatement label -> joiningTransfer (lowerTransfer lowerExpression statementSpan label Nothing state)
  LetElseStatement{} -> halt statementSpan "refutable pattern bindings" state
  LetPatternStatement{} -> halt statementSpan "pattern bindings" state
  InvalidStatement -> halt statementSpan "this statement" state
 where
  allowedReturn kind = allowedResultType (lowerFunctionResult state) kind
    || (lowerFlexibleResult state && nativeValueType kind)

projectedReturn :: LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
projectedReturn state located = case lowerExpression state located of
  (after, Just (value, _)) | Just expected <- lowerFunctionResult state ->
    let (ready, projected) = projectRuntimeValue (contextTypes (lowerContext after)) after expected value
     in (ready, Just (projected, coreExpressionType projected))
  outcome -> outcome

{-| A statement that leaves, after the joins it owes. -}
afterJoins :: Span -> [CoreStatement] -> CoreStatement -> CoreStatement
afterJoins _ [] final = final
afterJoins at joins final = CoreStatement at (CoreEvaluate (CoreExpression at CoreNeverType
  (CoreBlockValue (CoreBlock (joins <> [final]) Nothing))))

{-| A loop transfer joins the scopes opened inside the loop it leaves; a
    break's value is in hand first. -}
joiningTransfer :: (LowerState, Maybe CoreStatement) -> (LowerState, Maybe CoreStatement)
joiningTransfer (state, Just statement@(CoreStatement at shape))
  | not (null (lowerOpenScopes state)) = case shape of
      CoreContinue identity ->
        let (joined, joins) = leavingLoop state at identity in (joined, Just (afterJoins at joins statement))
      CoreBreak identity Nothing ->
        let (joined, joins) = leavingLoop state at identity in (joined, Just (afterJoins at joins statement))
      CoreBreak identity (Just operand) | coreExpressionType operand /= CoreNeverType ->
        let (withKept, kept) = bindLocal state "" (coreExpressionType operand)
            (joined, joins) = leavingLoop withKept at identity
            carried = CoreStatement at (CoreBreak identity (Just (CoreExpression at (coreExpressionType operand) (CoreReadLocal kept))))
         in (joined, Just (afterJoins at (if null joins then [] else CoreStatement at (CoreDeclare kept operand) : joins)
              (if null joins then statement else carried)))
      _ -> (state, Just statement)
joiningTransfer other = other

{-| Preserve an entry's explicit return type even when its outer block has
    no trailing expression. Checked programs already agree on return types. -}
observeReturn :: CoreType -> LowerState -> LowerState
observeReturn CoreNeverType state = state
observeReturn resultType state | lowerFlexibleResult state =
  state{lowerObservedReturns = Set.union (lowerObservedReturns state) (runtimeCarriers resultType)}
observeReturn resultType state = case lowerFunctionResult state of
  Nothing -> state{lowerFunctionResult = Just resultType}
  Just _ -> state

{-| Which operand types a `return` may carry: exactly the declared result for
    a non-entry function, an admitted integer or unit for the entry. -}
allowedResultType :: Maybe CoreType -> CoreType -> Bool
allowedResultType declared operand = case declared of
  Just expected -> operand == expected || operand == CoreNeverType
  Nothing -> case operand of
    CoreIntegerType kind -> nativeIntegerKind kind
    CoreFloatType _ -> True
    CoreTupleType _ -> True
    CoreRecordType _ _ -> True
    CoreSumType _ _ -> True
    CoreFunctionType _ _ -> True
    CoreArrayType _ -> True
    kind | treeType kind -> True
    CoreRangeType -> True
    CoreBytesType -> True
    _ -> operand `elem` [CoreBoolType, CoreTextType, CoreCharType, CoreUnitType, CoreNeverType, CoreDecimalType]

lowerArrayCallback :: [CoreType] -> LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerArrayCallback inputs state written@(Located at shape) = case shape of
  LambdaExpression function ->
    lowerLambdaWithInputs lowerExpression lowerBlock inputs state at function
  TypeApplication inner arguments ->
    lowerArrayCallback inputs (writtenTypeArguments state at inner arguments) inner
  NameExpression (first :| rest)
    | Nothing <- lookupLocal state first
    , Just selected <- named (first : rest) -> selected
  MemberExpression (Located _ (NameExpression (owner :| []))) (Located _ member)
    | isModuleQualifier state owner
    , Just selected <- named [owner, member] -> selected
  _ -> case lowerExpression state written of
    (after, Just (core, _)) -> specializeCallable lowerExpression lowerBlock inputs after core
    (after, Nothing) -> refused after
 where
  named path = do
    key <- resolveFunction state path
    entry <- lookup key (contextTable (lowerContext state))
    pure (lowerFunctionValueWithInputs inputs state at key entry)

lowerAwaited :: LowerState -> Span -> CoreExpression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerAwaited state at task
  | kind == CoreNeverType = (state, Just (task, kind))
  | Just selected <- mapRuntimeChoice state at CoreNeverType task
      (\current held -> fmap (fmap fst) (lowerAwaited current at held)) = selected
  | CoreFunctionType [] answered <- kind =
      let (ready, ran) = released state at task answered
          isResult (CoreSumType "Result" _) = True
          isResult _ = False
       in if not (Set.null (runtimeCarriers answered)) && all isResult (runtimeCarriers answered)
            then unwrapOrLeave ready at ran answered
            else (ready, Just (ran, answered))
  | otherwise = halt at ("awaiting a " <> coreTypeName kind <> " value") state
 where
  kind = coreExpressionType task

lowerExpression :: LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerExpression state (Located spanValue expression) = case expression of
  LiteralExpression literal -> case literal of
    ResolvedInteger kind number
      | nativeIntegerKind kind
      , integerKindFits kind number || integerKindFits kind (negate number) -> value (CoreIntegerLiteral kind number) (CoreIntegerType kind)
      | nativeIntegerKind kind -> halt spanValue "an integer literal outside the exact native carrier range" state
    ResolvedInteger kind _ ->
      halt spanValue ("the " <> coreTypeName (CoreIntegerType kind) <> " type") state
    IntegerValue _ -> halt spanValue "an unresolved integer literal" state
    BoolValue flag -> value (CoreBoolLiteral flag) CoreBoolType
    StringValue text -> value (CoreTextLiteral text) CoreTextType
    CharValue character -> value (CoreCharLiteral character) CoreCharType
    FloatValue text -> case parseFloatLiteral text of
      Just ParsedFloat{parsedFloatValue, parsedFloatWidth, parsedFloatFits = True} ->
        value (CoreFloatLiteral parsedFloatWidth (castDoubleToWord64 parsedFloatValue)) (CoreFloatType parsedFloatWidth)
      _ -> halt spanValue "a floating literal outside its width" state
    DecimalValue text -> value (decimalLiteral text) CoreDecimalType
    NullValue -> halt spanValue "null" state
  NameExpression (name :| []) -> case lookupLocal state name of
    Just local -> value (CoreReadLocal local) (coreLocalType local)
    Nothing | Just lowered <- lowerConstant lowerExpression state spanValue [name] -> lowered
    Nothing | Just key <- resolveFunction state [name], Just entry <- lookup key (contextTable (lowerContext state)) ->
      lowerFunctionValue state spanValue key entry
    Nothing | Just lowered <- lowerForeignValue state spanValue [name] -> lowered
    Nothing | Just lowered <- lowerCallbackValue state spanValue [name] -> lowered
    Nothing | Just lowered <- lowerIntrinsicValue state spanValue name -> lowered
    Nothing -> maybe (halt spanValue ("the value '" <> name <> "'") state) id
      (lowerVariant lowerExpression state spanValue name [])
  NameExpression ("::trait-method::" :| [provider, member]) ->
    lowerTraitMethodValue lowerExpression state spanValue provider member
  -- A dotted path names a module's constant, a module's function as a
  -- value, or a variant by its owner.
  NameExpression (first :| rest) ->
    case lowerConstant lowerExpression state spanValue (first : rest) of
      Just lowered -> lowered
      Nothing
        | Just key <- resolveFunction state (first : rest), Just entry <- lookup key (contextTable (lowerContext state)) ->
            lowerFunctionValue state spanValue key entry
      Nothing | Just lowered <- lowerForeignValue state spanValue (first : rest) -> lowered
      Nothing | Just lowered <- lowerCallbackValue state spanValue (first : rest) -> lowered
      Nothing -> maybe (halt spanValue "module-qualified names" state) id
        (lowerVariant lowerExpression state spanValue (last (first : rest)) [])
  UnaryExpression operator operand -> lowerUnary lowerExpression state spanValue operator operand
  -- An assignment's value is unit: it runs as the statement it is.
  BinaryExpression _ "=" _ -> case lowerStatement state (Located spanValue (ExpressionStatement (Located spanValue expression))) of
    (after, Just assigned) -> typed after (CoreBlockValue (CoreBlock [assigned] Nothing)) (blockType [assigned] Nothing)
    (after, Nothing) -> refused after
  BinaryExpression left operator right -> lowerBinary lowerExpression state spanValue left operator right
  -- The checker has already solved a type application's copy at this call.
  CallExpression (Located _ (TypeApplication (Located _ (NameExpression ("convertInteger" :| []))) _)) arguments
    | Nothing <- lookupLocal state "convertInteger"
    , Nothing <- resolveFunction state ["convertInteger"] -> lowerConvertInteger lowerExpression state spanValue arguments
  CallExpression callee@(Located _ (TypeApplication (Located _ (NameExpression ("::trait-method::" :| [_, _]))) _)) arguments ->
    lowerValueCall lowerExpression lowerBlock state spanValue callee arguments
  CallExpression (Located application (TypeApplication inner written)) arguments ->
    lowerExpression (writtenTypeArguments state application inner written) (Located spanValue (CallExpression inner arguments))
  CallExpression (Located callee (NameExpression (name :| []))) arguments
    | Just _ <- lookupLocal state name -> lowerValueCall lowerExpression lowerBlock state spanValue (Located callee (NameExpression (name :| []))) arguments
    | Just _ <- lookupConstant state [name] -> lowerValueCall lowerExpression lowerBlock state spanValue (Located callee (NameExpression (name :| []))) arguments
    | Just "Std.Option.unwrapOr" <- resolveFunction state [name]
    , Just lowered <- lowerFittingUnwrap lowerExpression state spanValue arguments -> lowered
    | Just key <- resolveFunction state [name] -> keepMarkup spanValue (lowerFunctionCall lowerExpression state spanValue key callee arguments)
    | Just lowered <- lowerCallbackRegistration lowerExpression state spanValue [name] arguments -> lowered
    | Just lowered <- lowerVariant lowerExpression state spanValue name arguments -> lowered
    | name `elem` ["print", "printPart", "printError", "printErrorPart"] -> lowerPrint lowerExpression state spanValue name arguments
    | name == "display" -> lowerRendered lowerExpression state spanValue name CoreDisplay arguments
    | name == "show" -> lowerRendered lowerExpression state spanValue name CoreShow arguments
    | name `elem` ["mapOf", "setOf"] -> lowerKeyedBuilder lowerExpression state spanValue name arguments
    | name == "charFromCode" -> lowerCharFromCode lowerExpression state spanValue arguments
    | name == "bytesOf" -> lowerBytesOf lowerExpression state spanValue arguments
    | name == "panic" -> lowerPanic lowerExpression state spanValue arguments
    | name == "convertInteger" -> lowerUntypedConvert lowerExpression state spanValue arguments
    | Just lowered <- lowerPrimitiveCall lowerExpression state spanValue name arguments -> lowered
    | otherwise -> halt spanValue ("calls to '" <> name <> "'") state
  CallExpression (Located _ (MemberExpression receiver (Located _ "unregister"))) arguments
    | Just lowered <- lowerCallbackUnregister lowerExpression clean spanValue receiver arguments -> lowered
  CallExpression (Located callee (MemberExpression receiver@(Located _ (NameExpression (owner :| []))) named@(Located _ member))) arguments
    | isModuleQualifier state owner, Just "Std.Option.unwrapOr" <- resolveFunction state [owner, member]
    , Just lowered <- lowerFittingUnwrap lowerExpression state spanValue arguments -> lowered
    | isModuleQualifier state owner, Just key <- resolveFunction state [owner, member] -> keepMarkup spanValue (lowerFunctionCall lowerExpression state spanValue key callee arguments)
    | isModuleQualifier state owner, Just _ <- lookupConstant state [owner, member] ->
        lowerValueCall lowerExpression lowerBlock state spanValue (Located callee (MemberExpression receiver named)) arguments
    | Just lowered <- lowerCallbackRegistration lowerExpression state spanValue [owner, member] arguments -> lowered
    | Just lowered <- lowerQualifiedForeignCall lowerExpression state spanValue owner member arguments -> lowered
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression clean spanValue member arguments -> lowered
    | qualifier receiver, Just lowered <- lowerQualifiedMethod lowerExpression state spanValue callee owner member arguments -> lowered
    | Just lowered <- lowerMethodCall lowerExpression (selectedMemberCall callee receiver member arguments)
        clean spanValue callee receiver member arguments -> keepMarkup spanValue lowered
    | functionField receiver member -> lowerValueCall lowerExpression lowerBlock clean spanValue (Located callee (MemberExpression receiver named)) arguments
    | otherwise -> lowerTextMethod lowerExpression (heldMember callee receiver member arguments)
        clean spanValue callee receiver member arguments
  CallExpression (Located callee (MemberExpression (Located owner (TypeApplication (Located _ (NameExpression path)) written)) (Located _ member))) arguments
    | Just kind <- writtenCoreType clean (Located owner (NamedType (ModuleName path) written))
    , Just lowered <- lowerOwnedMethod lowerExpression clean spanValue callee kind member arguments -> lowered
  -- `Module.Type.member(...)`: elaboration names an owner by its canonical path.
  CallExpression (Located callee (MemberExpression (Located _ (NameExpression (first :| rest@(_ : _)))) (Located _ member))) arguments
    | Nothing <- lookupLocal state first
    , Just lowered <- lowerQualifiedMethod lowerExpression state spanValue callee (Text.intercalate "." (first : rest)) member arguments -> lowered
  CallExpression (Located callee (MemberExpression receiver named@(Located _ member))) arguments
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression clean spanValue member arguments -> lowered
    | Just lowered <- lowerMethodCall lowerExpression (selectedMemberCall callee receiver member arguments)
        clean spanValue callee receiver member arguments -> keepMarkup spanValue lowered
    | functionField receiver member -> lowerValueCall lowerExpression lowerBlock clean spanValue (Located callee (MemberExpression receiver named)) arguments
    | otherwise -> lowerTextMethod lowerExpression (heldMember callee receiver member arguments)
        clean spanValue callee receiver member arguments
  CallExpression callee'@(Located _ (NameExpression ("::trait-method::" :| [_, _]))) arguments ->
    lowerValueCall lowerExpression lowerBlock state spanValue callee' arguments
  CallExpression callee'@(Located callee (NameExpression (first :| rest@(_ : _)))) arguments
    | Just key <- resolveFunction state (first : rest) -> lowerFunctionCall lowerExpression state spanValue key callee arguments
    | Just lowered <- lowerCallbackRegistration lowerExpression state spanValue (first : rest) arguments -> lowered
    | Just lowered <- lowerVariant lowerExpression state spanValue (last rest) arguments -> lowered
    | Just _ <- lookupConstant state (first : rest) -> lowerValueCall lowerExpression lowerBlock state spanValue callee' arguments
    | otherwise -> halt spanValue ("calls to '" <> Text.intercalate "." (first : rest) <> "'") state
  CallExpression (Located _ (RecordExpression written@(ModuleName ("::constructor::" :| _)) [])) arguments
    | Just lowered <- lowerVariant lowerExpression state spanValue (writtenLabel written) arguments -> lowered
  CallExpression callee arguments -> lowerValueCall lowerExpression lowerBlock state spanValue callee arguments
  MemberExpression receiver (Located _ member)
    | Located _ (NameExpression (owner :| [])) <- receiver
    , Just lowered <- lowerConstant lowerExpression state spanValue [owner, member] -> lowered
    | Located _ (NameExpression (owner :| [])) <- receiver, isModuleQualifier state owner
    , Just key <- resolveFunction state [owner, member], Just entry <- lookup key (contextTable (lowerContext state)) ->
        lowerFunctionValue state spanValue key entry
    | Located _ (NameExpression (owner :| [])) <- receiver
    , Just lowered <- lowerForeignValue state spanValue [owner, member] -> lowered
    | Located _ (NameExpression (owner :| [])) <- receiver
    , Just lowered <- lowerCallbackValue state spanValue [owner, member] -> lowered
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression state spanValue member [] -> lowered
    | member == "unregister"
    , Just lowered <- lowerCallbackUnregisterValue lowerExpression state spanValue receiver -> lowered
    | Just lowered <- lowerMethodValue lowerExpression state spanValue receiver member -> lowered
    | otherwise -> lowerField lowerExpression state spanValue receiver member
  IndexExpression receiver key -> lowerBracketIndex lowerExpression state spanValue receiver key
  RangeExpression low inclusive high -> lowerRangeValue lowerExpression state spanValue low inclusive high
  TryExpression operand -> lowerTry lowerExpression state spanValue operand
  -- Awaiting runs the task's body now; a failure it answers leaves this
  -- function as `?` would.
  AwaitExpression target -> case lowerExpression state target of
    (after, Just (task, _)) -> lowerAwaited after spanValue task
    (after, Nothing) -> refused after
  TupleExpression [] -> value (CoreBlockValue (CoreBlock [] Nothing)) CoreUnitType
  -- `(x,)` is a tuple of one member, as the evaluator holds it.
  TupleExpression members@(_ : _) -> lowerTuple lowerExpression state spanValue members
  ArrayExpression members -> lowerArrayLiteral lowerExpression state spanValue members
  SetExpression members -> lowerSetLiteral lowerExpression state spanValue members
  -- The capability is checked before lowering; the body runs as a block.
  UnsafeExpression _ body -> lowerExpression state (Located spanValue (BlockExpression body))
  MacroCall{} -> unexpanded "macro call reached evaluation unexpanded"
  ScopeExpression body -> lowerScope lowerBlock state spanValue body
  LambdaExpression function -> lowerLambda lowerExpression lowerBlock state spanValue function
  TypeApplication (Located _ (NameExpression ("::trait-method::" :| [provider, member]))) _ ->
    lowerTraitMethodValue lowerExpression state spanValue provider member
  -- `identity[Int]` as a value: the copy the written type arguments select.
  TypeApplication inner written -> lowerExpression (writtenTypeArguments state spanValue inner written) inner
  RecordExpression (ModuleName ("::constructor::" :| [owner, label])) [] ->
    lowerConstructorValue lowerExpression state spanValue owner label
  RecordExpression written fields -> lowerRecord lowerExpression state spanValue (writtenLabel written) fields
  RecordUpdateExpression written source fields -> lowerRecordUpdate lowerExpression state spanValue (writtenLabel written) source fields
  BlockExpression block ->
    let (after, coreBlock, resultType) = lowerBlock state block
        refusalCount = length . contextRefusals . lowerContext
     in if refusalCount after > refusalCount state
          then refused after
          else typed after (CoreBlockValue coreBlock) resultType
  IfExpression condition thenBlock (Just elseExpression) ->
    case lowerCondition StrictCondition spanValue lowerExpression state condition of
      (after, Just stopped@(_, CoreNeverType)) -> (after, Just stopped)
      (afterCondition, Just (coreCondition, _)) ->
        let (afterThen, coreThen, thenType) = lowerBlock afterCondition thenBlock
            thenValue = CoreExpression (locatedSpan thenBlock) thenType (CoreBlockValue coreThen)
            branch value' = case coreExpressionShape value' of
              CoreBlockValue entered -> entered
              _ -> CoreBlock [] (Just value')
         in case lowerExpression afterThen elseExpression of
              (afterElse, Nothing) -> refused afterElse
              (afterElse, Just (coreElse, _)) ->
                let checked = typeForSpan (contextTypes (lowerContext afterElse)) spanValue
                 in case joinBranchValues afterElse checked [thenValue, coreElse] of
                      Just (ready, result, [yes, no]) -> typed ready (CoreIfValue coreCondition (branch yes) no) result
                      _ -> halt (locatedSpan elseExpression) "an if whose branches have incompatible native layouts" afterElse
      (afterCondition, Nothing) -> refused afterCondition
  IfExpression _ _ Nothing ->
    case lowerStatement state (Located spanValue (ExpressionStatement (Located spanValue expression))) of
      (after, Just statement@(CoreStatement _ CoreIf{})) ->
        let block = CoreBlock [statement] Nothing
         in typed after (CoreBlockValue block) (blockType [statement] Nothing)
      (after, Just _) -> halt spanValue "an if without else outside the native statement form" after
      (after, Nothing) -> refused after
  WhileExpression label condition body -> lowerWhile lowerExpression lowerBlock spanValue label condition body state
  MatchExpression subject arms -> lowerMatch lowerExpression False state spanValue subject arms
  WhileLetExpression label pattern' subject body -> lowerExpression state (whileLetLoop spanValue label pattern' subject body)
  IfLetExpression pattern' subject taken otherwise' ->
    lowerMatch lowerExpression (null otherwise') state spanValue subject (ifLetArms spanValue pattern' taken otherwise')
  LoopExpression label body -> lowerLoop lowerBlock spanValue label body state
  ForExpression label binder iterated body -> lowerFor lowerExpression lowerBlock state spanValue label binder iterated body
  ComptimeForExpression{} -> unexpanded "compile-time loop reached evaluation unexpanded"
  InvalidExpression -> halt spanValue "this expression" state
  where
    typed after shape coreType = (after, Just (CoreExpression spanValue coreType shape, coreType))
    -- Only a callee's admission reads the type arguments written on a call.
    clean = state{lowerTypeArguments = []}
    value shape coreType = (state, Just (CoreExpression spanValue coreType shape, coreType))
    -- Expansion runs before checking, so one left over stops as it does when evaluated.
    unexpanded message = value (CoreFailText "E7001" Nothing (CoreExpression spanValue CoreTextType (CoreTextLiteral message)) Nothing) CoreNeverType

    -- `Shape.Circle(3)`: the receiver names a type, not a local.
    qualifier (Located _ (NameExpression (owner :| []))) = lookupLocal state owner == Nothing
    qualifier _ = False
    selectedMemberCall callee receiver member arguments current held place =
      lowerSelectedMember lowerExpression (\ready selected -> heldMember callee receiver member arguments ready selected place)
        current spanValue callee member arguments held
    heldMember callee receiver member arguments current held place =
      unqualified fieldCall <|> unqualified collection <|> lowerHeldMethod lowerExpression spanValue member arguments current held place
     where
      -- A checked trait member names neither a field nor a builtin method.
      (provider, plain) = selectedMember member
      unqualified found = maybe found (const Nothing) provider
      kind = coreExpressionType held
      types = contextTypes (lowerContext current)
      checked owner = case typeForSpan types (locatedSpan receiver) of
        Just expected | ownerKeyOf expected == Just owner -> expected
        _ -> kind
      fieldCall = do
        field <- recordFields types kind >>= lookup plain
        let reading = CoreExpression callee field (CoreField plain held)
            name = Located callee (MemberExpression receiver (Located callee plain))
            lowerFieldValue ready syntax
              | locatedSpan syntax == callee = (ready, Just (reading, field))
              | otherwise = lowerExpression ready syntax
            context = lowerContext current
            opened = current{lowerContext = context{contextTypes = withFacts [(callee, unformed field)] types}}
            (after, result) = lowerValueCall lowerFieldValue lowerBlock opened spanValue name arguments
         in Just (after{lowerContext = (lowerContext after){contextTypes = types}}, result)
      collection = do
        owner <- ownerKeyOf kind
        let specialize = specializeTraversalCallback lowerExpression lowerBlock
        if plain == "toText" || plain `notElem` builtinMethodNamesFor owner then Nothing else
          case kind of
            CoreArrayType element ->
              let input = case checked owner of
                    CoreArrayType declared -> declared
                    _ -> element
               in Just (lowerArrayMethod lowerExpression lowerArrayCallback specialize current spanValue input held plain arguments)
            CoreRangeType -> Just (lowerRangeMethod lowerExpression lowerArrayCallback specialize current spanValue held plain arguments)
            _ | treeType kind -> Just (lowerKeyedMethod lowerExpression current spanValue (checked owner) held plain arguments)
            _ -> Nothing
    -- With no method of that name, a call reads the field and calls what it holds.
    functionField receiver member = case typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver) of
      Just kind@(CoreRecordType _ _) | Just (CoreFunctionType _ _) <- recordFields (contextTypes (lowerContext state)) kind >>= lookup member -> True
      _ -> False
