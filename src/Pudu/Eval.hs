{-| @Eval.Module — evaluates a resolved module -}
module Pudu.Eval
  ( EvalOutcome (..)
  , evaluateEntryPoint
  , evaluateModule
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic)
import Pudu.Eval.Env
  ( Eval (..)
  , Evaluator (..)
  , abortAt
  , ascend
  , bind
  , catchUnwind
  , descend
  , emptyEnv
  , expectBool
  , lookupName
  , unwind
  , Unwind (..)
  , update
  , withFrame
  , withNewFrame
  )
import Pudu.Eval.Match (literalValue, matchPattern)
import Pudu.Eval.Operator (applyUnary, combine, readIndex, readMember, unwrapTry)
import Pudu.Eval.Value (Closure (..), Value (..), renderValue, valueKind)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , Function (..)
  , FunctionBody (..)
  , MatchArm (..)
  , Module (..)
  , Parameter (..)
  , Pattern
  , Statement (..)
  , TypeDeclarationValue (..)
  , TypeDefinition (..)
  , Variant (..)
  )
import Pudu.Source (Span)

{-| @Eval.Outcome — a value or the diagnostic that stopped evaluation -}
data EvalOutcome = EvalOutcome
  { outcomeValue :: !(Maybe Value)
  , outcomeDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

{-| Evaluate a module and return the value of its entry point. Module constants
    are evaluated in declaration order, so a constant that reads one declared
    later is a runtime diagnostic rather than a silent default. -}
evaluateEntryPoint :: Text -> Module -> EvalOutcome
evaluateEntryPoint entryName moduleValue =
  run $ do
    loadDeclarations (moduleDeclarations moduleValue)
    found <- lookupName entryName
    case found of
      Just (FunctionValue closure) -> callClosure closure [] Nothing
      _ -> pure UnitValue

evaluateModule :: Module -> EvalOutcome
evaluateModule moduleValue =
  run (loadDeclarations (moduleDeclarations moduleValue) >> pure UnitValue)

{-| A control transfer that reaches the top has left every construct that could
    own it, which the entry point reports as a value of unit rather than losing
    the run. -}
run :: Evaluator Value -> EvalOutcome
run (Evaluator action) = case action emptyEnv of
  Done value _ -> EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound (ReturnUnwind value) _ ->
    EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound _ _ -> EvalOutcome{outcomeValue = Just UnitValue, outcomeDiagnostics = []}
  Aborted stop -> EvalOutcome{outcomeValue = Nothing, outcomeDiagnostics = [stop]}

{-| Functions and variant constructors are installed before any constant runs,
    so mutual recursion and forward references work exactly as resolution
    promised they would. -}
loadDeclarations :: [Located Declaration] -> Evaluator ()
loadDeclarations declarations = do
  mapM_ installDeclaration declarations
  mapM_ initializeDeclaration declarations

installDeclaration :: Located Declaration -> Evaluator ()
installDeclaration (Located _ declaration) = case declaration of
  FunctionDeclaration value ->
    bind (locatedValue (functionName value))
      (FunctionValue (Closure (locatedValue (functionName value)) value))
  TypeDeclaration value ->
    installVariants (locatedValue (typeName value)) (typeDefinition value)
  _ -> pure ()

{-| Each variant is bound unqualified and, together with its siblings, under its
    type's name. A variant with a payload starts life as an empty constructor
    that a call fills in, so `Circle` and `Shape.Circle(3)` reach the same
    value. -}
installVariants :: Text -> Located TypeDefinition -> Evaluator ()
installVariants typeText (Located _ definition) = case definition of
  SumDefinition variants -> do
    let entries = map variantEntry variants
    mapM_ (uncurry bind) entries
    bind typeText (RecordValue typeText entries)
  _ -> pure ()
 where
  variantEntry (Located _ variant) =
    let name = locatedValue (variantName variant)
     in (name, VariantValue name [])

initializeDeclaration :: Located Declaration -> Evaluator ()
initializeDeclaration (Located _ declaration) = case declaration of
  BindingDeclaration _ _ name _ value -> do
    evaluated <- evaluate value
    bind (locatedValue name) evaluated
  _ -> pure ()

callClosure :: Closure -> [Value] -> Maybe Span -> Evaluator Value
callClosure closure arguments callSpan = do
  let value = closureFunction closure
      parameters = functionParameters value
  deeper <- descend callSpan
  bindings <- bindArguments parameters arguments callSpan
  outcome <- withFrame bindings $ catchUnwind $ case functionBody value of
    Nothing -> pure UnitValue
    Just (Located _ body) -> case body of
      BlockBody block -> evaluateBlock block
      ExpressionBody expression -> evaluate expression
  ascend deeper
  case outcome of
    Right result -> pure result
    Left (ReturnUnwind result) -> pure result
    Left _ ->
      abortAt callSpan "E7006" "break or continue outside a loop"
        (Just "use break and continue inside while, loop, or for")

{-| Supplied arguments bind left to right; a parameter with no argument uses its
    default, evaluated in the environment the earlier parameters already
    extended. -}
bindArguments :: [Located Parameter] -> [Value] -> Maybe Span -> Evaluator [(Text, Value)]
bindArguments parameters arguments callSpan = go parameters arguments []
 where
  go [] [] collected = pure (reverse collected)
  go [] (_ : _) collected =
    abortAt callSpan "E7003" "too many arguments in call"
      (Just "pass one argument per declared parameter") >> pure (reverse collected)
  go (Located _ parameter : rest) supplied collected = case supplied of
    value : remaining ->
      go rest remaining ((locatedValue (parameterName parameter), value) : collected)
    [] -> case parameterDefault parameter of
      Just expression -> do
        value <- withFrame (reverse collected) (evaluate expression)
        go rest [] ((locatedValue (parameterName parameter), value) : collected)
      Nothing -> do
        _ <-
          abortAt callSpan "E7003"
            ("missing argument for parameter " <> locatedValue (parameterName parameter))
            (Just "supply the argument or give the parameter a default")
        pure (reverse collected)

{-| A block evaluates its statements in order and yields its trailing
    expression, or unit when it has none. A control transfer inside it travels
    outward untouched. -}
evaluateBlock :: Located Block -> Evaluator Value
evaluateBlock (Located _ block) = withNewFrame $ do
  mapM_ evaluateStatement (blockStatements block)
  case blockResult block of
    Nothing -> pure UnitValue
    Just expression -> evaluate expression

evaluateStatement :: Located Statement -> Evaluator ()
evaluateStatement (Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) -> do
    evaluated <- evaluate value
    bind (locatedValue name) evaluated
  DeclarationStatement _ -> pure ()
  ExpressionStatement expression -> evaluate expression >> pure ()
  ReturnStatement Nothing -> unwind (ReturnUnwind UnitValue)
  ReturnStatement (Just expression) -> do
    value <- evaluate expression
    unwind (ReturnUnwind value)
  BreakStatement -> unwind BreakUnwind
  ContinueStatement -> unwind ContinueUnwind
  InvalidStatement -> pure ()

evaluate :: Located Expression -> Evaluator Value
evaluate (Located spanValue expression) = case expression of
  LiteralExpression literal -> pure (literalValue literal)
  NameExpression names -> readPath spanValue names
  UnaryExpression operator operand -> evaluate operand >>= applyUnary spanValue operator
  BinaryExpression left operator right -> applyBinary spanValue left operator right
  CallExpression callee arguments -> evaluateCall spanValue callee arguments
  MemberExpression target member -> do
    value <- evaluate target
    readMember spanValue value (locatedValue member)
  IndexExpression target index -> do
    container <- evaluate target
    key <- evaluate index
    readIndex spanValue container key
  TryExpression target -> do
    value <- evaluate target
    unwrapTry spanValue value
  AwaitExpression target -> evaluate target
  TupleExpression members -> case members of
    [] -> pure UnitValue
    _ -> TupleValue <$> mapM evaluate members
  BlockExpression block -> evaluateBlock block
  IfExpression condition thenBlock elseBranch -> do
    test <- evaluate condition
    truth <- expectBool spanValue test
    if truth
      then evaluateBlock thenBlock
      else case elseBranch of
        Nothing -> pure UnitValue
        Just branch -> evaluate branch
  MatchExpression scrutinee arms -> do
    subject <- evaluate scrutinee
    evaluateArms spanValue subject arms
  WhileExpression condition body -> evaluateWhile spanValue condition body
  LoopExpression body -> evaluateLoop spanValue body
  ForExpression binder iterated body -> do
    sequence' <- evaluate iterated
    evaluateFor spanValue binder sequence' body
  InvalidExpression -> abortAt (Just spanValue) "E7001" "cannot evaluate invalid syntax" Nothing

readPath :: Span -> NonEmpty Text -> Evaluator Value
readPath spanValue (first :| rest) = do
  found <- lookupName first
  base <- case found of
    Just value -> pure value
    Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> first) Nothing
  foldMember base rest
 where
  foldMember value segments = case segments of
    [] -> pure value
    segment : remaining -> do
      next <- readMember spanValue value segment
      foldMember next remaining

evaluateCall :: Span -> Located Expression -> [Located Expression] -> Evaluator Value
evaluateCall spanValue callee arguments = do
  target <- evaluate callee
  values <- mapM evaluate arguments
  case target of
    FunctionValue closure -> callClosure closure values (Just spanValue)
    VariantValue name [] -> pure (VariantValue name values)
    _ -> abortAt (Just spanValue) "E7001" ("cannot call a " <> valueKind target) Nothing

evaluateArms :: Span -> Value -> [Located MatchArm] -> Evaluator Value
evaluateArms spanValue subject arms = case arms of
  [] ->
    abortAt (Just spanValue) "E7005" ("no match arm accepted " <> renderValue subject)
      (Just "add a case that covers this value")
  Located _ arm : rest -> case matchPattern (armPattern arm) subject of
    Nothing -> evaluateArms spanValue subject rest
    Just bindings -> do
      guarded <- withFrame bindings (evaluateGuard (armGuard arm))
      if guarded
        then withFrame bindings (evaluate (armBody arm))
        else evaluateArms spanValue subject rest

evaluateGuard :: Maybe (Located Expression) -> Evaluator Bool
evaluateGuard guard = case guard of
  Nothing -> pure True
  Just expression -> do
    value <- evaluate expression
    case value of
      BoolValue flag -> pure flag
      _ -> pure False

evaluateWhile :: Span -> Located Expression -> Located Block -> Evaluator Value
evaluateWhile spanValue condition body = loop (0 :: Int)
 where
  loop iterations
    | iterations > iterationLimit =
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "the interactive evaluator bounds iteration; restructure the loop")
    | otherwise = do
        test <- evaluate condition
        truth <- expectBool spanValue test
        if not truth
          then pure UnitValue
          else do
            outcome <- catchUnwind (evaluateBlock body)
            case outcome of
              Left BreakUnwind -> pure UnitValue
              Left ContinueUnwind -> loop (iterations + 1)
              Left transfer -> unwind transfer
              Right _ -> loop (iterations + 1)

evaluateLoop :: Span -> Located Block -> Evaluator Value
evaluateLoop spanValue body = loop (0 :: Int)
 where
  loop iterations
    | iterations > iterationLimit =
        abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "the interactive evaluator bounds iteration; add a break")
    | otherwise = do
        outcome <- catchUnwind (evaluateBlock body)
        case outcome of
          Left BreakUnwind -> pure UnitValue
          Left ContinueUnwind -> loop (iterations + 1)
          Left transfer -> unwind transfer
          Right _ -> loop (iterations + 1)

{-| Iteration is defined over the values the evaluator can enumerate without a
    trait system: tuples and strings. Anything else reports that iteration is
    not yet available for it. -}
evaluateFor :: Span -> Located Pattern -> Value -> Located Block -> Evaluator Value
evaluateFor spanValue binder iterated body = case elements of
  Nothing ->
    abortAt (Just spanValue) "E7001"
      ("cannot iterate a " <> valueKind iterated)
      (Just "iteration over user types arrives with the trait system")
  Just values -> step values
 where
  elements = case iterated of
    TupleValue members -> Just members
    StrValue text -> Just (map CharValue (Text.unpack text))
    VariantValue _ payload -> Just payload
    _ -> Nothing
  step values = case values of
    [] -> pure UnitValue
    value : rest -> case matchPattern binder value of
      Nothing -> step rest
      Just bindings -> do
        outcome <- withFrame bindings (catchUnwind (evaluateBlock body))
        case outcome of
          Left BreakUnwind -> pure UnitValue
          Left ContinueUnwind -> step rest
          Left transfer -> unwind transfer
          Right _ -> step rest

iterationLimit :: Int
iterationLimit = 100000

{-| Assignment writes to an existing binding; `&&` and `||` short-circuit; every
    other operator evaluates both operands left to right. -}
applyBinary :: Span -> Located Expression -> Text -> Located Expression -> Evaluator Value
applyBinary spanValue left operator right = case operator of
  "=" -> do
    value <- evaluate right
    assign spanValue left value
  "&&" -> do
    leftValue <- evaluate left
    truth <- expectBool spanValue leftValue
    if not truth then pure (BoolValue False) else evaluate right >>= expectBoolValue spanValue
  "||" -> do
    leftValue <- evaluate left
    truth <- expectBool spanValue leftValue
    if truth then pure (BoolValue True) else evaluate right >>= expectBoolValue spanValue
  _ -> do
    leftValue <- evaluate left
    rightValue <- evaluate right
    combine spanValue operator leftValue rightValue

expectBoolValue :: Span -> Value -> Evaluator Value
expectBoolValue spanValue value = BoolValue <$> expectBool spanValue value

assign :: Span -> Located Expression -> Value -> Evaluator Value
assign spanValue target value = case locatedValue target of
  NameExpression (name :| []) -> do
    existing <- lookupName name
    case existing of
      Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> name) Nothing
      Just _ -> update name value >> pure UnitValue
  _ -> abortAt (Just spanValue) "E7001" "assignment target is not a place" Nothing
