{-| @Pudu.Compiler.Lower.Sum — constructing a variant: `Dot`, `Shape.Dot`,
    `Circle(3)`, `Some(x)`. Record variants go through [[Compiler Lower Record]].

    A name or call is a variant only when the checker typed its span as a sum
    that has a variant of that name taking that many positional members, so
    locals and functions of the same name are never mistaken for one. -}
module Pudu.Compiler.Lower.Sum (lowerVariant, variantAt, constructVariant, lowerConstructorValue, registerConstructor) where

import Data.List (find, mapAccumL)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (CallableSource (..), CallableTemplate (..), LowerContext (..), LowerState (..), halt, refused, startFunction)
import Pudu.Compiler.Lower.Types (nativeValueType, ownerKeyOf, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Core.Closure (constructorSite)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, projectRuntimeValue, storageCarrier, sumWithPayload, widen)
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

lowerConstructorValue :: LowerExpression -> LowerState -> Span -> Text -> Text -> Lowered
lowerConstructorValue lower state at owner label =
  case typeForSpan (contextTypes (lowerContext state)) at of
    Just (CoreFunctionType inputs result) -> registerConstructor state at owner label result inputs
    Just result | ownerKeyOf result == Just owner
      , Just lowered <- lowerVariant lower state at label [] -> lowered
    _ -> halt at "a constructor value without a settled native layout" state

registerConstructor :: LowerState -> Span -> Text -> Text -> CoreType -> [CoreType] -> Lowered
registerConstructor state at owner label declared inputs
  | ownerKeyOf declared == Just owner
  , Just variants <- sumVariants (contextTypes context) declared
  , Just variant <- find ((== label) . coreVariantName) variants
  , not (coreVariantRecord variant)
  , not (null inputs)
  , length inputs == length (coreVariantFields variant) =
      let labels = map fst (coreVariantFields variant)
          locals = zipWith3 CoreLocal [0 ..] labels inputs
          parameters = [CoreParameter local at | local <- locals]
          entered = startFunction state parameters (Just declared)
          fields = zip labels [CoreExpression at (coreLocalType local) (CoreReadLocal local) | local <- locals]
       in case constructVariant entered at declared label fields of
            (after, Nothing) -> refused state{lowerContext = lowerContext after}
            (after, Just (body, result)) ->
              let kind = CoreFunctionType inputs result
                  added = lowerContext after
                  function = CoreFunction key parameters result (CoreBlock [] (Just body))
                  info = CoreClosureInfo [] label site True False Nothing
                  template = CallableTemplate kind (ConstructorCallable owner label declared)
                  registered
                    | Map.member key (contextClosures added) = added
                    | otherwise = added
                        { contextFunctions = function : contextFunctions added
                        , contextClosures = Map.insert key info (contextClosures added)
                        , contextObservedCallables = Map.insert key template (contextObservedCallables added)
                        }
               in (state{lowerContext = registered}, Just (CoreExpression at kind (CoreClosure key []), kind))
  | otherwise = halt at "a positional constructor with incompatible native parameters" state
 where
  context = lowerContext state
  site = constructorSite owner label
  key = site <> ":" <> Text.pack (show (CoreFunctionType inputs declared))

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
            Just kind -> let (projected, converted) = projectRuntimeValue types current kind value
                          in (projected, (label, converted))
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
    Just value ->
      let actual = coreExpressionType (widen types expected value)
       in if hasRuntimeChoice actual then storageCarrier types expected [actual]
            else if nativeValueType actual then actual else expected
    Nothing -> expected)
