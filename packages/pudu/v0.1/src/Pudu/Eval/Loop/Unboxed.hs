{-# LANGUAGE BangPatterns, MagicHash, UnboxedSums, UnboxedTuples #-}
{-| @Eval.Loop.Unboxed — machine-word execution of proven integer loop regions. -}
module Pudu.Eval.Loop.Unboxed
  ( Region
  , executeRegion
  , planRegion
  , platformIntValue
  ) where

import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import GHC.Exts
  ( Int (I#), Int#, MutableByteArray#, RealWorld, State#, (+#), (-#), (*#)
  , addIntC#, subIntC#, quotInt#, remInt#, negateInt#, intToInt64#, int64ToInt#
  , ltInt64#, leInt64#, gtInt64#, geInt64#, eqInt64#, neInt64#
  , newByteArray#, readInt64Array#, writeInt64Array# )
import GHC.IO (IO (..))
import Pudu.Comptime.Limits (iterationLimit)
import Pudu.Eval.Env (Env, Eval (..), Evaluator (..), abortAt, integerKindAt)
import Pudu.Eval.Match (integerLiteralValue)
import Pudu.Eval.Value (Value (..))
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Block (..), Expression (..), Statement (..))
import Pudu.IntegerLiteral (IntegerKind (..), integerKindName)
import Pudu.Source (Span)

type Slots = MutableByteArray# RealWorld

{-| A planned pure computation: the machine word it yields, or the exact
    refusal the boxed kernel would have produced. -}
type Code = Env -> Slots -> State# RealWorld -> (# State# RealWorld, (# Int# | Eval Value #) #)

data Region = Region
  { regionCondition :: !Code
  , regionSteps :: ![Code]
  , regionWritten :: ![(Int, Text)]
  , regionSpan :: !Span
  }

{-| The platform `Int` a value denotes, when the machine word can hold it. -}
platformIntValue :: Value -> Maybe Integer
platformIntValue (IntValue PlatformSigned number)
  | number >= toInteger (minBound :: Int), number <= toInteger (maxBound :: Int) = Just number
platformIntValue _ = Nothing

{-| Plan the whole region or nothing; planning reads bindings and evaluates no source. -}
planRegion :: Span -> Map.Map Text Int -> Located Expression -> Located Block -> Evaluator (Maybe Region)
planRegion spanValue layout condition body = do
  test <- planBool layout condition
  turn <- planSteps layout body
  pure $ do
    conditionCode <- test
    (steps, final, written) <- turn
    let rest = maybe [] (\(code, _, _) -> [code]) final
        resultWrites = maybe Set.empty (\(_, names, _) -> names) final
        allWritten = written <> resultWrites
        writtenByPosition =
          [(position, name) | (name, position) <- Map.toList layout, name `Set.member` allWritten]
    pure Region
      { regionCondition = conditionCode
      , regionSteps = steps <> rest
      , regionWritten = writtenByPosition
      , regionSpan = spanValue
      }

planBool :: Map.Map Text Int -> Located Expression -> Evaluator (Maybe Code)
planBool layout (Located _ expression) = case expression of
  UnaryExpression "!" operand -> do
    planned <- planBool layout operand
    pure (notCode <$> planned)
  BinaryExpression left operator right
    | operator `elem` ["&&", "||"] -> do
        lhs <- planBool layout left
        rhs <- planBool layout right
        pure $ do
          leftCode <- lhs
          rightCode <- rhs
          pure (if operator == "&&" then andCode leftCode rightCode else orCode leftCode rightCode)
    | operator `elem` ["<", ">", "<=", ">=", "==", "!="] -> do
        lhs <- planInt layout left
        rhs <- planInt layout right
        pure $ do
          leftCode <- lhs
          rightCode <- rhs
          pure (compareAt operator leftCode rightCode)
  _ -> pure Nothing

planInt :: Map.Map Text Int -> Located Expression -> Evaluator (Maybe Code)
planInt layout (Located spanValue expression) = case expression of
  LiteralExpression literal -> do
    selected <- integerKindAt spanValue
    pure (literalCode (integerLiteralValue selected literal))
  NameExpression (name :| []) -> pure (readSlot <$> Map.lookup name layout)
  UnaryExpression operator operand | operator `elem` ["&", "*", "-"] -> do
    planned <- planInt layout operand
    pure $ case operator of
      "-" -> negateCode spanValue <$> planned
      _ -> planned
  BinaryExpression left operator right
    | operator `elem` ["+", "-", "*", "/", "%"] -> do
        lhs <- planInt layout left
        rhs <- planInt layout right
        pure $ do
          leftCode <- lhs
          rightCode <- rhs
          pure (arithmeticAt spanValue operator leftCode rightCode)
  BlockExpression block -> do
    planned <- planSteps layout block
    pure $ do
      (steps, final, _) <- planned
      (result, _, isInt) <- final
      if isInt then pure (chain steps result) else Nothing
  _ -> pure Nothing

{-| Statement order is left to right; the block result, when present, is the
    final planned value. The result may itself be an assignment, which the
    parser places there; the Bool records whether the final code is an integer. -}
planSteps :: Map.Map Text Int -> Located Block -> Evaluator (Maybe ([Code], Maybe (Code, Set.Set Text, Bool), Set.Set Text))
planSteps layout (Located _ block) = do
  statements <- traverse (planStatement layout) (blockStatements block)
  result <- traverse (planResult layout) (blockResult block)
  pure $ do
    leading <- sequence statements
    final <- sequence result
    let steps = map fst leading
        written = Set.unions (map snd leading)
    pure (steps, final, written)

planResult :: Map.Map Text Int -> Located Expression -> Evaluator (Maybe (Code, Set.Set Text, Bool))
planResult layout expression = do
  asInt <- planInt layout expression
  case asInt of
    Just code -> pure (Just (code, Set.empty, True))
    Nothing -> do
      asStatement <- planStatementExpression layout expression
      pure (fmap (\(code, written) -> (code, written, False)) asStatement)

planStatement :: Map.Map Text Int -> Located Statement -> Evaluator (Maybe (Code, Set.Set Text))
planStatement layout (Located _ statement) = case statement of
  ExpressionStatement expression -> planStatementExpression layout expression
  _ -> pure Nothing

planStatementExpression :: Map.Map Text Int -> Located Expression -> Evaluator (Maybe (Code, Set.Set Text))
planStatementExpression layout located@(Located _ expression) = case expression of
  BinaryExpression (Located _ (NameExpression (name :| []))) "=" right
    | Just position <- Map.lookup name layout -> do
        planned <- planInt layout right
        pure (fmap (\code -> (writeSlot position code, Set.singleton name)) planned)
  _ -> do
    planned <- planInt layout located
    pure (fmap (\code -> (code, Set.empty)) planned)

literalCode :: Value -> Maybe Code
literalCode value = do
  number <- platformIntValue value
  case fromInteger number :: Int of
    I# word# -> pure (\_ _ state -> (# state, (# word# | #) #))

readSlot :: Int -> Code
readSlot (I# position#) _ slots state = case readInt64Array# slots position# state of
  (# after, value #) -> (# after, (# int64ToInt# value | #) #)

writeSlot :: Int -> Code -> Code
writeSlot (I# position#) value = thenCode value $ \result _ slots state ->
  case writeInt64Array# slots position# (intToInt64# result) state of
    after -> (# after, (# 0# | #) #)

{-# INLINE thenCode #-}
thenCode :: Code -> (Int# -> Code) -> Code
thenCode first next env slots state = case first env slots state of
  (# after, (# value | #) #) -> next value env slots after
  (# after, (# | stopped #) #) -> (# after, (# | stopped #) #)

chain :: [Code] -> Code -> Code
chain leading final = foldr (\step rest -> thenCode step (\_ -> rest)) final leading

negateCode :: Span -> Code -> Code
negateCode spanValue code = thenCode code $ \value env _ state ->
  case extremal value minWord of
    0# -> (# state, (# negateInt# value | #) #)
    _ -> overflowAt env state spanValue "negate"
 where
  minWord = negateInt# 9223372036854775807# -# 1#

arithmeticAt :: Span -> Text -> Code -> Code -> Code
arithmeticAt spanValue operator left right = case operator of
  "+" -> binary left right (\a b env _ state -> case addIntC# a b of
    (# result, carry #) -> case carry of
      0# -> (# state, (# result | #) #)
      _ -> overflowAt env state spanValue "add")
  "-" -> binary left right (\a b env _ state -> case subIntC# a b of
    (# result, borrow #) -> case borrow of
      0# -> (# state, (# result | #) #)
      _ -> overflowAt env state spanValue "subtract")
  "*" -> binary left right (multiplyAt spanValue)
  "/" -> binary left right (divideAt spanValue)
  _ -> binary left right (remainderAt spanValue)

binary :: Code -> Code -> (Int# -> Int# -> Code) -> Code
binary left right operation = thenCode left $ \a -> thenCode right (operation a)

{-| The wrapped product divided back by the right operand equals the left
    operand exactly when no bit was lost. The `-1` divisor is pinned out
    because `quotInt#` is undefined for the extreme pair. -}
multiplyAt :: Span -> Int# -> Int# -> Code
multiplyAt spanValue left right env _ state = case right of
  0# -> (# state, (# 0# | #) #)
  _ -> case extremal right minusOne of
    0# -> case extremal (quotInt# (left *# right) right) left of
      0# -> overflowAt env state spanValue "multiply"
      _ -> (# state, (# left *# right | #) #)
    _ -> case extremal left minWord of
      0# -> (# state, (# left *# right | #) #)
      _ -> overflowAt env state spanValue "multiply"
 where
  minusOne = negateInt# 1#
  minWord = negateInt# 9223372036854775807# -# 1#


divideAt :: Span -> Int# -> Int# -> Code
divideAt spanValue left right env _ state = case right of
  0# -> divideByZeroAt env state spanValue
  _ -> case extremal left minWord of
    0# -> (# state, (# quotInt# left right | #) #)
    _ -> case extremal right (negateInt# 1#) of
      0# -> (# state, (# quotInt# left right | #) #)
      _ -> overflowAt env state spanValue "divide"
 where
  minWord = negateInt# 9223372036854775807# -# 1#

remainderAt :: Span -> Int# -> Int# -> Code
remainderAt spanValue left right env _ state = case right of
  0# -> divideByZeroAt env state spanValue
  _ -> case extremal left minWord of
    0# -> (# state, (# remInt# left right | #) #)
    _ -> case extremal right (negateInt# 1#) of
      0# -> (# state, (# remInt# left right | #) #)
      _ -> (# state, (# 0# | #) #)
 where
  minWord = negateInt# 9223372036854775807# -# 1#

extremal :: Int# -> Int# -> Int#
extremal left right = eqInt64# (intToInt64# left) (intToInt64# right)

compareAt :: Text -> Code -> Code -> Code
compareAt operator left right = case operator of
  "<" -> comparable (\a b -> ltInt64# a b)
  ">" -> comparable (\a b -> gtInt64# a b)
  "<=" -> comparable (\a b -> leInt64# a b)
  ">=" -> comparable (\a b -> geInt64# a b)
  "==" -> comparable (\a b -> eqInt64# a b)
  _ -> comparable (\a b -> neInt64# a b)
 where
  comparable comparison = binary left right $ \a b _ _ state ->
    (# state, (# comparison (intToInt64# a) (intToInt64# b) | #) #)

andCode :: Code -> Code -> Code
andCode left right = thenCode left $ \value -> case value of
  0# -> constant 0#
  _ -> right

orCode :: Code -> Code -> Code
orCode left right = thenCode left $ \value -> case value of
  0# -> right
  _ -> constant 1#

notCode :: Code -> Code
notCode code = thenCode code $ \value -> case value of
  0# -> constant 1#
  _ -> constant 0#

constant :: Int# -> Code
constant value _ _ state = (# state, (# value | #) #)

overflowAt :: Env -> State# RealWorld -> Span -> Text -> (# State# RealWorld, (# Int# | Eval Value #) #)
overflowAt env state spanValue what = stopAt env state spanValue "E7005"
  (integerKindName PlatformSigned <> " cannot hold the result of this " <> what)
  (Just "use the wrapping or saturating form, or a wider type; checked arithmetic never truncates quietly")

divideByZeroAt :: Env -> State# RealWorld -> Span -> (# State# RealWorld, (# Int# | Eval Value #) #)
divideByZeroAt env state spanValue = stopAt env state spanValue "E7004" "division by zero" Nothing

stopAt :: Env -> State# RealWorld -> Span -> Text -> Text -> Maybe Text -> (# State# RealWorld, (# Int# | Eval Value #) #)
stopAt env state spanValue code message help =
  case abortAt (Just spanValue) code message help of
    Evaluator action -> case action env of
      IO io -> case io state of
        (# after, stopped #) -> (# after, (# | stopped #) #)

{-| Run a fully planned region; Left is the exact refusal, Right the final
    written bindings in commit order. Boxes once per written binding at exit. -}
executeRegion :: Region -> Env -> [Integer] -> Bool -> IO (Either (Eval Value) [(Text, Value)])
executeRegion region env initial limited = IO $ \state ->
  case newByteArray# (8# *# size#) state of
    (# after, slots #) ->
      case install slots 0# initial after of
        installed -> case loop slots 0# installed of
          (# after', (# | stopped #) #) -> (# after', Left stopped #)
          (# after', (# _ | #) #) -> case gather slots (regionWritten region) after' of
            (# after'', finals #) -> (# after'', Right finals #)
 where
  size# = case length initial of I# count# -> count#
  limit# = case iterationLimit of I# bound# -> bound#

  install :: Slots -> Int# -> [Integer] -> State# RealWorld -> State# RealWorld
  install _ _ [] state = state
  install slots index (number : rest) state =
    case fromInteger number :: Int of
      I# word# -> install slots (index +# 1#) rest
        (writeInt64Array# slots index (intToInt64# word#) state)

  loop :: Slots -> Int# -> State# RealWorld -> (# State# RealWorld, (# Int# | Eval Value #) #)
  loop slots iterations state
    | limited = case gtInt64# (intToInt64# iterations) (intToInt64# limit#) of
        0# -> turn slots iterations state
        _ -> stopAt env state (regionSpan region) "E7002"
          "loop exceeded the evaluation step limit"
          (Just "a constant is folded while the compiler runs; restructure the loop")
    | otherwise = turn slots iterations state
   where
    turn :: Slots -> Int# -> State# RealWorld -> (# State# RealWorld, (# Int# | Eval Value #) #)
    turn current count token = case regionCondition region env current token of
      (# next, (# | stopped #) #) -> (# next, (# | stopped #) #)
      (# next, (# truth | #) #) -> case truth of
        0# -> (# next, (# 0# | #) #)
        _ -> case runSteps (regionSteps region) env current next of
          (# next', (# | stopped #) #) -> (# next', (# | stopped #) #)
          (# next', (# _ | #) #) -> loop current (count +# 1#) next'

  runSteps :: [Code] -> Env -> Slots -> State# RealWorld -> (# State# RealWorld, (# Int# | Eval Value #) #)
  runSteps [] _ _ state = (# state, (# 0# | #) #)
  runSteps (step : rest) scope slots state = case step scope slots state of
    (# after, (# | stopped #) #) -> (# after, (# | stopped #) #)
    (# after, (# _ | #) #) -> runSteps rest scope slots after

  gather :: Slots -> [(Int, Text)] -> State# RealWorld -> (# State# RealWorld, [(Text, Value)] #)
  gather _ [] state = (# state, [] #)
  gather slots ((I# position#, name) : rest) state =
    case readInt64Array# slots position# state of
      (# after, value #) -> case gather slots rest after of
        (# after', finals #) -> (# after', (name, IntValue PlatformSigned (toInteger (I# (int64ToInt# value)))) : finals #)
