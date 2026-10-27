{-| @Pudu.Compiler.Lower.Body — lower function bodies through lexical blocks,
    statements and expressions. State and signature admission have independent
    owners; mutual block/expression recursion stays within this traversal. -}
module Pudu.Compiler.Lower.Body (lowerEntryBody, lowerFunctionBody, lowerExpression) where

import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Compiler.Lower.Scalar (lowerUnary, lowerBinary, eagerType)
import Pudu.Compiler.Lower.Types (recordFields, typeForSpan, nativeIntegerKind, nativeValueType)
import Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinType
  , printValued, expressionIsPrintValued )
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..)
  , bindLocal, halt, isModuleQualifier, lookupLocal, refuse, refused, resolveFunction )
import Pudu.Compiler.Lower.Signature (functionLevelRefusal)
import Pudu.Compiler.Lower.Text (lowerTextMethod)
import Pudu.Compiler.Lower.Method (lowerMethodCall, lowerQualifiedMethod)
import Pudu.Compiler.Lower.Call (lowerFunctionCall, lowerPrint, lowerRendered)
import Pudu.Compiler.Lower.Array (lowerArrayIndex, lowerArrayLiteral, lowerArrayMethod, takeReceiver)
import Pudu.Compiler.Lower.Slice (lowerRangeIndex)
import Pudu.Compiler.Lower.Convert (lowerCharFromCode, lowerConvertInteger)
import Pudu.Compiler.Lower.Keyed (lowerKeyedBuilder, lowerKeyedMethod, lowerSetLiteral)
import Pudu.Compiler.Lower.Range (lowerRangeMethod, lowerRangeValue)
import Pudu.Compiler.Lower.Bytes (lowerBytesMethod, lowerBytesOf)
import Control.Applicative ((<|>))
import Pudu.Compiler.Lower.Try (lowerTry)
import Pudu.Compiler.Lower.For (lowerFor)
import Pudu.Compiler.Lower.Intrinsic (annotatedPanic, lowerIntrinsicValue)
import Pudu.Compiler.Lower.Stop (lowerPanic, lowerUntypedConvert)
import Pudu.Compiler.Lower.Lambda (lowerFunctionValue, lowerLambda, lowerValueCall)
import Pudu.Compiler.Lower.Tuple (lowerTuple, lowerTupleIndex, lowerTuplePattern)
import Pudu.Compiler.Lower.Record (lowerField, lowerFieldAssignment, lowerRecord, lowerRecordUpdate)
import Pudu.Compiler.Lower.Sum (lowerVariant)
import Pudu.Compiler.Lower.Constant (lowerConstant)
import Pudu.Compiler.Lower.Match (ifLetArms, lowerLetElse, lowerMatch, whileLetLoop)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import Pudu.Core
import Pudu.Frontend.Syntax
  ( BindingKind (..), Block (..), Declaration (..), Expression (..)
  , Function (..), FunctionBody (..), Literal (..), Located (..), Statement (..) )
import GHC.Float (castDoubleToWord64)
import Pudu.FloatLiteral (ParsedFloat (..), parseFloatLiteral)
import Pudu.IntegerLiteral (integerKindFits)
import Pudu.Source (Span)

{-| The entry carries an admitted integer, Bool, float, Str, Char, tuple, record, sum or unit; a body that never
    returns uses the unit ABI. Integers become the exit status and every other value is
    printed as `renderValue` writes it, the same split `pudu run` makes. -}
lowerEntryBody :: Located Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerEntryBody located state
  | not (null (functionParameters function)) =
      halt atName "parameters on the entry function" state
  | otherwise = case functionLevelRefusal function of
      Just (spanValue, construct) -> halt spanValue construct state
      Nothing -> case functionBlock function of
        Just block ->
          let (after, coreBlock, resultType) = lowerBlock state block
           in case maybe resultType id (lowerFunctionResult after) of
                kind@(CoreIntegerType integerKind) | nativeIntegerKind integerKind -> built after coreBlock kind
                kind@(CoreFloatType _) -> built after coreBlock kind
                CoreBoolType -> built after coreBlock CoreBoolType
                CoreTextType -> built after coreBlock CoreTextType
                CoreCharType -> built after coreBlock CoreCharType
                kind@(CoreTupleType _) -> built after coreBlock kind
                kind@(CoreRecordType _ _) -> built after coreBlock kind
                kind@(CoreSumType _ _) -> built after coreBlock kind
                kind@(CoreFunctionType _ _) -> built after coreBlock kind
                kind@(CoreArrayType _) -> built after coreBlock kind
                kind@(CoreMapType _ _) -> built after coreBlock kind
                kind@(CoreSetType _) -> built after coreBlock kind
                CoreRangeType -> built after coreBlock CoreRangeType
                CoreBytesType -> built after coreBlock CoreBytesType
                CoreNeverType -> built after coreBlock CoreUnitType
                CoreUnitType
                  | printValued coreBlock ->
                      halt
                        (maybe atName locatedSpan (blockResult (locatedValue block)))
                        "a main function that returns Result[(), Str]"
                        after
                  | otherwise -> built after coreBlock CoreUnitType
                other ->
                  halt
                    (maybe atName locatedSpan (blockResult (locatedValue block)))
                    ("a main function that returns " <> coreTypeName other)
                    after
        _ -> refused state
  where
    function = locatedValue located
    atName = locatedSpan (functionName function)
    built after coreBlock resultType =
      ( after
      , Just
          CoreFunction
            { coreFunctionName = locatedValue (functionName function)
            , coreFunctionParameters = []
            , coreFunctionResult = resultType
            , coreFunctionBody = coreBlock
            }
      )

{-| Lower a non-entry function against its settled signature. The checker
    has already proved result agreement; structural lowering preserves the
    signature without inferring another return type. -}
lowerFunctionBody :: Located Function -> CoreSignature -> LowerState -> (LowerState, Maybe CoreFunction)
lowerFunctionBody located signature state = case functionBlock function of
  Just block ->
    let (after, coreBlock, _) = lowerBlock state block
        final
          | printValued coreBlock = refuse (locatedSpan block) "a function body returning Result[(), Str]" after
          | otherwise = after
     in ( final
        , Just
            CoreFunction
              { coreFunctionName = locatedValue (functionName function)
              , coreFunctionParameters = signatureParameters signature
              , coreFunctionResult = signatureResult signature
              , coreFunctionBody = coreBlock
              }
        )
  _ -> refused state
  where
    function = locatedValue located

functionBlock :: Function -> Maybe (Located Block)
functionBlock function = case functionBody function of
  Just (Located _ (BlockBody block)) -> Just block
  Just (Located at (ExpressionBody expression)) ->
    Just (Located at (Block [] (Just expression)))
  Nothing -> Nothing

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

{-| A block's trailing expression. An assignment there is an effect whose
    value the checker gives as unit, so it becomes a statement and the block's
    result is empty — the same reading the evaluator takes. -}
lowerBlockResult :: LowerState -> Located Expression -> (LowerState, [CoreStatement], Maybe CoreExpression, CoreType)
lowerBlockResult state located@(Located expressionSpan expression) = case expression of
  BinaryExpression target@(Located _ MemberExpression{}) "=" right
    | Just (after, assigned) <- lowerFieldAssignment lowerExpression state expressionSpan target right ->
        (after, maybe [] pure assigned, Nothing, CoreUnitType)
  BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
    | Just local <- lookupLocal state name -> case lowerExpression state right of
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
      LetPatternStatement kind pattern annotation subject
        | kind == CompileTime -> (refuse statementSpan "comptime bindings" current, reverse collected, True)
        | otherwise -> case lowerTuplePattern lowerExpression current statementSpan pattern annotation subject of
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
  DeclarationStatement (Located declarationSpan (BindingDeclaration _ kind (Located nameSpan name) annotation value))
    | kind == CompileTime -> halt nameSpan "comptime bindings" state
    | otherwise -> let panicked = annotatedPanic state annotation value in case maybe (lowerExpression state value) id panicked of
        (after, Just (coreValue, coreType))
          | expressionIsPrintValued coreValue -> halt declarationSpan "binding a Result[(), Str] value" after
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
    BinaryExpression target@(Located _ MemberExpression{}) "=" right
      | Just lowered <- lowerFieldAssignment lowerExpression state statementSpan target right -> lowered
    BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
      | Just local <- lookupLocal state name -> case lowerExpression state right of
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
    ( observeReturn CoreUnitType state
    , Just CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = CoreReturn Nothing}
    )
  ReturnStatement (Just located) -> case lowerExpression state located of
    (after, Just (coreValue, _))
      | expressionIsPrintValued coreValue ->
          halt (locatedSpan located) "returning a Result[(), Str] value" after
    (after, Just (coreValue, coreType))
      | allowedResultType (lowerFunctionResult state) coreType ->
          ( observeReturn coreType after
          , Just
              CoreStatement
                { coreStatementSpan = statementSpan
                , coreStatementShape = CoreReturn (Just coreValue)
                }
          )
    (after, Just (_, coreType)) ->
      halt (locatedSpan located) ("returning a " <> coreTypeName coreType <> " value") after
    (after, Nothing) -> refused after
  BreakStatement label operand -> lowerTransfer lowerExpression statementSpan label (Just operand) state
  ContinueStatement label -> lowerTransfer lowerExpression statementSpan label Nothing state
  LetElseStatement pattern' subject fallback -> lowerLetElse lowerExpression state statementSpan pattern' subject fallback
  LetPatternStatement{} -> halt statementSpan "pattern bindings" state
  InvalidStatement -> halt statementSpan "this statement" state

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
    CoreMapType _ _ -> True
    CoreSetType _ -> True
    CoreRangeType -> True
    CoreBytesType -> True
    _ -> operand `elem` [CoreBoolType, CoreTextType, CoreCharType, CoreUnitType, CoreNeverType]

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
    DecimalValue _ -> halt spanValue "decimal values" state
    NullValue -> halt spanValue "null" state
  NameExpression (name :| []) -> case lookupLocal state name of
    Just local -> value (CoreReadLocal local) (coreLocalType local)
    Nothing | Just lowered <- lowerConstant state spanValue [name] -> lowered
    Nothing | Just key <- resolveFunction state [name], Just entry <- lookup key (contextTable (lowerContext state)) ->
      lowerFunctionValue state spanValue key entry
    Nothing | Just lowered <- lowerIntrinsicValue state spanValue name -> lowered
    Nothing -> maybe (halt spanValue ("the value '" <> name <> "'") state) id
      (lowerVariant lowerExpression state spanValue name [])
  NameExpression (first :| rest) ->
    case lowerConstant state spanValue (first : rest) of
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
  CallExpression (Located _ (TypeApplication inner _)) arguments -> lowerExpression state (Located spanValue (CallExpression inner arguments))
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
    | otherwise -> halt spanValue ("calls to '" <> name <> "'") state
  CallExpression (Located callee (MemberExpression receiver@(Located _ (NameExpression (owner :| []))) named@(Located _ member))) arguments
    | isModuleQualifier state owner, Just key <- resolveFunction state [owner, member] -> lowerFunctionCall lowerExpression state spanValue key callee arguments
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression state spanValue member arguments -> lowered
    | qualifier receiver, Just lowered <- lowerQualifiedMethod lowerExpression state spanValue callee owner member arguments -> lowered
    | Just lowered <- lowerMethodCall lowerExpression state spanValue callee receiver member arguments -> lowered
    | functionField receiver member -> lowerValueCall lowerExpression state spanValue (Located callee (MemberExpression receiver named)) arguments
    | Just lowered <- lowerArrayMethod lowerExpression state spanValue receiver member arguments -> lowered
    | Just lowered <- lowerKeyedMethod lowerExpression state spanValue receiver member arguments -> lowered
    | Just lowered <- lowerRangeMethod lowerExpression state spanValue receiver member arguments -> lowered
    | Just lowered <- lowerBytesMethod lowerExpression state spanValue receiver member arguments -> lowered
    | otherwise -> lowerTextMethod lowerExpression state spanValue receiver member arguments
  CallExpression (Located callee (MemberExpression receiver named@(Located _ member))) arguments
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression state spanValue member arguments -> lowered
    | Just lowered <- lowerMethodCall lowerExpression state spanValue callee receiver member arguments -> lowered
    | functionField receiver member -> lowerValueCall lowerExpression state spanValue (Located callee (MemberExpression receiver named)) arguments
    | Just lowered <- lowerArrayMethod lowerExpression state spanValue receiver member arguments -> lowered
    | Just lowered <- lowerKeyedMethod lowerExpression state spanValue receiver member arguments -> lowered
    | Just lowered <- lowerRangeMethod lowerExpression state spanValue receiver member arguments -> lowered
    | Just lowered <- lowerBytesMethod lowerExpression state spanValue receiver member arguments -> lowered
    | otherwise -> lowerTextMethod lowerExpression state spanValue receiver member arguments
  CallExpression (Located callee (NameExpression (first :| rest@(_ : _)))) arguments
    | Just key <- resolveFunction state (first : rest) -> lowerFunctionCall lowerExpression state spanValue key callee arguments
    | Just lowered <- lowerVariant lowerExpression state spanValue (last rest) arguments -> lowered
    | otherwise -> halt spanValue ("calls to '" <> Text.intercalate "." (first : rest) <> "'") state
  CallExpression callee arguments -> lowerValueCall lowerExpression state spanValue callee arguments
  MemberExpression receiver (Located _ member)
    | Located _ (NameExpression (owner :| [])) <- receiver
    , Just lowered <- lowerConstant state spanValue [owner, member] -> lowered
    | Located _ (NameExpression (owner :| [])) <- receiver, isModuleQualifier state owner
    , Just key <- resolveFunction state [owner, member], Just entry <- lookup key (contextTable (lowerContext state)) ->
        lowerFunctionValue state spanValue key entry
    | qualifier receiver, Just lowered <- lowerVariant lowerExpression state spanValue member [] -> lowered
    | otherwise -> lowerField lowerExpression state spanValue receiver member
  IndexExpression receiver key -> maybe (lowerTupleIndex lowerExpression state spanValue receiver key) id
    (lowerRangeIndex lowerExpression state receiver key <|> lowerArrayIndex lowerExpression state spanValue receiver key)
  RangeExpression low inclusive high -> lowerRangeValue lowerExpression state spanValue low inclusive high
  TryExpression operand -> lowerTry lowerExpression state spanValue operand
  AwaitExpression{} -> halt spanValue "await" state
  TupleExpression [] -> value (CoreBlockValue (CoreBlock [] Nothing)) CoreUnitType
  TupleExpression members@(_ : _ : _) -> lowerTuple lowerExpression state spanValue members
  TupleExpression{} -> halt spanValue "tuples" state
  ArrayExpression members -> lowerArrayLiteral lowerExpression state spanValue members
  SetExpression members -> lowerSetLiteral lowerExpression state spanValue members
  UnsafeExpression{} -> halt spanValue "unsafe blocks" state
  MacroCall{} -> halt spanValue "macro calls" state
  ScopeExpression{} -> halt spanValue "scope expressions" state
  LambdaExpression function -> lowerLambda lowerExpression lowerBlock state spanValue function
  TypeApplication{} -> halt spanValue "type applications" state
  RecordExpression (ModuleName segments) fields -> lowerRecord lowerExpression state spanValue (NonEmpty.last segments) fields
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
  ComptimeForExpression{} -> halt spanValue "comptime for" state
  InvalidExpression -> halt spanValue "this expression" state
  where
    typed after shape coreType = (after, Just (CoreExpression spanValue coreType shape, coreType))
    value shape coreType = (state, Just (CoreExpression spanValue coreType shape, coreType))

    -- `Shape.Circle(3)`: the receiver names a type, not a local.
    qualifier (Located _ (NameExpression (owner :| []))) = lookupLocal state owner == Nothing
    qualifier _ = False
    -- With no method of that name, a call reads the field and calls what it holds.
    functionField receiver member = case typeForSpan (contextTypes (lowerContext state)) (locatedSpan receiver) of
      Just kind@(CoreRecordType _ _) | Just (CoreFunctionType _ _) <- recordFields (contextTypes (lowerContext state)) kind >>= lookup member -> True
      _ -> False
