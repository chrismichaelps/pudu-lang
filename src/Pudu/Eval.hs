{-| @Eval.Module — evaluates a resolved module -}
{-| The evaluator's core. What a caller reaches to run a program is
    [[Eval Program]], which depends on this rather than the other way round. -}
module Pudu.Eval
  ( EvalOutcome (..)
  , awaitTask
  , callClosure
  , evaluate
  , runCounted
  , runWithEffects
  , scopeTo
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Data.Text (Text)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Eval.Env
  ( Env (..)
  , integerKindAt
  , tally
  , captureEnvironment
  , Eval (..)
  , Evaluator (..)
  , abortAt
  , bind
  , emptyEnv
  , expectBool
  , lookupName
  , unwind
  , Unwind (..)
  , update
  , withFrame
  , withNewFrame
  )
import Pudu.Eval.Loop
  ( LoopNeeds (..)
  , evaluateFor
  , evaluateLoop
  , evaluateWhile
  , evaluateWhileLet
  )
import Pudu.Eval.Call
  ( CallNeeds (..)
  , evaluateCall
  , evaluateScope
  , lastPathSegment
  , pathValue
  , readPath
  )
import qualified Pudu.Eval.Call as Call
import Pudu.Eval.Match (integerLiteralValue, literalValue, matchPattern)
import Pudu.Eval.Operator (applyUnary, combine, readIndex, readMember, unwrapTry)
import Pudu.Eval.Value
  ( Closure (..)
  , Value (..)
  , renderValue
  )
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Literal (IntegerValue)
  , Block (..)
  , lambdaName
  , FieldInit (..)
  , Declaration (..)
  , Expression (..)
  , MatchArm (..)
  , Statement (..)
  )
import Data.IORef (IORef)
import Pudu.Source (Span)

{-| @Eval.Outcome — a value or the diagnostic that stopped evaluation -}
data EvalOutcome = EvalOutcome
  { outcomeValue :: !(Maybe Value)
  , outcomeDiagnostics :: ![Diagnostic]
  }
  deriving stock (Eq, Show)

runCounted :: Maybe (IORef (Map.Map Text Int)) -> Evaluator Value -> IO EvalOutcome
runCounted counters (Evaluator action) = do
  outcome <- action emptyEnv{envEffects = True, envTally = counters}
  pure (outcomeOf outcome)

{-| Run an evaluation, choosing whether the program may reach the world.

    Compile-time folding passes `False`: a constant is evaluated while the
    compiler runs, and letting it read a file or print would make compilation
    depend on the world the compiler happened to be in, and would produce output
    nobody asked for. -}
runWithEffects :: Bool -> Evaluator Value -> IO EvalOutcome
runWithEffects effects (Evaluator action) = do
  outcome <- action emptyEnv{envEffects = effects}
  pure (outcomeOf outcome)

{-| What a finished evaluation answers with. A control transfer that reached the
    top is the value it carried; only an abort has nothing to answer. -}
outcomeOf :: Eval Value -> EvalOutcome
outcomeOf outcome = case outcome of
  Done value _ -> EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound (ReturnUnwind value) _ ->
    EvalOutcome{outcomeValue = Just value, outcomeDiagnostics = []}
  Unwound _ _ -> EvalOutcome{outcomeValue = Just UnitValue, outcomeDiagnostics = []}
  Aborted stop -> EvalOutcome{outcomeValue = Nothing, outcomeDiagnostics = [stop]}

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
  BreakStatement label value -> do
    carried <- maybe (pure UnitValue) evaluate value
    unwind (BreakUnwind (fmap locatedValue label) carried)
  ContinueStatement label -> unwind (ContinueUnwind (fmap locatedValue label))
  {-| The bindings enter the frame already open rather than a new one, which is
      what makes them visible to every statement after this. The fallback needs
      no forcing: typing has already established that it cannot reach them. -}
  LetElseStatement pattern' subject fallback -> do
    value <- evaluate subject
    case matchPattern pattern' value of
      Just bindings -> mapM_ (uncurry bind) bindings
      Nothing -> evaluateBlock fallback >> pure ()
  InvalidStatement -> pure ()

{-| Evaluation is not counted per expression.

    A tally on every node of every program costs more than it reports: measured
    on a quarter-megabyte parse, a bind there took the run from 0.93s to 1.50s,
    and writing it against the environment directly still left it at 1.30s.
    `evaluate` is the hottest function in the evaluator and nothing belongs in
    it that the program did not ask for.

    What is counted is counted where the evaluator already stops: a name lookup,
    which every way of reaching a name goes through, and the constructs that
    already open a block to do their work. Those are the costs worth knowing and
    they are free to take. -}
{-| What a loop needs of the evaluator, tied once here. -}
{-| What a call needs of the evaluator, tied once here. -}
{-| Calling, awaiting, and scoping with the record already supplied, so a
    caller that only wants to run something does not have to know there is one.
    [[Eval Program]] and the loop forms reach these. -}
callClosure :: Closure -> [Value] -> Maybe Span -> Evaluator Value
callClosure = Call.callClosure callNeeds

awaitTask :: Span -> Value -> Evaluator Value
awaitTask = Call.awaitTask callNeeds

scopeTo :: [Map Text Value] -> Value -> Value
scopeTo = Call.scopeTo

callNeeds :: CallNeeds
callNeeds = CallNeeds{callEvaluate = evaluate, callBlock = evaluateBlock}

loopNeeds :: LoopNeeds
loopNeeds =
  LoopNeeds
    { loopEvaluate = evaluate
    , loopBlock = evaluateBlock
    , loopClosure = callClosure
    }

evaluate :: Located Expression -> Evaluator Value
evaluate = evaluateHere

evaluateHere :: Located Expression -> Evaluator Value
evaluateHere (Located spanValue expression) = case expression of
  {-| A literal is built as the type inference gave it, not as it was spelled.
      A suffix says the kind outright; without one the checker's answer for this
      span is the kind, and only where it has none is the platform integer the
      right default. -}
  LiteralExpression literal -> case literal of
    IntegerValue _ -> do
      selected <- integerKindAt spanValue
      pure (integerLiteralValue selected literal)
    _ -> pure (literalValue literal)
  NameExpression names -> readPath spanValue names
  UnaryExpression operator operand -> evaluate operand >>= applyUnary spanValue operator
  BinaryExpression left operator right -> applyBinary spanValue left operator right
  CallExpression callee arguments -> evaluateCall callNeeds spanValue callee arguments
  MemberExpression target member -> do
    tally "member"
    {-| A member access on a linked module is a name, not a read: `Std.Char.toUpper`
        is one binding, while `record.field.inner` is two reads. Trying the whole
        chain as a path first is what lets a module's function be passed as a
        value, which is how `mapChars(text, Char.toUpper)` works at all. -}
    linked <- pathValue expression
    case linked of
      Just value -> pure value
      Nothing -> do
        value <- evaluate target
        readMember spanValue value (locatedValue member)
  IndexExpression target index -> do
    tally "index"
    container <- evaluate target
    key <- evaluate index
    readIndex spanValue container key
  TryExpression target -> do
    value <- evaluate target
    unwrapTry spanValue value
  AwaitExpression target -> evaluate target >>= awaitTask spanValue
  TupleExpression members -> case members of
    [] -> pure UnitValue
    _ -> TupleValue <$> mapM evaluate members
  ArrayExpression members -> ArrayValue . Seq.fromList <$> mapM evaluate members
  UnsafeExpression _ body -> evaluateBlock body
  MacroCall _ _ ->
    abortAt (Just spanValue) "E7001" "macro call reached evaluation unexpanded" Nothing
  {-| Types are erased at run time, so a type application evaluates to what it
      was applied to. It exists to tell the checker which instantiation was
      meant, and the checker has already been told by the time this runs. -}
  TypeApplication target _ -> evaluate target
  LambdaExpression value -> do
    {-| A literal captures the environment it was written in, so calling it
        later means what it meant then. A declaration does not, and the two
        cases are distinguished by this field rather than by asking what kind
        of function it is. -}
    captured <- captureEnvironment
    pure (FunctionValue (Closure lambdaName value Nothing (Just captured)))
  ScopeExpression body -> evaluateScope callNeeds spanValue body
  RecordExpression path fields -> do
    values <- mapM (evaluateFieldInit spanValue) fields
    pure (RecordValue (lastPathSegment path) values)
  BlockExpression block -> evaluateBlock block
  IfExpression condition thenBlock elseBranch -> do
    test <- evaluate condition
    truth <- expectBool spanValue test
    if truth
      then evaluateBlock thenBlock
      else case elseBranch of
        Nothing -> pure UnitValue
        Just branch -> evaluate branch
  IfLetExpression pattern' subject thenBlock elseBranch -> do
    value <- evaluate subject
    case matchPattern pattern' value of
      Just bindings -> withFrame bindings $ case elseBranch of
        Nothing -> evaluateBlock thenBlock >> pure UnitValue
        Just _ -> evaluateBlock thenBlock
      Nothing -> case elseBranch of
        Nothing -> pure UnitValue
        Just branch -> evaluate branch
  MatchExpression scrutinee arms -> do
    subject <- evaluate scrutinee
    evaluateArms spanValue subject arms
  WhileExpression label condition body ->
    evaluateWhile loopNeeds spanValue (fmap locatedValue label) condition body
  WhileLetExpression label pattern' subject body ->
    evaluateWhileLet loopNeeds spanValue (fmap locatedValue label) pattern' subject body
  LoopExpression label body -> evaluateLoop loopNeeds spanValue (fmap locatedValue label) body
  ForExpression label binder iterated body -> do
    sequence' <- evaluate iterated
    evaluateFor loopNeeds spanValue (fmap locatedValue label) binder sequence' body
  InvalidExpression -> abortAt (Just spanValue) "E7001" "cannot evaluate invalid syntax" Nothing

evaluateFieldInit :: Span -> Located FieldInit -> Evaluator (Text, Value)
evaluateFieldInit recordSpan (Located _ field) = do
  let name = locatedValue (fieldInitName field)
  value <- case fieldInitValue field of
    Just expression -> evaluate expression
    Nothing -> do
      found <- lookupName name
      case found of
        Just existing -> pure existing
        Nothing -> abortAt (Just recordSpan) "E7001" ("undefined name " <> name) Nothing
  pure (name, value)

evaluateArms :: Span -> Value -> [Located MatchArm] -> Evaluator Value
evaluateArms spanValue subject arms = case arms of
  [] ->
    abortAt (Just spanValue) "E7011" ("no match arm accepted " <> renderValue subject)
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
