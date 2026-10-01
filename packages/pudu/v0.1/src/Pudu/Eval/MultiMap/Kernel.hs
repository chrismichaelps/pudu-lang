{-| @Eval.MultiMap.Kernel — pure loop regions over the MultiMap primitives. -}
module Pudu.Eval.MultiMap.Kernel (multiMapLoop) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import GHC.IOArray (IOArray, newIOArray, unsafeReadIOArray, unsafeWriteIOArray)
import Pudu.Eval.Env
  ( Env (..), Eval (..), Evaluator (..), abortAt, expectBool, integerKindAt
  , lookupLocal, lookupModule, lookupName, updateExisting )
import Pudu.Eval.Frame (frameLookup)
import Pudu.Eval.Match (integerLiteralValue, literalValue)
import Pudu.Eval.MultiMap (callMultiMapAdd, callMultiMapContains, multiMapWrapper)
import Pudu.Eval.Operator (applyUnary, checkedResult, combine)
import Pudu.IntegerLiteral (integerKindMeet)
import Pudu.Eval.Value (Builtin (..), Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..), Expression (..), Literal (IntegerValue), Statement (..) )
import Pudu.Source (Span)

type Slots = IOArray Int Value
type Code = Slots -> Env -> IO (Result Value)
data Result a = Yield !a | Stop !(Eval Value)
data Plan = Plan !Code !(Set Text) !(Set Text) !(Set Text) !Bool

{-| Eligibility is all-or-nothing; planning reads bindings but executes no source. -}
multiMapLoop :: Span -> Located Expression -> Located Block -> Evaluator (Maybe (Evaluator Value))
multiMapLoop spanValue condition body = do
  let names = Set.toAscList (readsOf condition <> readsOfBlock body)
      layout = Map.fromList (zip names [0 ..])
  test <- planExpression layout condition
  turn <- planBlock layout body
  case (test, turn) of
    (Just (Plan testCode _ testWrites testCallees testNative),
      Just (Plan bodyCode _ bodyWrites bodyCallees bodyNative))
      | testNative || bodyNative
      , Set.null ((testWrites <> bodyWrites) `Set.intersection` (testCallees <> bodyCallees)) -> do
          values <- mapM lookupName names
          case sequence values of
            Nothing -> pure Nothing
            Just initial -> Evaluator $ \env -> do
              writable <- mapM (boundIn (envFrames env)) (Set.toList (testWrites <> bodyWrites))
              pure (Done (if and writable
                then Just (execute spanValue names initial (testWrites <> bodyWrites) testCode bodyCode)
                else Nothing) env)
    _ -> pure Nothing
 where
  boundIn [] _ = pure False
  boundIn (frame : rest) name = do
    found <- frameLookup name frame
    case found of
      Just _ -> pure True
      Nothing -> boundIn rest name

execute :: Span -> [Text] -> [Value] -> Set Text -> Code -> Code -> Evaluator Value
execute spanValue names initial written test body = Evaluator $ \env -> do
  slots <- newIOArray (0, length names - 1) UnitValue
  mapM_ (uncurry (unsafeWriteIOArray slots)) (zip [0 ..] initial)
  outcome <- loop slots env (0 :: Int)
  case outcome of
    Stop stopped -> pure stopped
    Yield _ -> do
      finals <- mapM (\(position, name) -> do
        value <- unsafeReadIOArray slots position
        pure (name, value)) [(position, name) | (position, name) <- zip [0 ..] names, name `Set.member` written]
      let Evaluator commit = mapM_ (\(name, value) -> updateExisting name value) finals >> pure UnitValue
      commit env
 where
  loop slots env iterations
    | iterations > 100000 && not (envEffects env) =
        action env (abortAt (Just spanValue) "E7002" "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; restructure the loop"))
    | otherwise = bindResult (test slots env) $ \value ->
        bindResult (boolean env spanValue value) $ \truth -> case truth of
          True -> bindResult (body slots env) (\_ -> loop slots env (iterations + 1))
          _ -> pure (Yield UnitValue)

{-| Primitive actions are pure apart from the runtime's own call tally. -}
{-# INLINE action #-}
action :: Env -> Evaluator Value -> IO (Result Value)
action env (Evaluator run) = do
  outcome <- run env
  pure $ case outcome of
    Done value _ -> Yield value
    other -> Stop other

{-# INLINE bindResult #-}
bindResult :: IO (Result a) -> (a -> IO (Result b)) -> IO (Result b)
bindResult left next = do
  outcome <- left
  case outcome of
    Yield value -> next value
    Stop stopped -> pure (Stop stopped)

planExpression :: Map.Map Text Int -> Located Expression -> Evaluator (Maybe Plan)
planExpression layout (Located spanValue expression) = case expression of
  NameExpression (name :| []) -> pure $ do
    position <- Map.lookup name layout
    pure (Plan (\slots _ -> Yield <$> unsafeReadIOArray slots position) (Set.singleton name) Set.empty Set.empty False)
  LiteralExpression literal -> do
    value <- case literal of
      IntegerValue _ -> do
        selected <- integerKindAt spanValue
        pure (integerLiteralValue selected literal)
      _ -> pure (literalValue literal)
    pure (Just (Plan (\_ _ -> pure (Yield value)) Set.empty Set.empty Set.empty False))
  UnaryExpression operator operand | operator `elem` ["&", "*", "-", "!", "~"] -> do
    planned <- planExpression layout operand
    pure $ do
      Plan inner names written callees native <- planned
      let code = if operator == "&" || operator == "*"
            then inner
            else \slots env -> bindResult (inner slots env) (action env . applyUnary spanValue operator)
      pure (Plan code names written callees native)
  BinaryExpression (Located _ (NameExpression (name :| []))) "=" right -> do
    planned <- planExpression layout right
    pure $ do
      position <- Map.lookup name layout
      Plan inner names written callees native <- planned
      let code slots env = bindResult (inner slots env) $ \value -> do
            unsafeWriteIOArray slots position value
            pure (Yield UnitValue)
      pure (Plan code (Set.insert name names) (Set.insert name written) callees native)
  BinaryExpression left operator right | operator `elem` ["+", "-", "*", "/", "%", "<", ">", "<=", ">=", "==", "!=", "&&", "||"] -> do
    lhs <- planExpression layout left
    rhs <- planExpression layout right
    pure $ do
      a@(Plan leftCode _ _ _ _) <- lhs
      b@(Plan rightCode _ _ _ _) <- rhs
      let apply = scalar spanValue operator
          code slots env = bindResult (leftCode slots env) $ \x ->
            if operator == "&&" || operator == "||"
              then bindResult (boolean env spanValue x) $ \truth ->
                if truth == (operator == "||")
                  then pure (Yield (BoolValue truth))
                  else bindResult (rightCode slots env) (\y -> fmap (mapResult BoolValue) (boolean env spanValue y))
              else bindResult (rightCode slots env) (action env . apply x)
      pure (joined code [a, b])
  CallExpression callee arguments | length arguments == 3 -> do
    target <- nativeCallee callee
    args <- traverse (planExpression layout) arguments
    pure $ do
      (prefix, invoke) <- target
      plans@[Plan first _ _ _ _, Plan second _ _ _ _, Plan third _ _ _ _] <- sequence args
      let code slots env = bindResult (first slots env) $ \a ->
            bindResult (second slots env) $ \b ->
              bindResult (third slots env) $ \c -> action env (invoke (Just spanValue) [a, b, c])
          Plan combined names written callees _ = joined code plans
      pure (Plan combined names written (Set.insert prefix callees) True)
  BlockExpression block -> planBlock layout block
  IfExpression condition thenBlock elseBranch -> do
    test <- planExpression layout condition
    taken <- planBlock layout thenBlock
    alternative <- case elseBranch of
      Nothing -> pure (Just (Plan (\_ _ -> pure (Yield UnitValue)) Set.empty Set.empty Set.empty False))
      Just branch -> planExpression layout branch
    pure $ do
      a@(Plan testCode _ _ _ _) <- test
      b@(Plan thenCode _ _ _ _) <- taken
      c@(Plan elseCode _ _ _ _) <- alternative
      let code slots env = bindResult (testCode slots env) $ \value ->
            bindResult (boolean env spanValue value) $ \truth ->
              if truth then thenCode slots env else elseCode slots env
      pure (joined code [a, b, c])
  _ -> pure Nothing

planBlock :: Map.Map Text Int -> Located Block -> Evaluator (Maybe Plan)
planBlock layout (Located _ block) = do
  statements <- traverse planStatement (blockStatements block)
  final <- traverse (planExpression layout) (blockResult block)
  pure $ do
    leading <- sequence statements
    trailing <- sequence final
    let plans = leading <> maybe [] (: []) trailing
        finish = case trailing of
          Nothing -> \_ _ -> pure (Yield UnitValue)
          Just (Plan finalCode _ _ _ _) -> finalCode
        code = foldr before finish leading
        before (Plan first _ _ _ _) rest slots env = bindResult (first slots env) (\_ -> rest slots env)
    pure (joined code plans)
 where
  planStatement (Located _ (ExpressionStatement expression)) = planExpression layout expression
  planStatement _ = pure Nothing

joined :: Code -> [Plan] -> Plan
joined code plans = Plan code
  (Set.unions [names | Plan _ names _ _ _ <- plans])
  (Set.unions [written | Plan _ _ written _ _ <- plans])
  (Set.unions [callees | Plan _ _ _ callees _ <- plans])
  (or [native | Plan _ _ _ _ native <- plans])

{-# INLINE mapResult #-}
mapResult :: (a -> b) -> Result a -> Result b
mapResult transform (Yield value) = Yield (transform value)
mapResult _ (Stop stopped) = Stop stopped

{-# INLINE boolean #-}
boolean :: Env -> Span -> Value -> IO (Result Bool)
boolean _ _ (BoolValue flag) = pure (Yield flag)
boolean env spanValue value = fmap (mapResult (== BoolValue True))
  (action env (BoolValue <$> expectBool spanValue value))

scalar :: Span -> Text -> Value -> Value -> Evaluator Value
scalar spanValue operator = case operator of
  "+" -> arithmetic "add" (+)
  "-" -> arithmetic "subtract" (-)
  "*" -> arithmetic "multiply" (*)
  "%" -> \left right -> case (left, right) of
    (IntValue a x, IntValue b y) | y /= 0 -> pure (IntValue (integerKindMeet a b) (rem x y))
    _ -> general left right
  "<" -> comparison (<)
  ">" -> comparison (>)
  "<=" -> comparison (<=)
  ">=" -> comparison (>=)
  "==" -> comparison (==)
  "!=" -> comparison (/=)
  _ -> general
 where
  general = combine spanValue operator
  arithmetic name operation left right = case (left, right) of
    (IntValue a x, IntValue b y) -> checkedResult spanValue (integerKindMeet a b) name (operation x y)
    _ -> general left right
  comparison predicate left right = case (left, right) of
    (IntValue _ x, IntValue _ y) -> pure (BoolValue (predicate x y))
    _ -> general left right

nativeCallee :: Located Expression -> Evaluator (Maybe (Text, Maybe Span -> [Value] -> Evaluator Value))
nativeCallee (Located primitiveSpan expression) = case path expression of
  Just names@(first : _) -> do
    local <- lookupLocal first
    found <- lookupModule (Text.intercalate "." names)
    pure $ case (local, found) of
      (Nothing, Just (FunctionValue closure)) -> (first,) <$> multiMapWrapper closure
      (Nothing, Just (BuiltinValue MultiMapAddBuiltin)) -> Just (first, \callSpan -> callMultiMapAdd (maybe primitiveSpan id callSpan))
      (Nothing, Just (BuiltinValue MultiMapContainsBuiltin)) -> Just (first, \callSpan -> callMultiMapContains (maybe primitiveSpan id callSpan))
      _ -> Nothing
  _ -> pure Nothing
 where
  path (NameExpression names) = Just (foldr (:) [] names)
  path (MemberExpression (Located _ target) member) = (<> [locatedValue member]) <$> path target
  path _ = Nothing

readsOf :: Located Expression -> Set Text
readsOf (Located _ expression) = case expression of
  NameExpression (name :| []) -> Set.singleton name
  UnaryExpression _ operand -> readsOf operand
  BinaryExpression left _ right -> readsOf left <> readsOf right
  CallExpression _ arguments -> Set.unions (map readsOf arguments)
  BlockExpression block -> readsOfBlock block
  IfExpression condition thenBlock elseBranch -> readsOf condition <> readsOfBlock thenBlock <> maybe Set.empty readsOf elseBranch
  _ -> Set.empty

readsOfBlock :: Located Block -> Set Text
readsOfBlock (Located _ block) = Set.unions
  ([readsOf expression | Located _ (ExpressionStatement expression) <- blockStatements block]
    <> maybe [] (\result -> [readsOf result]) (blockResult block))
