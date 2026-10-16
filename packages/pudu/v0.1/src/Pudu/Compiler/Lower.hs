{-| @Pudu.Compiler.Lower — the checked root module to [[Core IR]], or a
    typed refusal.

    This is the one gate between the full language and the native subset:
    everything the emitter can represent is lowered exactly, and everything
    else becomes an `E6001` refusal carrying the construct's own span. The
    lowering reads the tree the same way the evaluator's entry evaluation
    does — `main` in the root module, assignment as `name = value`, `print`
    and `display` as unqualified builtin calls — so a program the interpreter
    runs and the native backend accepts mean the same thing by construction.
-}
module Pudu.Compiler.Lower
  ( LowerResult (..)
  , lowerProgram
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)

import Pudu.Core
import Pudu.Diagnostic (Diagnostic, sortDiagnostics)
import Pudu.Diagnostic.Native (nativeRefusal)
import Pudu.Frontend.Syntax
  ( BindingKind (..)
  , Block (..)
  , Declaration (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , Literal (..)
  , Located (..)
  , Module (..)
  , Statement (..)
  , moduleNameText
  )
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

{-| @Compiler.Lower.Result — the lowered module, or every refusal. A refusal
    never coexists with a module: a program lowers or it does not. -}
data LowerResult
  = Lowered !CoreModule
  | LowerRefused ![Diagnostic]
  deriving stock (Eq, Show)

{-| @Compiler.Lower.State — local numbering, the scope stack, and refusals
    collected so far. Lowering keeps going after a refusal so one build
    reports every unsupported construct, not only the first. -}
data LowerState = LowerState
  { lowerNextLocal :: !Int
  , lowerScopes :: ![[(Text, CoreLocal)]]
  , lowerRefusals :: ![Diagnostic]
  }

emptyLowerState :: LowerState
emptyLowerState = LowerState{lowerNextLocal = 0, lowerScopes = [[]], lowerRefusals = []}

refuse :: Span -> Text -> LowerState -> LowerState
refuse spanValue construct state =
  state{lowerRefusals = nativeRefusal spanValue construct : lowerRefusals state}

refused :: LowerState -> (LowerState, Maybe a)
refused state = (state, Nothing)

{-| Refuse one construct and stop lowering this subtree, keeping the refusals
    already collected. -}
halt :: Span -> Text -> LowerState -> (LowerState, Maybe a)
halt spanValue construct state = (refuse spanValue construct state, Nothing)

lookupLocal :: LowerState -> Text -> Maybe CoreLocal
lookupLocal state name =
  case [local | frame <- lowerScopes state, (bound, local) <- frame, bound == name] of
    found : _ -> Just found
    [] -> Nothing

bindLocal :: LowerState -> Text -> CoreType -> (LowerState, CoreLocal)
bindLocal state name coreType =
  let local =
        CoreLocal
          { coreLocalId = lowerNextLocal state
          , coreLocalName = name
          , coreLocalType = coreType
          }
   in ( state
          { lowerNextLocal = lowerNextLocal state + 1
          , lowerScopes = case lowerScopes state of
              frame : rest -> ((name, local) : frame) : rest
              [] -> [[(name, local)]]
          }
      , local
      )

intType :: CoreType
intType = CoreIntegerType PlatformSigned

{-| Lower the root module's entry function. -}
lowerProgram :: Text -> Module -> LowerResult
lowerProgram entryName parsed
  | not (null (moduleImports parsed)) =
      LowerRefused [nativeRefusal (moduleSpan parsed) "imports"]
  | otherwise = case findEntry of
      Left refusal -> LowerRefused [refusal]
      Right function -> settle (lowerFunction function emptyLowerState)
 where
  findEntry = case entryFunctions of
    function : _ -> Right function
    [] -> Left firstDeclarationRefusal
   where
    entryFunctions =
      [ f
      | Located _ (FunctionDeclaration f) <- moduleDeclarations parsed
      , locatedValue (functionName f) == entryName
      ]

  firstDeclarationRefusal = case moduleDeclarations parsed of
    Located _ (FunctionDeclaration other) : _ ->
      nativeRefusal
        (locatedSpan (functionName other))
        ("the function '" <> locatedValue (functionName other) <> "'")
    Located declarationSpan _ : _ -> nativeRefusal declarationSpan "this declaration"
    [] -> nativeRefusal (locatedSpan (moduleName parsed)) "programs without a main function"

  settle (state, coreFunction) = case sortDiagnostics (lowerRefusals state) of
    [] -> case coreFunction of
      Just function ->
        Lowered
          CoreModule
            { coreModuleName = moduleNameText (locatedValue (moduleName parsed))
            , coreModuleFunctions = [function]
            }
      Nothing -> LowerRefused [nativeRefusal (moduleSpan parsed) "this program"]
    refusals -> LowerRefused refusals

{-| Lower the entry function itself: a plain, parameterless, block-bodied
    function named by the caller. The declared return annotation is not
    consulted; the result type is the block's own, exactly as the evaluator
    reads it. -}
lowerFunction :: Function -> LowerState -> (LowerState, Maybe CoreFunction)
lowerFunction function state
  | not (null (functionTypeParams function)) = halt atName "type parameters on main" state
  | functionAsync function = halt atName "async functions" state
  | Just _ <- functionUnsafe function = halt atName "unsafe functions" state
  | functionComptime function = halt atName "comptime functions" state
  | not (null (functionParameters function)) = halt atName "function parameters" state
  | not (null (functionConstraints function)) = halt atName "function constraints" state
  | otherwise = case functionBody function of
      Nothing -> halt atName "a function without a body" state
      Just (Located bodySpan (ExpressionBody _)) ->
        halt bodySpan "an expression-bodied main function" state
      Just (Located bodySpan (BlockBody block)) ->
        let (after, coreBlock, resultType) = lowerBlock state block
         in case resultType of
              CoreIntegerType PlatformSigned -> built after coreBlock resultType
              CoreUnitType -> built after coreBlock resultType
              other ->
                halt
                  (maybe bodySpan locatedSpan (blockResult (locatedValue block)))
                  ("a main function that returns " <> coreTypeName other)
                  after
 where
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

{-| Lower one block: a fresh scope, statements in order, then the trailing
    expression as the result. The scope is popped on exit, so C block scoping
    and Pudu scoping agree. -}
lowerBlock :: LowerState -> Located Block -> (LowerState, CoreBlock, CoreType)
lowerBlock state (Located _ block) =
  (popped, CoreBlock{coreBlockStatements = statements <> resultStatements, coreBlockResult = coreResult}, resultType)
 where
  pushed = state{lowerScopes = [] : lowerScopes state}
  (afterStatements, statements) = foldStatements pushed (blockStatements block)
  (afterResult, resultStatements, coreResult, resultType) = case blockResult block of
    Nothing -> (afterStatements, [], Nothing, CoreUnitType)
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
          | coreType == coreLocalType local ->
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

foldStatements :: LowerState -> [Located Statement] -> (LowerState, [CoreStatement])
foldStatements state located = (finalState, reverse collected)
 where
  (finalState, collected) = foldl step (state, []) located
  step (current, acc) one = case lowerStatement current one of
    (after, Just statement) -> (after, statement : acc)
    (after, Nothing) -> (after, acc)

lowerStatement :: LowerState -> Located Statement -> (LowerState, Maybe CoreStatement)
lowerStatement state (Located statementSpan statement) = case statement of
  DeclarationStatement (Located declarationSpan (BindingDeclaration _ kind (Located nameSpan name) annotation value))
    | kind == CompileTime -> halt nameSpan "comptime bindings" state
    | Just _ <- annotation -> halt declarationSpan "type annotations on bindings" state
    | otherwise -> case lowerExpression state value of
        (after, Just (coreValue, coreType))
          | coreType == intType || coreType == CoreBoolType ->
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
            | coreType == coreLocalType local ->
                ( after
                , Just
                    CoreStatement
                      { coreStatementSpan = statementSpan
                      , coreStatementShape = CoreAssign local coreRight
                      }
                )
            | otherwise -> halt statementSpan "an assignment whose value has a different type" after
          (after, Nothing) -> refused after
    WhileExpression Nothing condition body -> case lowerExpression state condition of
      (afterCondition, Just (coreCondition, CoreBoolType)) ->
        let (afterBody, coreBody, _) = lowerBlock afterCondition body
         in ( afterBody
            , Just
                CoreStatement
                  { coreStatementSpan = statementSpan
                  , coreStatementShape = CoreWhile coreCondition coreBody
                  }
            )
      (afterCondition, Just (_, coreType)) ->
        halt (locatedSpan condition) ("a while condition of type " <> coreTypeName coreType) afterCondition
      (afterCondition, Nothing) -> refused afterCondition
    WhileExpression (Just _) _ _ -> halt statementSpan "labeled loops" state
    IfExpression condition thenBlock elseExpression -> case lowerExpression state condition of
      (afterCondition, Just (coreCondition, CoreBoolType)) ->
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
    ( state
    , Just CoreStatement{coreStatementSpan = statementSpan, coreStatementShape = CoreReturn Nothing}
    )
  ReturnStatement (Just located) -> case lowerExpression state located of
    (after, Just (coreValue, coreType))
      | coreType == intType || coreType == CoreUnitType ->
          ( after
          , Just
              CoreStatement
                { coreStatementSpan = statementSpan
                , coreStatementShape = CoreReturn (Just coreValue)
                }
          )
    (after, Just (_, coreType)) ->
      halt (locatedSpan located) ("returning a " <> coreTypeName coreType <> " value") after
    (after, Nothing) -> refused after
  BreakStatement{} -> halt statementSpan "break" state
  ContinueStatement{} -> halt statementSpan "continue" state
  LetElseStatement{} -> halt statementSpan "let else" state
  LetPatternStatement{} -> halt statementSpan "pattern bindings" state
  InvalidStatement -> halt statementSpan "this statement" state

lowerExpression :: LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
lowerExpression state (Located spanValue expression) = case expression of
  LiteralExpression literal -> case literal of
    ResolvedInteger PlatformSigned number ->
      value (CoreIntegerLiteral PlatformSigned number) intType
    ResolvedInteger kind _ ->
      halt spanValue ("the " <> coreTypeName (CoreIntegerType kind) <> " type") state
    IntegerValue _ -> halt spanValue "an unresolved integer literal" state
    BoolValue flag -> value (CoreBoolLiteral flag) CoreBoolType
    StringValue text -> value (CoreTextLiteral text) CoreTextType
    CharValue _ -> halt spanValue "character literals" state
    FloatValue _ -> halt spanValue "floating-point values" state
    DecimalValue _ -> halt spanValue "decimal values" state
    NullValue -> halt spanValue "null" state
  NameExpression (name :| []) -> case lookupLocal state name of
    Just local -> value (CoreReadLocal local) (coreLocalType local)
    Nothing -> halt spanValue ("the value '" <> name <> "'") state
  NameExpression _ -> halt spanValue "module-qualified names" state
  UnaryExpression "-" operand -> case lowerExpression state operand of
    (after, Just (coreOperand, operandType))
      | operandType == intType -> typed after (CoreNegate coreOperand) intType
      | otherwise -> halt spanValue ("negation of a " <> coreTypeName operandType <> " value") after
    (after, Nothing) -> refused after
  UnaryExpression "!" operand -> case lowerExpression state operand of
    (after, Just (coreOperand, CoreBoolType)) -> typed after (CoreNot coreOperand) CoreBoolType
    (after, Just (_, operandType)) ->
      halt spanValue ("negation of a " <> coreTypeName operandType <> " value") after
    (after, Nothing) -> refused after
  UnaryExpression operator _ ->
    halt spanValue ("the operator '" <> operator <> "'") state
  BinaryExpression left operator right -> lowerBinary spanValue left operator right
  CallExpression (Located _ (NameExpression (name :| []))) arguments
    | name == "print" -> case arguments of
        [argument] -> case lowerExpression state argument of
          (after, Just (coreArgument, CoreTextType))
            | printableArgument coreArgument ->
                typed after (CorePrint coreArgument) CoreUnitType
            | otherwise ->
                halt spanValue "a print argument other than a text literal or a display" after
          (after, Just (_, coreType)) ->
            halt spanValue ("printing a " <> coreTypeName coreType <> " value") after
          (after, Nothing) -> refused after
        _ -> halt spanValue "a call to print with this many arguments" state
    | name == "display" -> case arguments of
        [argument] -> case lowerExpression state argument of
          (after, Just (coreArgument, operandType))
            | operandType == intType || operandType == CoreBoolType ->
                typed after (CoreDisplay coreArgument) CoreTextType
            | otherwise ->
                halt spanValue ("display of a " <> coreTypeName operandType <> " value") after
          (after, Nothing) -> refused after
        _ -> halt spanValue "a call to display with this many arguments" state
    | otherwise -> halt spanValue ("calls to '" <> name <> "'") state
  CallExpression (Located _ MemberExpression{}) _ -> halt spanValue "method calls" state
  CallExpression{} -> halt spanValue "this call" state
  MemberExpression{} -> halt spanValue "member access" state
  IndexExpression{} -> halt spanValue "indexing" state
  RangeExpression{} -> halt spanValue "ranges" state
  TryExpression{} -> halt spanValue "the try operator" state
  AwaitExpression{} -> halt spanValue "await" state
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
     in typed after (CoreBlockValue coreBlock) resultType
  IfExpression condition thenBlock (Just elseExpression) ->
    case lowerExpression state condition of
      (afterCondition, Just (coreCondition, CoreBoolType)) ->
        let (afterThen, coreThen, thenType) = lowerBlock afterCondition thenBlock
         in case lowerExpression afterThen elseExpression of
              (afterElse, Just (coreElse, elseType))
                | elseType == thenType ->
                    typed afterElse (CoreIfValue coreCondition coreThen coreElse) thenType
                | otherwise ->
                    halt (locatedSpan elseExpression) "an if whose branches have different types" afterElse
              (afterElse, Nothing) -> refused afterElse
      (afterCondition, Just (_, conditionType)) ->
        halt (locatedSpan condition) ("an if condition of type " <> coreTypeName conditionType) afterCondition
      (afterCondition, Nothing) -> refused afterCondition
  IfExpression _ _ Nothing -> halt spanValue "an if without else used as a value" state
  WhileExpression{} -> halt spanValue "a while loop used as a value" state
  MatchExpression{} -> halt spanValue "match expressions" state
  WhileLetExpression{} -> halt spanValue "while let" state
  IfLetExpression{} -> halt spanValue "if let" state
  LoopExpression{} -> halt spanValue "loop" state
  ForExpression{} -> halt spanValue "for loops" state
  ComptimeForExpression{} -> halt spanValue "comptime for" state
  InvalidExpression -> halt spanValue "this expression" state
 where
  typed after shape coreType = (after, Just (CoreExpression spanValue coreType shape, coreType))
  value shape coreType = (state, Just (CoreExpression spanValue coreType shape, coreType))

  lowerBinary binarySpan left operator right = case operator of
    "+" -> arithmetic CoreAdd
    "-" -> arithmetic CoreSubtract
    "*" -> arithmetic CoreMultiply
    "/" -> arithmetic CoreDivide
    "%" -> arithmetic CoreRemainder
    "<" -> comparison CoreLess
    "<=" -> comparison CoreLessOrEqual
    ">" -> comparison CoreGreater
    ">=" -> comparison CoreGreaterOrEqual
    "==" -> equality CoreEqual
    "!=" -> equality CoreNotEqual
    "&&" -> logical CoreAnd
    "||" -> logical CoreOr
    "=" -> halt binarySpan "an assignment used as a value" state
    _ -> halt binarySpan ("the operator '" <> operator <> "'") state
   where
    arithmetic coreOperator = case intPair of
      Right (after, coreLeft, coreRight) ->
        typed after (CoreBinary coreOperator coreLeft coreRight) intType
      Left after -> refused after
    comparison coreOperator = case intPair of
      Right (after, coreLeft, coreRight) ->
        typed after (CoreBinary coreOperator coreLeft coreRight) CoreBoolType
      Left after -> refused after
    equality coreOperator = case equalityPair of
      Right (after, coreLeft, coreRight) ->
        typed after (CoreBinary coreOperator coreLeft coreRight) CoreBoolType
      Left after -> refused after
    logical coreOperator = case boolPair of
      Right (after, coreLeft, coreRight) ->
        typed after (CoreBinary coreOperator coreLeft coreRight) CoreBoolType
      Left after -> refused after

    intPair = case lowerExpression state left of
      (afterLeft, Just (coreLeft, leftType))
        | leftType == intType -> case lowerExpression afterLeft right of
            (afterRight, Just (coreRight, rightType))
              | rightType == intType -> Right (afterRight, coreLeft, coreRight)
              | otherwise ->
                  Left (refuse (locatedSpan right) ("an operation on a " <> coreTypeName rightType <> " value") afterRight)
            (afterRight, Nothing) -> Left afterRight
      (afterLeft, Just (_, leftType)) ->
        Left (refuse (locatedSpan left) ("an operation on a " <> coreTypeName leftType <> " value") afterLeft)
      (afterLeft, Nothing) -> Left afterLeft

    boolPair = case lowerExpression state left of
      (afterLeft, Just (coreLeft, CoreBoolType)) -> case lowerExpression afterLeft right of
        (afterRight, Just (coreRight, CoreBoolType)) -> Right (afterRight, coreLeft, coreRight)
        (afterRight, Just (_, rightType)) ->
          Left (refuse (locatedSpan right) ("an operation on a " <> coreTypeName rightType <> " value") afterRight)
        (afterRight, Nothing) -> Left afterRight
      (afterLeft, Just (_, leftType)) ->
        Left (refuse (locatedSpan left) ("an operation on a " <> coreTypeName leftType <> " value") afterLeft)
      (afterLeft, Nothing) -> Left afterLeft

    equalityPair = case lowerExpression state left of
      (afterLeft, Just (coreLeft, leftType)) -> case lowerExpression afterLeft right of
        (afterRight, Just (coreRight, rightType))
          | rightType == leftType && leftType `elem` [intType, CoreBoolType] ->
              Right (afterRight, coreLeft, coreRight)
          | otherwise ->
              Left (refuse (locatedSpan right) ("an operation on a " <> coreTypeName rightType <> " value") afterRight)
        (afterRight, Nothing) -> Left afterRight
      (afterLeft, Nothing) -> Left afterLeft

{-| A print argument the emitter can fuse: the argument is always `Str`
    because the checker gives `print` the type `Str -> Unit`, so only a text
    literal or a `display` of a supported value can stand there. -}
printableArgument :: CoreExpression -> Bool
printableArgument (CoreExpression _ _ shape) = case shape of
  CoreTextLiteral _ -> True
  CoreDisplay _ -> True
  _ -> False
