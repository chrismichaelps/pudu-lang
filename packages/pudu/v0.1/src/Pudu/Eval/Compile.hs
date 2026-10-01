{-| @Pudu.Eval.Compile.Module — function bodies turned into closures once -}
module Pudu.Eval.Compile
  ( Walker (..)
  , Code
  , compileBody
  , blockIntroducesBindings
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.IntMap.Strict as IntMap
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Sequence as Seq
import Pudu.Eval.Env
  ( Evaluator
  , Unwind (..)
  , abortAt
  , bind
  , expectBool
  , integerKindAt
  , lookupLocal
  , lookupModule
  , lookupName
  , enterSlots
  , readSlot
  , writeSlot
  , tally
  , unwind
  , withFrame
  , withNewFrame
  )
import Pudu.Eval.Call (CallNeeds (..), callClosure, evaluateCall)
import Pudu.Eval.Call.Path (flattenPath, lastPathSegment, pathValue)
import Pudu.Eval.Compile.Layout (slotLayout)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Loop (LoopNeeds (..), evaluateFor, evaluateWhile)
import Pudu.Eval.Match (integerLiteralValue, literalValue, matchPattern)
import Pudu.Eval.MultiMap (multiMapWrapper)
import Pudu.Eval.Operator (applyUnary, checkedResult, combine, readIndex, readMember)
import Pudu.IntegerLiteral (integerKindMeet)
import Pudu.Eval.Place (exclusiveParameters, plainPlace, storePlace)
import Pudu.Eval.Value (Closure (..), Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..)
  , Declaration (..)
  , Expression (..)
  , FieldInit (..)
  , FunctionBody (..)
  , Literal (IntegerValue, ResolvedInteger)
  , MatchArm (..)
  , Pattern
  , Statement (..)
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Source (Span, spanStart, unOffset)

{-| A body ready to run: every decision the tree walker makes about its syntax
    has been made, and running it only does the work. -}
type Code = Evaluator Value

{-| The tree walker, for every construct the compiler leaves to it.

    Passed in rather than imported, because the walker is the module that
    starts calls, and calls are where compiled bodies are used. -}
data Walker = Walker
  { walkExpression :: Located Expression -> Evaluator Value
  , walkStatement :: Located Statement -> Evaluator ()
  , walkLoopNeeds :: LoopNeeds
  , walkCallNeeds :: CallNeeds
  {-| The positions of the body being compiled, when it runs on slots. -}
  , walkSlots :: Maybe (Map Text Int)
  }

{-| Compile a function body, on slots when every name it binds is distinct. -}
compileBody :: Walker -> [Text] -> FunctionBody -> Evaluator Code
compileBody walker parameters body = case slotLayout parameters body of
  Just layout -> enterSlots layout <$> compileWith walker{walkSlots = Just layout}
  Nothing -> compileWith walker{walkSlots = Nothing}
 where
  compileWith scoped = case body of
    BlockBody block -> compileBlock scoped block
    ExpressionBody expression -> compileExpression scoped expression

{-| The slot a name has in the body being compiled. -}
slotOf :: Walker -> Text -> Maybe Int
slotOf walker name = walkSlots walker >>= Map.lookup name

compileExpression :: Walker -> Located Expression -> Evaluator Code
compileExpression walker located@(Located spanValue expression) = case expression of
  -- A literal's kind is the checker's answer for its span, read once here
  -- rather than each time the literal is reached.
  LiteralExpression literal -> case literal of
    IntegerValue _ -> do
      selected <- integerKindAt spanValue
      let value = integerLiteralValue selected literal
      pure (pure value)
    ResolvedInteger kind number -> let value = IntValue kind number in pure (pure value)
    _ -> let value = literalValue literal in pure (pure value)
  -- A local of a body on slots is read by position; a path that starts at one
  -- is that local's fields, read in turn.
  NameExpression (first :| rest)
    | Just position <- slotOf walker first ->
        pure (foldl (\base field -> base >>= \value -> readMember spanValue value field) (readSlot position) rest)
  NameExpression (first :| rest) -> do
    -- A function bound in module scope does not change once the program is
    -- linked, so it is found once here. A local of the same first name, bound
    -- later by the body, still wins, which is what lexical scope says.
    let written = Text.intercalate "." (first : rest)
    global <- lookupModule written
    case global of
      Just function@(FunctionValue _) -> pure $ do
        local <- lookupLocal first
        case local of
          Nothing -> pure function
          Just _ -> walkExpression walker located
      _ -> case rest of
        [] -> pure $ do
          found <- lookupName first
          case found of
            Just value -> pure value
            Nothing -> abortAt (Just spanValue) "E7001" ("undefined name " <> first) Nothing
        _ -> pure (walkExpression walker located)
  UnaryExpression operator operand -> do
    inner <- compileExpression walker operand
    pure (inner >>= applyUnary spanValue operator)
  BinaryExpression left operator right -> compileBinary walker located left operator right
  BlockExpression block -> compileBlock walker block
  IfExpression condition thenBlock elseBranch -> do
    test <- compileExpression walker condition
    taken <- compileBlock walker thenBlock
    otherwise' <- traverse (compileExpression walker) elseBranch
    pure $ do
      truth <- test >>= expectBool spanValue
      if truth then taken else maybe (pure UnitValue) id otherwise'
  -- The loop itself is the tree walker's, so its step limit and its handling of
  -- `break` and `continue` are written once; only the condition and the body
  -- it runs are compiled.
  WhileExpression label condition body -> do
    test <- compileExpression walker condition
    turn <- compileBlock walker body
    let needs = (walkLoopNeeds walker){loopEvaluate = const test, loopBlock = const turn}
    pure (evaluateWhile needs spanValue (fmap locatedValue label) condition body)
  MemberExpression target member
    | Just (first : _) <- flattenPath expression
    , Just _ <- slotOf walker first -> do
        inner <- compileExpression walker target
        pure (inner >>= \value -> readMember spanValue value (locatedValue member))
  MemberExpression target member -> do
    inner <- compileExpression walker target
    pure $ do
      tally "member"
      -- A chain of names may name a module's member rather than read a value.
      linked <- pathValue expression
      case linked of
        Just value -> pure value
        Nothing -> inner >>= \value -> readMember spanValue value (locatedValue member)
  IndexExpression target index -> do
    container <- compileExpression walker target
    key <- compileExpression walker index
    pure $ do
      tally "index"
      held <- container
      chosen <- key
      readIndex (locatedSpan index) held chosen
  -- Like `while`, the iteration itself is the tree walker's, so every way of
  -- walking a value and the step limit are written once; the body is compiled.
  ForExpression label binder iterated body -> do
    sequenceCode <- compileExpression walker iterated
    turn <- compileBlock walker body
    let needs = (walkLoopNeeds walker){loopBlock = const turn}
    pure $ do
      sequence' <- sequenceCode
      evaluateFor needs spanValue (fmap locatedValue label) binder sequence' body
  IfLetExpression pattern' subject thenBlock elseBranch -> do
    subjectCode <- compileExpression walker subject
    taken <- compileBlock walker thenBlock
    otherwise' <- traverse (compileExpression walker) elseBranch
    pure $ do
      value <- subjectCode
      case matchPattern pattern' value of
        -- Without an `else` the expression answers unit whichever way it went.
        Just bindings -> withBindings (walkSlots walker) bindings $ case otherwise' of
          Nothing -> taken >> pure UnitValue
          Just _ -> taken
        Nothing -> maybe (pure UnitValue) id otherwise'
  TupleExpression [] -> pure (pure UnitValue)
  TupleExpression members -> do
    codes <- mapM (compileExpression walker) members
    pure (TupleValue <$> sequence codes)
  ArrayExpression members -> do
    codes <- mapM (compileExpression walker) members
    pure (ArrayValue . Seq.fromList <$> sequence codes)
  RecordExpression path fields -> do
    codes <- mapM (compileFieldInit walker spanValue) fields
    let owner = lastPathSegment path
    pure (RecordValue owner <$> sequence codes)
  MatchExpression scrutinee arms -> do
    subject <- compileExpression walker scrutinee
    compiled <- mapM (compileArm walker) arms
    pure (subject >>= chooseArm spanValue (walkSlots walker) compiled)
  -- A module's function called by name, with nothing lent to it, is called
  -- directly: this is the path the call machinery takes for such a call, with
  -- what it decides on every call decided here once.
  CallExpression callee arguments
    | Just (first : rest) <- flattenPath (locatedValue callee)
    , Nothing <- slotOf walker first
    , not (any lendsExclusively arguments) -> do
        resolved <- lookupModule (Text.intercalate "." (first : rest))
        case resolved of
          Just (FunctionValue closure)
            | null (exclusiveParameters (closureFunction closure))
            , directCallee callee closure -> do
                codes <- mapM (compileExpression walker) arguments
                general <- compileCall walker spanValue callee arguments
                let invoke = maybe (\callSpan values -> callClosure (walkCallNeeds walker) closure values callSpan) id (multiMapWrapper closure)
                pure $ do
                  local <- lookupLocal first
                  case local of
                    Just _ -> general
                    Nothing -> do
                      values <- sequence codes
                      invoke (Just spanValue) values
          _ -> compileCall walker spanValue callee arguments
  CallExpression callee arguments -> compileCall walker spanValue callee arguments
  _ -> pure (walkExpression walker located)

{-| Member syntax keeps method dispatch unless its captured closure proves
    a transparent call to one of the MultiMap primitives. -}
directCallee :: Located Expression -> Closure -> Bool
directCallee (Located _ NameExpression{}) _ = True
directCallee _ closure = case multiMapWrapper closure of
  Just _ -> True
  Nothing -> False

{-| Whether an argument lends a place exclusively. -}
lendsExclusively :: Located Expression -> Bool
lendsExclusively (Located _ expression) = case expression of
  UnaryExpression "&mut" _ -> True
  _ -> False

{-| A call through the call machinery, which reaches the callee, its receiver,
    and each argument through the needs it is given; each is answered by its
    compiled code, found by where it starts and, where two start together, by
    the syntax itself. -}
compileCall :: Walker -> Span -> Located Expression -> [Located Expression] -> Evaluator Code
compileCall walker spanValue callee arguments = do
    -- The call machinery reaches the callee, its receiver, and each argument
    -- through the needs it is given; each is answered by its compiled code.
    let reached = callee : calleeTarget callee <> concatMap argumentParts arguments
    codes <- mapM (\part -> (,) part <$> compileExpression walker part) reached
    let table = IntMap.fromListWith (<>) [(startOf part, [(part, code)]) | (part, code) <- codes]
        answer part = case IntMap.lookup (startOf part) table of
          Just [(candidate, code)] | locatedSpan candidate == locatedSpan part -> code
          Just several | Just code <- lookup part several -> code
          _ -> walkExpression walker part
        needs = (walkCallNeeds walker){callEvaluate = answer}
    pure (evaluateCall needs spanValue callee arguments)
 where
  startOf part = unOffset (spanStart (locatedSpan part))

{-| The receiver a member callee is called on. -}
calleeTarget :: Located Expression -> [Located Expression]
calleeTarget (Located _ expression) = case expression of
  MemberExpression target _ -> [target]
  TypeApplication inner _ -> calleeTarget inner
  _ -> []

{-| An argument, and what it lends when it is written `&` or `&mut`. -}
argumentParts :: Located Expression -> [Located Expression]
argumentParts argument@(Located _ expression) = case expression of
  UnaryExpression operator operand | operator == "&" || operator == "&mut" -> [argument, operand]
  _ -> [argument]

{-| A field written with its value, or written as a name standing for itself. -}
compileFieldInit :: Walker -> Span -> Located FieldInit -> Evaluator (Evaluator (Text, Value))
compileFieldInit walker recordSpan (Located _ field) = do
  let name = locatedValue (fieldInitName field)
  case fieldInitValue field of
    Just expression -> do
      code <- compileExpression walker expression
      pure ((,) name <$> code)
    Nothing -> pure $ do
      found <- lookupName name
      case found of
        Just existing -> pure (name, existing)
        Nothing -> abortAt (Just recordSpan) "E7001" ("undefined name " <> name) Nothing

{-| An arm's pattern with its guard and body compiled. -}
data Arm = Arm !(Located Pattern) !(Maybe Code) !Code

compileArm :: Walker -> Located MatchArm -> Evaluator Arm
compileArm walker (Located _ arm) = do
  guard' <- traverse (compileExpression walker) (armGuard arm)
  body <- compileExpression walker (armBody arm)
  pure (Arm (armPattern arm) guard' body)

{-| The first arm whose pattern matches and whose guard holds, run in a frame
    holding what its pattern bound. A guard answering anything but `true`
    rejects the arm. -}
chooseArm :: Span -> Maybe (Map Text Int) -> [Arm] -> Value -> Evaluator Value
chooseArm spanValue slots arms subject = case arms of
  [] ->
    abortAt (Just spanValue) "E7011" ("no match arm accepted " <> renderValue subject)
      (Just "add a case that covers this value")
  Arm pattern' guard' body : rest -> case matchPattern pattern' subject of
    Nothing -> chooseArm spanValue slots rest subject
    Just bindings -> do
      let scoped = withBindings slots bindings
      accepted <- case guard' of
        Nothing -> pure True
        Just test -> do
          value <- scoped test
          pure (value == BoolValue True)
      if accepted then scoped body else chooseArm spanValue slots rest subject

{-| Run code with a pattern's bindings: written to their slots in a body on
    slots, where every name has one, or in a frame of their own otherwise. -}
withBindings :: Maybe (Map Text Int) -> [(Text, Value)] -> Evaluator a -> Evaluator a
withBindings slots bindings action = case slots of
  Just layout | all ((`Map.member` layout) . fst) bindings -> do
    mapM_ (\(name, value) -> mapM_ (`writeSlot` value) (Map.lookup name layout)) bindings
    action
  _ -> withFrame bindings action

compileBinary
  :: Walker -> Located Expression -> Located Expression -> Text -> Located Expression -> Evaluator Code
compileBinary walker located@(Located spanValue _) left operator right = case operator of
  "=" -> case plainPlace left of
    _ | Located _ (NameExpression (name :| [])) <- left, Just position <- slotOf walker name -> do
        value <- compileExpression walker right
        pure (value >>= writeSlot position >> pure UnitValue)
    Just place -> do
      value <- compileExpression walker right
      pure $ do
        held <- value
        storePlace place held
        pure UnitValue
    Nothing -> pure (walkExpression walker located)
  "&&" -> do
    first <- compileExpression walker left
    second <- compileExpression walker right
    pure $ do
      truth <- first >>= expectBool spanValue
      if not truth then pure (BoolValue False) else BoolValue <$> (second >>= expectBool spanValue)
  "||" -> do
    first <- compileExpression walker left
    second <- compileExpression walker right
    pure $ do
      truth <- first >>= expectBool spanValue
      if truth then pure (BoolValue True) else BoolValue <$> (second >>= expectBool spanValue)
  "in" -> pure (walkExpression walker located)
  _ -> do
    first <- compileExpression walker left
    second <- compileExpression walker right
    let operation = operationFor spanValue operator
    pure $ do
      leftValue <- first
      rightValue <- second
      operation leftValue rightValue

{-| What an operator does, chosen once. Two integers are handled here with the
    same checks `combine` makes; every other pairing, and every refusal, is
    `combine`'s, so the two cannot disagree. -}
operationFor :: Span -> Text -> Value -> Value -> Evaluator Value
operationFor spanValue operator = case operator of
  "+" -> arithmetic "add" (+)
  "-" -> arithmetic "subtract" (-)
  "*" -> arithmetic "multiply" (*)
  "<" -> comparing (<)
  "<=" -> comparing (<=)
  ">" -> comparing (>)
  ">=" -> comparing (>=)
  "==" -> comparing (==)
  "!=" -> comparing (/=)
  "%" -> \left right -> case (left, right) of
    (IntValue leftKind a, IntValue rightKind b)
      | b /= 0 -> pure (IntValue (integerKindMeet leftKind rightKind) (rem a b))
    _ -> combine spanValue operator left right
  _ -> combine spanValue operator
 where
  arithmetic what apply left right = case (left, right) of
    (IntValue leftKind a, IntValue rightKind b) ->
      checkedResult spanValue (integerKindMeet leftKind rightKind) what (apply a b)
    _ -> combine spanValue operator left right
  comparing test left right = case (left, right) of
    (IntValue _ a, IntValue _ b) -> pure (BoolValue (test a b))
    _ -> combine spanValue operator left right

{-| A block's statements in order, then its result, in a frame of its own when
    one of its statements binds a name. -}
compileBlock :: Walker -> Located Block -> Evaluator Code
compileBlock walker (Located _ block) = do
  steps <- mapM (compileStatement walker) (blockStatements block)
  result <- maybe (pure (pure UnitValue)) (compileExpression walker) (blockResult block)
  let run = sequence_ steps >> result
  -- A body on slots keeps every local in its slot frame, so its blocks open none.
  let scoped = blockIntroducesBindings block && walkSlots walker == Nothing
  pure (if scoped then withNewFrame run else run)

compileStatement :: Walker -> Located Statement -> Evaluator (Evaluator ())
compileStatement walker located@(Located _ statement) = case statement of
  DeclarationStatement (Located _ (BindingDeclaration _ _ name _ value)) -> do
    code <- compileExpression walker value
    pure $ case slotOf walker (locatedValue name) of
      Just position -> code >>= writeSlot position
      Nothing -> code >>= bind (locatedValue name)
  ExpressionStatement expression -> do
    code <- compileExpression walker expression
    pure (code >> pure ())
  ReturnStatement (Just expression) -> do
    code <- compileExpression walker expression
    pure (code >>= unwind . ReturnUnwind)
  _ -> pure (walkStatement walker located)

{-| Whether a block binds a name, and so needs a frame of its own. -}
blockIntroducesBindings :: Block -> Bool
blockIntroducesBindings block = any statementIntroduces (blockStatements block)
 where
  statementIntroduces (Located _ statement) = case statement of
    DeclarationStatement (Located _ BindingDeclaration{}) -> True
    LetElseStatement{} -> True
    LetPatternStatement{} -> True
    _ -> False
