{-| @Pudu.Compiler.Lower.Body — lower function bodies through lexical blocks,
    statements and expressions. State and signature admission have independent
    owners; mutual block/expression recursion stays within this traversal. -}
module Pudu.Compiler.Lower.Body (lowerEntryBody, lowerFunctionBody) where

import Data.List.NonEmpty (NonEmpty (..))
import Pudu.Compiler.Lower.Scalar (lowerUnary, lowerBinary, eagerType)
import Pudu.Compiler.Lower.Types (typeForSpan, nativeIntegerKind, nativeValueType)
import Pudu.Compiler.Lower.Control
  ( lowerWhile, lowerLoop, lowerTransfer, blockType, joinType
  , printValued, expressionIsPrintValued )
import Pudu.Compiler.Lower.State
  ( CoreSignature (..), LowerContext (..), LowerState (..)
  , bindLocal, halt, lookupLocal, refuse, refused )
import Pudu.Compiler.Lower.Signature (ensureSignature, functionLevelRefusal)
import Pudu.Compiler.Lower.Text (lowerTextMethod)
import Pudu.Core
import Pudu.Frontend.Syntax
  ( BindingKind (..), Block (..), Declaration (..), Expression (..)
  , Function (..), FunctionBody (..), Literal (..), Located (..), Statement (..) )
import GHC.Float (castDoubleToWord64)
import Pudu.FloatLiteral (ParsedFloat (..), parseFloatLiteral)
import Pudu.IntegerLiteral (integerKindFits)

{-| The entry carries an admitted integer, Bool, float, Str or unit; a body that never
    returns uses the unit ABI. Integers become the exit status and every other value is
    printed as `renderValue` writes it, the same split `pudu run` makes. Print's Result carrier must not escape through the
    entry result. -}
lowerEntryBody :: Located Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerEntryBody located state
  | not (null (functionParameters function)) =
      halt atName "parameters on the entry function" state
  | otherwise = case functionLevelRefusal function of
      Just (spanValue, construct) -> halt spanValue construct state
      Nothing -> case functionBody function of
        Just (Located _ (BlockBody block)) ->
          let (after, coreBlock, resultType) = lowerBlock state block
           in case maybe resultType id (lowerFunctionResult after) of
                kind@(CoreIntegerType integerKind) | nativeIntegerKind integerKind -> built after coreBlock kind
                kind@(CoreFloatType _) -> built after coreBlock kind
                CoreBoolType -> built after coreBlock CoreBoolType
                CoreTextType -> built after coreBlock CoreTextType
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
lowerFunctionBody located signature state = case functionBody function of
  Just (Located _ (BlockBody block)) ->
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
  BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
    | Just local <- lookupLocal state name -> case lowerExpression state right of
        (after, Just (coreRight, coreType))
          | expressionIsPrintValued coreRight ->
              (refuse expressionSpan "assigning a Result[(), Str] value" after, [], Nothing, CoreUnitType)
          | coreType == coreLocalType local || coreType == CoreNeverType ->
              ( after
              , [CoreStatement{coreStatementSpan = expressionSpan, coreStatementShape = CoreAssign local coreRight}]
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
    (after, Nothing) -> (after, [], Nothing, CoreUnitType)

foldStatements :: LowerState -> [Located Statement] -> (LowerState, [CoreStatement], Bool)
foldStatements state = go state []
  where
    go current collected [] = (current, reverse collected, False)
    go current collected (one : rest) = case lowerStatement current one of
      (after, Just statement) -> go after (statement : collected) rest
      (after, Nothing) -> (after, reverse collected, True)

lowerStatement :: LowerState -> Located Statement -> (LowerState, Maybe CoreStatement)
lowerStatement state (Located statementSpan statement) = case statement of
  DeclarationStatement (Located declarationSpan (BindingDeclaration _ kind (Located nameSpan name) annotation value))
    | kind == CompileTime -> halt nameSpan "comptime bindings" state
    | otherwise -> case lowerExpression state value of
        (after, Just (coreValue, coreType))
          | expressionIsPrintValued coreValue -> halt declarationSpan "binding a Result[(), Str] value" after
          | Just _ <- annotation
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
    BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
      | Just local <- lookupLocal state name -> case lowerExpression state right of
          (after, Just (coreRight, coreType))
            | expressionIsPrintValued coreRight -> halt statementSpan "assigning a Result[(), Str] value" after
            | coreType == coreLocalType local || coreType == CoreNeverType ->
                ( after
                , Just
                    CoreStatement
                      { coreStatementSpan = statementSpan
                      , coreStatementShape = CoreAssign local coreRight
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
  LetElseStatement{} -> halt statementSpan "let else" state
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
    _ -> operand `elem` [CoreBoolType, CoreTextType, CoreUnitType, CoreNeverType]

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
    CharValue _ -> halt spanValue "character literals" state
    FloatValue text -> case parseFloatLiteral text of
      Just ParsedFloat{parsedFloatValue, parsedFloatWidth, parsedFloatFits = True} ->
        value (CoreFloatLiteral parsedFloatWidth (castDoubleToWord64 parsedFloatValue)) (CoreFloatType parsedFloatWidth)
      _ -> halt spanValue "a floating literal outside its width" state
    DecimalValue _ -> halt spanValue "decimal values" state
    NullValue -> halt spanValue "null" state
  NameExpression (name :| []) -> case lookupLocal state name of
    Just local -> value (CoreReadLocal local) (coreLocalType local)
    Nothing -> halt spanValue ("the value '" <> name <> "'") state
  NameExpression _ -> halt spanValue "module-qualified names" state
  UnaryExpression operator operand -> lowerUnary lowerExpression state spanValue operator operand
  BinaryExpression left operator right -> lowerBinary lowerExpression state spanValue left operator right
  CallExpression (Located _ (NameExpression (name :| []))) arguments
    | Just _ <- lookupLocal state name -> halt spanValue "a call through a local value" state
    | name == contextEntry (lowerContext state) -> halt spanValue "a call to the entry function" state
    | Just target <- lookup name (contextTable (lowerContext state)) -> case ensureSignature target state of
        (after, Nothing) -> refused after
        (after, Just signature) -> case lowerArguments after [] arguments of
          (final, Just coreArguments)
            | any ((== CoreNeverType) . coreExpressionType) coreArguments ->
                typed final (CoreBlockValue (CoreBlock
                  [CoreStatement (coreExpressionSpan argument) (CoreEvaluate argument) | argument <- coreArguments] Nothing)) CoreNeverType
            | otherwise -> typed (recordCall name final) (CoreCall name coreArguments) (eagerType (signatureResult signature) coreArguments)
          (final, Nothing) -> refused final
    | name == "print" -> case arguments of
        [argument] -> case lowerExpression state argument of
          (after, Just (coreArgument, CoreNeverType)) -> (after, Just (coreArgument, CoreNeverType))
          (after, Just (coreArgument, CoreTextType)) -> typed after (CorePrint coreArgument) CoreUnitType
          (after, Just (_, coreType)) ->
            halt spanValue ("printing a " <> coreTypeName coreType <> " value") after
          (after, Nothing) -> refused after
        _ -> halt spanValue "a call to print with this many arguments" state
    | name == "display" -> rendered CoreDisplay
    | name == "show" -> rendered CoreShow
    | otherwise -> halt spanValue ("calls to '" <> name <> "'") state
  CallExpression (Located _ (MemberExpression receiver (Located _ member))) arguments ->
    lowerTextMethod lowerExpression state spanValue receiver member arguments
  CallExpression{} -> halt spanValue "this call" state
  MemberExpression{} -> halt spanValue "member access" state
  IndexExpression{} -> halt spanValue "indexing" state
  RangeExpression{} -> halt spanValue "ranges" state
  TryExpression{} -> halt spanValue "the try operator" state
  AwaitExpression{} -> halt spanValue "await" state
  TupleExpression [] -> value (CoreBlockValue (CoreBlock [] Nothing)) CoreUnitType
  TupleExpression{} -> halt spanValue "tuples" state
  ArrayExpression{} -> halt spanValue "arrays" state
  SetExpression{} -> halt spanValue "sets" state
  UnsafeExpression{} -> halt spanValue "unsafe blocks" state
  MacroCall{} -> halt spanValue "macro calls" state
  ScopeExpression{} -> halt spanValue "scope expressions" state
  LambdaExpression{} -> halt spanValue "lambdas" state
  TypeApplication{} -> halt spanValue "type applications" state
  RecordExpression{} -> halt spanValue "records" state
  RecordUpdateExpression{} -> halt spanValue "record updates" state
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
  MatchExpression{} -> halt spanValue "match expressions" state
  WhileLetExpression{} -> halt spanValue "while let" state
  IfLetExpression{} -> halt spanValue "if let" state
  LoopExpression label body -> lowerLoop lowerBlock spanValue label body state
  ForExpression{} -> halt spanValue "for loops" state
  ComptimeForExpression{} -> halt spanValue "comptime for" state
  InvalidExpression -> halt spanValue "this expression" state
  where
    rendered shape = case expression of
      CallExpression (Located _ (NameExpression (name :| []))) [argument] -> case lowerExpression state argument of
        (after, Just (coreArgument, CoreNeverType)) -> (after, Just (coreArgument, CoreNeverType))
        (after, Just (coreArgument, _))
          | expressionIsPrintValued coreArgument -> halt spanValue (name <> " of a Result[(), Str] value") after
        (after, Just (coreArgument, operandType))
          | nativeValueType operandType -> typed after (shape coreArgument) CoreTextType
          | otherwise -> halt spanValue (name <> " of a " <> coreTypeName operandType <> " value") after
        (after, Nothing) -> refused after
      CallExpression (Located _ (NameExpression (name :| []))) _ ->
        halt spanValue ("a call to " <> name <> " with this many arguments") state
      _ -> halt spanValue "this call" state
    typed after shape coreType = (after, Just (CoreExpression spanValue coreType shape, coreType))
    value shape coreType = (state, Just (CoreExpression spanValue coreType shape, coreType))

    lowerArguments current collected arguments = case arguments of
      [] -> (current, Just (reverse collected))
      argument : rest -> case lowerExpression current argument of
        (after, Just (core, _))
          | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
          | otherwise -> lowerArguments after (core : collected) rest
        (after, Nothing) -> (after, Nothing)

    recordCall name current =
      current
        { lowerContext =
            context{contextQueue = name : contextQueue context}
        }
      where
        context = lowerContext current
