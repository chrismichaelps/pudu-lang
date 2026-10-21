{-| @Pudu.Compiler.Lower.Sum — constructing a variant: `Dot`, `Shape.Dot`,
    `Circle(3)`, `Some(x)`. Record variants go through [[Compiler Lower Record]].

    A name or call is a variant only when the checker typed its span as a sum
    that has a variant of that name taking that many positional members, so
    locals and functions of the same name are never mistaken for one. -}
module Pudu.Compiler.Lower.Sum (lowerVariant, variantAt) where

import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, refused)
import Pudu.Compiler.Lower.Types (sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

variantAt :: LowerState -> Span -> Text -> Maybe Int -> Maybe (CoreType, CoreVariant)
variantAt state at name arity = do
  let types = contextTypes (lowerContext state)
  kind <- typeForSpan types at
  variants <- sumVariants types kind
  variant <- find ((== name) . coreVariantName) variants
  case arity of
    Just count | coreVariantRecord variant || length (coreVariantFields variant) /= count -> Nothing
    _ -> Just (kind, variant)

{-| Payload members run left to right; a Never member stops the variant
    after the members before it ran. -}
lowerVariant :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression]
  -> Maybe (LowerState, Maybe (CoreExpression, CoreType))
lowerVariant lower state at name arguments = do
  (kind, _) <- variantAt state at name (Just (length arguments))
  Just (go kind state [] arguments)
 where
  go kind current done [] =
    let members = reverse done
     in if any ((== CoreNeverType) . coreExpressionType) members
          then (current, Just (CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
                 [CoreStatement (coreExpressionSpan member) (CoreEvaluate member) | member <- members] Nothing)), CoreNeverType))
          else (current, Just (CoreExpression at kind (CoreConstruct name (zip labels members)), kind))
  go kind current done (argument : rest) = case lower current argument of
    (next, Nothing) -> refused next
    (next, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] payload" next
      | coreExpressionType core == CoreNeverType -> go kind next (core : done) []
      | otherwise -> go kind next (core : done) rest
  labels = map (Text.pack . show) [0 :: Int ..]
