{-| @Compiler.Lower.WordMap — checked sparse word operations, direct and as values. -}
module Pudu.Compiler.Lower.WordMap (lowerWordMapPrimitive, wordMapCallable, wordMapMethod) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (stopped)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Types (typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

wordMapMethod :: Text -> Maybe CoreKeyedMethodName
wordMapMethod name = lookup name
  [("wordMapUnion", KeyedWordUnion), ("wordMapIntersection", KeyedWordIntersection),
   ("wordMapDifference", KeyedWordDifference), ("wordMapSymmetricDifference", KeyedWordSymmetricDifference),
   ("wordMapIsSubsetOf", KeyedWordSubset), ("wordMapIsDisjointFrom", KeyedWordDisjoint),
   ("wordMapPopCount", KeyedWordPopCount), ("wordMapMembers", KeyedWordMembers)]

lowerWordMapPrimitive :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerWordMapPrimitive lower state at name arguments = do
  _ <- wordMapMethod name
  pure (go state [] arguments)
 where
  go current done [] = case typeForSpan (contextTypes (lowerContext current)) at of
    Just result
      | let cores = reverse done
      , Just build <- wordMapCallable name (CoreFunctionType (map coreExpressionType cores) result) -> build current at cores
    _ -> halt at "a word-map call without its represented signature" current
  go current done (argument : rest) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
    (after, Just (core, _)) -> go after (core : done) rest

wordMapCallable :: Text -> CoreType -> Maybe (LowerState -> Span -> [CoreExpression] -> Lowered)
wordMapCallable name signature = do
  method <- wordMapMethod name
  case signature of
    CoreFunctionType inputs@(kind@(CoreMapType key payload) : _) result
      | payload == word, Just (arity, expected) <- shape method key kind
      , inputs == replicate arity kind, result == expected -> Just $ \state at arguments ->
          if map coreExpressionType arguments /= inputs then halt at "a word-map value without its checked arguments" state
          else
            let hold (current, collected, snapshots) core =
                  let (after, local) = bindLocal current "" kind
                   in (after, collected <> [CoreStatement at (CoreDeclare local core)], snapshots <> [CoreExpression at kind (CoreReadLocal local)])
                (held, statements, readings) = foldl' hold (state, [], []) arguments
             in case readings of
                  receiver : operands ->
                    let body = CoreBlock statements (Just (CoreExpression at result (CoreKeyedMethod method receiver operands)))
                     in (held, Just (CoreExpression at result (CoreBlockValue body), result))
                  [] -> halt at "a word-map value without its receiver" held
    _ -> Nothing
 where
  word = CoreIntegerType (UnsignedKind 64)
  shape method key kind = case method of
    KeyedWordSubset -> Just (2, CoreBoolType)
    KeyedWordDisjoint -> Just (2, CoreBoolType)
    KeyedWordPopCount -> Just (1, CoreIntegerType (UnsignedKind 128))
    KeyedWordMembers | key == word -> Just (1, CoreArrayType word)
    _ | method `elem` [KeyedWordUnion, KeyedWordIntersection, KeyedWordDifference, KeyedWordSymmetricDifference] -> Just (2, kind)
    _ -> Nothing
