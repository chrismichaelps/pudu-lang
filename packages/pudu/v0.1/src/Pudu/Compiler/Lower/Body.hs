{-| @Pudu.Compiler.Lower.Body — mutually recursive block/expression traversal.
    State and signature admission remain independently owned. -}
module Pudu.Compiler.Lower.Body (lowerEntryBody, lowerFunctionBody, lowerExpression) where

import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Compiler.Lower.Scalar (lowerUnary, lowerBinary, eagerType)
import Pudu.Compiler.Lower.Types (recordFields, typeForSpan, nativeIntegerKind, nativeValueType, treeType, writtenLabel)
import Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinType
  , expressionIsPrintValued )
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..)
  , bindLocal, halt, isModuleQualifier, lookupLocal, refuse, refused, resolveFunction )
import Pudu.Compiler.Lower.Text (lowerTextMethod)
import Pudu.Compiler.Lower.Method (lowerMethodCall, lowerOwnedMethod, lowerQualifiedMethod)
import Pudu.Compiler.Lower.Call (lowerFunctionCall, lowerPrint, lowerRendered)
import Pudu.Compiler.Lower.FunctionBody (lowerEntryBodyWith, lowerFunctionBodyWith)
import Pudu.Compiler.Lower.Array (lowerArrayIndex, lowerArrayLiteral, lowerArrayMethod, takeReceiver)
import Pudu.Compiler.Lower.Slice (lowerRangeIndex)
import Pudu.Compiler.Lower.Convert (lowerCharFromCode, lowerConvertInteger)
import Pudu.Compiler.Lower.Keyed (lowerKeyedBuilder, lowerKeyedMethod, lowerSetLiteral)
import Pudu.Compiler.Lower.Range (lowerRangeMethod, lowerRangeValue)
import Pudu.Compiler.Lower.Bytes (lowerBytesMethod, lowerBytesOf)
import Control.Applicative ((<|>))
import Pudu.Compiler.Lower.Try (lowerTry, unwrapOrLeave)
import Pudu.Compiler.Lower.Scope (leaving, leavingLoop, lowerScope, released)
import Pudu.Compiler.Lower.Decimal (decimalLiteral)
import Pudu.Compiler.Lower.Dynamic (isDynamic, widen, widenBlock, widenTo)
import Pudu.Compiler.Lower.Generic (writtenCoreType, writtenTypeArguments)
import Pudu.Compiler.Lower.For (lowerFor)
import Pudu.Compiler.Lower.Intrinsic (annotatedPanic, lowerIntrinsicValue)
import Pudu.Compiler.Lower.Primitive (lowerPrimitiveCall)
import Pudu.Compiler.Lower.MethodValue (lowerMethodValue)
import Pudu.Compiler.Lower.Stop (lowerPanic, lowerUntypedConvert)
import Pudu.Compiler.Lower.Lambda (lowerFunctionValue, lowerLambda, lowerValueCall)
import Pudu.Compiler.Lower.Tuple (lowerTuple, lowerTupleIndex, lowerTuplePattern)
import Pudu.Compiler.Lower.Place (lowerPlaceAssignment)
import Pudu.Compiler.Lower.Loan (loanedReturn)
import Pudu.Compiler.Lower.Record (lowerField, lowerRecord, lowerRecordUpdate)
import Pudu.Compiler.Lower.Sum (lowerVariant)
import Pudu.Compiler.Lower.Constant (lowerConstant)
import Pudu.Compiler.Lower.Match (hasSequencePattern, ifLetArms, lowerLetElse, lowerLetSequence, lowerMatch, whileLetLoop)
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Core
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
    | Just local <- lookupLocal state name -> case fmap (widenTo (contextTypes (lowerContext state)) (coreLocalType local)) <$> lowerExpression state right of
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
      LetPatternStatement _ pattern _ subject | hasSequencePattern pattern ->
        case lowerLetSequence lowerExpression current statementSpan pattern subject of
          (after, Just lowered) -> go after (lowered : collected) rest
          (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)
      LetPatternStatement _ pattern annotation subject
        -> case lowerTuplePattern lowerExpression current statementSpan pattern annotation subject of
            (after, Just statements) -> go after (reverse statements <> collected) rest
            (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)
      _ -> case lowerStatement current one of
        (after, Just lowered)
          | LetElseStatement{} <- statement, blockType [lowered] Nothing == CoreNeverType ->
              (after, reverse (lowered : collected), True)
        (after, Just lowered) -> go after (lowered : collected) rest
        (after, Nothing) -> (unexplained current statementSpan after, reverse collected, True)

lowerStatement :: LowerState -> Located Statement -> (LowerState, Maybe CoreStatement)
lowerStatement state (Located statementSpan statement) = case statement of
  DeclarationStatement (Located declarationSpan (BindingDeclaration _ _ (Located _ name) annotation value))
    -> let panicked = annotatedPanic state annotation value in case maybe (lowerExpression state value) id panicked of
        (after, Just (coreValue, coreType))
          | expressionIsPrintValued coreValue -> halt declarationSpan "binding a Result[(), Str] value" after
          -- A binding annotated dynamic holds the value widened.
          | Just written <- annotation, Just declared <- writtenCoreType after written, declared /= coreType
          , let widened = widen (contextTypes (lowerContext after)) declared coreValue
          , coreExpressionType widened == declared ->
              let (withLocal, local) = bindLocal after name declared
               in (withLocal, Just (CoreStatement declarationSpan (CoreDeclare local widened)))
          | Just _ <- annotation
          , Nothing <- panicked
          , let solved = typeForSpan (contextTypes (lowerContext state)) (locatedSpan value)
          , solved == Nothing || (coreType /= CoreNeverType && solved /= Just coreType) ->
              halt declarationSpan "a binding without matching solved native type facts" after
          | nativeValueType coreType || coreType == CoreNeverType ->
              let (withLocal, local) = bindLocal after name coreType
               in ( withLocal
                  , Just
                      CoreStatement
                        { coreStatementSpan = declarationSpan
                        , coreStatementShape = CoreDeclare local coreValue
                        }
                  )
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
      | Just local <- lookupLocal state name -> case fmap (widenTo (contextTypes (lowerContext state)) (coreLocalType local)) <$> lowerExpression state right of
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
    IfExpression condition thenBlock elseExpression -> case lowerExpression state condition of
      (afterCondition, Just (coreCondition, conditionType))
        | conditionType `elem` [CoreBoolType, CoreNeverType] ->
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
      (afterCondition, Just (_, coreType)) ->
        halt (locatedSpan condition) ("an if condition of type " <> coreTypeName coreType) afterCondition
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
  ReturnStatement (Just located) -> case fmap (maybe id (widenTo (contextTypes (lowerContext state))) (lowerFunctionResult state)) <$> lowerExpression state located of
    (after, Just (coreValue, _))
      | expressionIsPrintValued coreValue ->
          halt (locatedSpan located) "returning a Result[(), Str] value" after
    (after, Just (coreValue, coreType))
      | allowedResultType (lowerFunctionResult state) coreType, null (lowerOpenScopes after) || coreType == CoreNeverType ->
          let (left, shape) = loanedReturn after statementSpan (Just coreValue)
           in (observeReturn coreType left, Just CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = shape})
      -- The value is in hand before the scopes the return leaves are joined.
      | allowedResultType (lowerFunctionResult state) coreType ->
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
  LetElseStatement pattern' subject fallback -> lowerLetElse lowerExpression state statementSpan pattern' subject fallback
  LetPatternStatement{} -> halt statementSpan "pattern bindings" state
  InvalidStatement -> halt statementSpan "this statement" state

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
    Nothing | Just lowered <- lowerIntrinsicValue state spanValue name -> lowered
    Nothing -> maybe (halt spanValue ("the value '" <> name <> "'") state) id
      (lowerVariant lowerExpression state spanValue name [])
  NameExpression (first :| rest) ->
    case lowerConstant lowerExpression state spanValue (first : rest) of
      Just lowered -> lowered
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
  CallExpression (Located application (TypeApplication inner written)) arguments ->
    lowerExpression (writtenTypeArguments state application inner written) (Located spanValue (CallExpression inner arguments))
  CallExpression (Located callee (NameExpression (name :| []))) arguments
    | Just _ <- lookupLocal state name -> lowerValueCall lowerExpression state spanValue (Located callee (NameExpression (name :| []))) arguments
    | Just key <- resolveFunction state [name] -> lowerFunctionCall lowerExpression state spanValue key callee arguments
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
  CallExpression (Located callee (MemberExpression receiver@(Located _ (NameExpression (owner :| []))) named@(Located _ member))) arguments
    | isModuleQualifier state owner, Just key <- resolveFunction state [owner, member] -> lowerFunctionCall lowerExpression state spanValue key callee arguments
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression clean spanValue member arguments -> lowered
    | qualifier receiver, Just lowered <- lowerQualifiedMethod lowerExpression state spanValue callee owner member arguments -> lowered
    | Just lowered <- lowerMethodCall lowerExpression clean spanValue callee receiver member arguments -> lowered
    | functionField receiver member -> lowerValueCall lowerExpression clean spanValue (Located callee (MemberExpression receiver named)) arguments
    | Just lowered <- lowerArrayMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | Just lowered <- lowerKeyedMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | Just lowered <- lowerRangeMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | Just lowered <- lowerBytesMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | otherwise -> lowerTextMethod lowerExpression clean spanValue receiver member arguments
  CallExpression (Located callee (MemberExpression (Located owner (TypeApplication (Located _ (NameExpression path)) written)) (Located _ member))) arguments
    | Just kind <- writtenCoreType clean (Located owner (NamedType (ModuleName path) written))
    , Just lowered <- lowerOwnedMethod lowerExpression clean spanValue callee kind member arguments -> lowered
  -- `Module.Type.member(...)`: elaboration names an owner by its canonical path.
  CallExpression (Located callee (MemberExpression (Located _ (NameExpression (first :| rest@(_ : _)))) (Located _ member))) arguments
    | Nothing <- lookupLocal state first
    , Just lowered <- lowerQualifiedMethod lowerExpression state spanValue callee (Text.intercalate "." (first : rest)) member arguments -> lowered
  CallExpression (Located callee (MemberExpression receiver named@(Located _ member))) arguments
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression clean spanValue member arguments -> lowered
    | Just lowered <- lowerMethodCall lowerExpression clean spanValue callee receiver member arguments -> lowered
    | functionField receiver member -> lowerValueCall lowerExpression clean spanValue (Located callee (MemberExpression receiver named)) arguments
    | Just lowered <- lowerArrayMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | Just lowered <- lowerKeyedMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | Just lowered <- lowerRangeMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | Just lowered <- lowerBytesMethod lowerExpression clean spanValue receiver member arguments -> lowered
    | otherwise -> lowerTextMethod lowerExpression clean spanValue receiver member arguments
  CallExpression (Located callee (NameExpression (first :| rest@(_ : _)))) arguments
    | Just key <- resolveFunction state (first : rest) -> lowerFunctionCall lowerExpression state spanValue key callee arguments
    | Just lowered <- lowerVariant lowerExpression state spanValue (last rest) arguments -> lowered
    | otherwise -> halt spanValue ("calls to '" <> Text.intercalate "." (first : rest) <> "'") state
  CallExpression (Located _ (RecordExpression written@(ModuleName ("::constructor::" :| _)) [])) arguments
    | Just lowered <- lowerVariant lowerExpression state spanValue (writtenLabel written) arguments -> lowered
  CallExpression callee arguments -> lowerValueCall lowerExpression state spanValue callee arguments
  MemberExpression receiver (Located _ member)
    | Located _ (NameExpression (owner :| [])) <- receiver
    , Just lowered <- lowerConstant lowerExpression state spanValue [owner, member] -> lowered
    | Located _ (NameExpression (owner :| [])) <- receiver, isModuleQualifier state owner
    , Just key <- resolveFunction state [owner, member], Just entry <- lookup key (contextTable (lowerContext state)) ->
        lowerFunctionValue state spanValue key entry
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression state spanValue member [] -> lowered
    | Just lowered <- lowerMethodValue lowerExpression state spanValue receiver member -> lowered
    | otherwise -> lowerField lowerExpression state spanValue receiver member
  IndexExpression receiver key -> maybe (lowerTupleIndex lowerExpression state spanValue receiver key) id
    (lowerRangeIndex lowerExpression state receiver key <|> lowerArrayIndex lowerExpression state spanValue receiver key)
  RangeExpression low inclusive high -> lowerRangeValue lowerExpression state spanValue low inclusive high
  TryExpression operand -> lowerTry lowerExpression state spanValue operand
  -- Awaiting runs the task's body now; a failure it answers leaves this
  -- function as `?` would.
  AwaitExpression target -> case lowerExpression state target of
    (after, Just (task, CoreFunctionType [] answered)) ->
      let (let', ran) = released after spanValue task answered
       in case answered of
            CoreSumType "Result" _ -> unwrapOrLeave let' spanValue ran answered
            _ -> (let', Just (ran, answered))
    (after, Just (stopped, CoreNeverType)) -> (after, Just (stopped, CoreNeverType))
    (after, Just (_, kind)) -> halt spanValue ("awaiting a " <> coreTypeName kind <> " value") after
    (after, Nothing) -> refused after
  TupleExpression [] -> value (CoreBlockValue (CoreBlock [] Nothing)) CoreUnitType
  TupleExpression members@(_ : _ : _) -> lowerTuple lowerExpression state spanValue members
  TupleExpression{} -> halt spanValue "tuples" state
  ArrayExpression members -> lowerArrayLiteral lowerExpression state spanValue members
  SetExpression members -> lowerSetLiteral lowerExpression state spanValue members
  -- The capability is checked before lowering; the body runs as a block.
  UnsafeExpression _ body -> lowerExpression state (Located spanValue (BlockExpression body))
  MacroCall{} -> unexpanded "macro call reached evaluation unexpanded"
  ScopeExpression body -> lowerScope lowerBlock state spanValue body
  LambdaExpression function -> lowerLambda lowerExpression lowerBlock state spanValue function
  TypeApplication{} -> halt spanValue "type applications" state
  RecordExpression written@(ModuleName ("::constructor::" :| _)) [] ->
    maybe (halt spanValue "this constructor" state) id (lowerVariant lowerExpression state spanValue (writtenLabel written) [])
  RecordExpression written fields -> lowerRecord lowerExpression state spanValue (writtenLabel written) fields
  RecordUpdateExpression _ source fields -> lowerRecordUpdate lowerExpression state spanValue source fields
  BlockExpression block ->
    let (after, coreBlock, resultType) = lowerBlock state block
        refusalCount = length . contextRefusals . lowerContext
     in if refusalCount after > refusalCount state
          then refused after
          else typed after (CoreBlockValue coreBlock) resultType
  IfExpression condition thenBlock (Just elseExpression) ->
    case lowerExpression state condition of
      (afterCondition, Just (coreCondition, conditionType))
        | conditionType `elem` [CoreBoolType, CoreNeverType] ->
          let (afterThen, coreThen, thenType) = lowerBlock afterCondition thenBlock
           in case lowerExpression afterThen elseExpression of
                (afterElse, Just (coreElse, elseType))
                  | Just resultType <- joinType thenType elseType ->
                      typed afterElse (CoreIfValue coreCondition coreThen coreElse) (eagerType resultType [coreCondition])
                  -- Branches of different implementing types widen to the dynamic type the `if` has.
                  | Just expected <- typeForSpan (contextTypes (lowerContext afterElse)) spanValue, isDynamic expected
                  , let widenedThen = widenBlock (contextTypes (lowerContext afterElse)) expected coreThen
                        widenedElse = widen (contextTypes (lowerContext afterElse)) expected coreElse
                  , all (`elem` [expected, CoreNeverType]) [blockType (coreBlockStatements widenedThen) (coreBlockResult widenedThen), coreExpressionType widenedElse] ->
                      typed afterElse (CoreIfValue coreCondition widenedThen widenedElse) (eagerType expected [coreCondition])
                  | otherwise ->
                      halt (locatedSpan elseExpression) "an if whose branches have different types" afterElse
                (afterElse, Nothing) -> refused afterElse
      (afterCondition, Just (_, conditionType)) ->
        halt (locatedSpan condition) ("an if condition of type " <> coreTypeName conditionType) afterCondition
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
    -- With no method of that name, a call reads the field and calls what it holds.
    functionField receiver member = case typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver) of
      Just kind@(CoreRecordType _ _) | Just (CoreFunctionType _ _) <- recordFields (contextTypes (lowerContext state)) kind >>= lookup member -> True
      _ -> False
