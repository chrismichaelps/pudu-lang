{-| @Compiler.Lower.WordMap — checked sparse word algebra, direct and as values. -}
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
   ("wordMapDifference", KeyedWordDifference), ("wordMapSymmetricDifference", KeyedWordSymmetricDifference)]

lowerWordMapPrimitive :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerWordMapPrimitive lower state at name arguments = do
  _ <- wordMapMethod name
  pure $ case typeForSpan (contextTypes (lowerContext state)) at of
    Just kind | length arguments == 2, Just build <- wordMapCallable name (CoreFunctionType [kind, kind] kind) ->
      let go current done [] = build current at (reverse done)
          go current done (argument : rest) = case lower current argument of
            (after, Nothing) -> refused after
            (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
            (after, Just (core, actual)) | actual == kind -> go after (core : done) rest
            (after, _) -> halt (locatedSpan argument) "a word-map argument without its checked map type" after
       in go state [] arguments
    _ -> halt at "a word-map call without its represented signature" state

wordMapCallable :: Text -> CoreType -> Maybe (LowerState -> Span -> [CoreExpression] -> Lowered)
wordMapCallable name signature = do
  method <- wordMapMethod name
  case signature of
    CoreFunctionType [kind@(CoreMapType _ (CoreIntegerType (UnsignedKind 64))), other] result
      | kind == other && kind == result -> Just $ \state at arguments -> case arguments of
          [left, right] | all ((== kind) . coreExpressionType) arguments ->
            let (withLeft, heldLeft) = bindLocal state "" kind
                (withRight, heldRight) = bindLocal withLeft "" kind
                reading local = CoreExpression at kind (CoreReadLocal local)
                -- Frame methods read arguments before their receiver; these
                -- snapshots preserve the builtin's left-to-right order.
                body = CoreBlock
                  [CoreStatement at (CoreDeclare heldLeft left), CoreStatement at (CoreDeclare heldRight right)]
                  (Just (CoreExpression at kind (CoreKeyedMethod method (reading heldLeft) [reading heldRight])))
             in (withRight, Just (CoreExpression at kind (CoreBlockValue body), kind))
          _ -> halt at "a word-map value without its checked arguments" state
    _ -> Nothing
