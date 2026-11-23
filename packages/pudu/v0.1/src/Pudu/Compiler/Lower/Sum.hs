{-| @Pudu.Compiler.Lower.Sum — constructing a variant: `Dot`, `Shape.Dot`,
    `Circle(3)`, `Some(x)`. Record variants go through [[Compiler Lower Record]].

    A name or call is a variant only when the checker typed its span as a sum
    that has a variant of that name taking that many positional members, so
    locals and functions of the same name are never mistaken for one. -}
module Pudu.Compiler.Lower.Sum (lowerVariant, variantAt, constructVariant) where

import Data.List (find, mapAccumL)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, refused)
import Pudu.Compiler.Lower.Types (sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, projectRuntimeValue, storageCarrier, sumWithPayload, widen)
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
          else constructVariant current at kind name (zip labels members)
  go kind current done (argument : rest) = case lower current argument of
    (next, Nothing) -> refused next
    (next, Just (core, _))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] payload" next
      | coreExpressionType core == CoreNeverType -> go kind next (core : done) []
      | otherwise -> go kind next (core : done) rest
  labels = map (Text.pack . show) [0 :: Int ..]

constructVariant :: LowerState -> Span -> CoreType -> Text -> [(Text, CoreExpression)]
  -> (LowerState, Maybe (CoreExpression, CoreType))
constructVariant state at declared name fields
  | Just variants <- sumVariants types declared
  , Just selected <- find ((== name) . coreVariantName) variants =
      let adjust variant
            | coreVariantName variant == name = map choose (coreVariantFields variant)
            | otherwise = coreVariantFields variant
          payload = concatMap adjust variants
          actual = sumWithPayload types declared (map snd payload)
          expected = adjust selected
          project current (label, value) = case lookup label expected of
            Just kind -> let (ready, converted) = projectRuntimeValue types current kind value
                          in (ready, (label, converted))
            Nothing -> (current, (label, value))
          (ready, members) = mapAccumL project state fields
       in if length expected == length members
            && all (\(label, value) -> lookup label expected == Just (coreExpressionType value)) members
            then (ready, Just (CoreExpression at actual (CoreConstruct name members), actual))
            else halt at "a variant constructor with incompatible payload layouts" ready
  | otherwise = halt at "a constructor outside its native sum" state
 where
  types = contextTypes (lowerContext state)
  choose (label, expected) = (label, case lookup label fields of
    Just value
      | let actual = coreExpressionType (widen types expected value)
      , hasRuntimeChoice actual -> storageCarrier types expected [actual]
    _ -> expected)
