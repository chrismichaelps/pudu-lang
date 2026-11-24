{-| @Pudu.Compiler.Lower.Record — record construction, update, field reads and
    assignment to a field path of a local. -}
module Pudu.Compiler.Lower.Record (lowerRecord, lowerRecordUpdate, lowerField) where

import Data.List (mapAccumL)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.MethodValue (lowerHeldMethodValue)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, refused)
import Pudu.Compiler.Lower.Sum (constructVariant)
import Pudu.Compiler.Lower.Types (LowerTypes, nativeValueType, recordFields, selectedMember, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, isDynamic, joinRuntimeArms, mapRuntimeChoice, missingRuntimeMember, preserveRuntimeResult, projectRuntimeValue, recordWithFields, storageCarrier, widen)
import Pudu.Frontend.Syntax (Expression (..), FieldInit (..), Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

{-| The written fields run in written order. The checker has already matched
    them against the declaration, so the type comes from its facts: a record,
    or a sum when the name is one of its record variants. -}
lowerRecord :: LowerExpression -> LowerState -> Span -> Text -> [Located FieldInit] -> (LowerState, Maybe (CoreExpression, CoreType))
lowerRecord lower state at name fields = case typeForSpan types at of
  Just kind@(CoreRecordType _ _) -> built kind CoreRecord
  Just kind@(CoreSumType _ _)
    | Just variants <- sumVariants types kind
    , any (\variant -> coreVariantName variant == name && coreVariantRecord variant) variants ->
        built kind CoreRecord
  _ -> halt at "this record" state
 where
  types = contextTypes (lowerContext state)
  built kind shape = case lowerFields lower state fields of
    (after, Just given)
      | any ((== CoreNeverType) . coreExpressionType . snd) given -> (after, Just (stopped at (map snd given), CoreNeverType))
      | CoreSumType{} <- kind -> constructVariant after at kind name given
      | otherwise ->
          let fallback = declared kind
              adjusted = case kind of
                CoreRecordType{} -> carryFields types fallback given
                _ -> fallback
              actual = recordWithFields types kind (map snd adjusted)
              (ready, projected) = projectFields types after adjusted given
           in if fieldsMatch adjusted projected
                then (ready, Just (CoreExpression at actual (shape projected), actual))
                else halt at "a record constructor with incompatible field layouts" ready
    (after, Nothing) -> refused after
  declared kind = case kind of
    CoreRecordType _ _ -> maybe [] id (recordFields types kind)
    _ -> concat [coreVariantFields variant | variant <- maybe [] id (sumVariants types kind), coreVariantName variant == name]

{-| The base runs first, then the written fields. -}
lowerRecordUpdate :: LowerExpression -> LowerState -> Span -> Text -> Located Expression -> [Located FieldInit]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerRecordUpdate lower state at name source fields = case lower state source of
  (after, Nothing) -> refused after
  (after, Just (base, CoreNeverType)) -> (after, Just (base, CoreNeverType))
  (after, Just (base, _)) -> case lowerFields lower after fields of
    (final, Nothing) -> refused final
    (final, Just written)
      | any ((== CoreNeverType) . coreExpressionType) (base : map snd written) ->
          (final, Just (stopped at (base : map snd written), CoreNeverType))
      | otherwise ->
          let (withBase, saved) = bindLocal final "" (coreExpressionType base)
              (withFields, retained) = mapAccumL hold withBase written
              declarations = declare saved base : [declare local value | (_, local, value) <- retained]
              replacements = [(label, reading local) | (label, local, _) <- retained]
           in case update replacements withFields (reading saved) of
                (ready, Just value) ->
                  let checked = typeForSpan (contextTypes (lowerContext ready)) at
                      carried = maybe value (`preserveRuntimeResult` value) checked
                      kind = coreExpressionType carried
                   in (ready, Just (CoreExpression at kind (CoreBlockValue (CoreBlock declarations (Just carried))), kind))
                (ready, Nothing) -> refused ready
 where
  hold current (label, value) =
    let (ready, local) = bindLocal current "" (coreExpressionType value)
     in (ready, (label, local, value))
  declare local value = CoreStatement (coreExpressionSpan value) (CoreDeclare local value)
  reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  update written current base
    | Just selected <- mapRuntimeChoice current at kind base (update written) = fmap (fmap fst) selected
    | Just declared <- recordFields types kind =
        let adjusted = carryFields types declared written
            actual = recordWithFields types kind (map snd adjusted)
            applicable = filter (\(label, _) -> label `elem` map fst declared) written
            (ready, projected) = projectFields types current adjusted applicable
         in if fieldsMatch adjusted projected
              then (ready, Just (CoreExpression at actual (CoreRecordUpdate base projected)))
              else halt at "a record update with incompatible field layouts" ready
    | otherwise =
        let message = CoreExpression at CoreTextType
              (CoreTextLiteral (name <> " can only be updated from a record of the same type"))
         in (current, Just (CoreExpression at CoreNeverType (CoreFailText "E7001" Nothing message Nothing)))
   where
    kind = coreExpressionType base
    types = contextTypes (lowerContext current)

carryFields :: LowerTypes -> [(Text, CoreType)] -> [(Text, CoreExpression)] -> [(Text, CoreType)]
carryFields types declared given = [(name, carried name expected) | (name, expected) <- declared]
 where
  carried name expected
    | Just value <- lookup name given
    , let actual = coreExpressionType (widen types expected value)
    , actual /= expected =
        if hasRuntimeChoice actual || hasRuntimeChoice expected
          then storageCarrier types expected [actual]
          else if nativeValueType actual then actual else expected
    | otherwise = expected

projectFields :: LowerTypes -> LowerState -> [(Text, CoreType)] -> [(Text, CoreExpression)]
  -> (LowerState, [(Text, CoreExpression)])
projectFields types state declared = mapAccumL project state
 where
  project current (name, value) = case lookup name declared of
    Just expected -> let (ready, carried) = projectRuntimeValue types current expected value
                     in (ready, (name, carried))
    Nothing -> (current, (name, value))

fieldsMatch :: [(Text, CoreType)] -> [(Text, CoreExpression)] -> Bool
fieldsMatch declared = all (\(name, value) -> lookup name declared == Just (coreExpressionType value))

lowerField :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> (LowerState, Maybe (CoreExpression, CoreType))
lowerField lower state at receiver member = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, _)) -> case select after core of
    (ready, Just value) ->
      let checked = typeForSpan (contextTypes (lowerContext ready)) at
          carried = maybe value (`preserveRuntimeResult` value) checked
       in (ready, Just (carried, coreExpressionType carried))
    (ready, Nothing) -> refused ready
 where
  select current core
    | Just selected <- mapRuntimeChoice current at CoreNeverType core select = fmap (fmap fst) selected
    | Just fieldKind <- recordFields types kind >>= lookup plain =
        (current, Just (CoreExpression at fieldKind (CoreField plain core)))
    | CoreSumType owner _ <- kind, Just variants <- sumVariants types kind =
        let (bound, saved) = bindLocal current "" kind
            held = reading saved
            (ready, arms) = mapAccumL (variantMember held owner) bound variants
            finish choices =
              let result = joinRuntimeArms at CoreNeverType held choices
               in CoreExpression at (coreExpressionType result)
                    (CoreBlockValue (CoreBlock [CoreStatement at (CoreDeclare saved core)] (Just result)))
         in (ready, finish <$> sequence arms)
    | otherwise = fallback current core (missingRuntimeMember at plain core)
   where
    kind = coreExpressionType core
    types = contextTypes (lowerContext current)
  plain = snd (selectedMember member)
  reading local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
  fallback current value failure =
    maybe (current, Just failure) (fmap (fmap fst)) (lowerHeldMethodValue lower current at receiver member value)
  variantMember held owner current variant
    | isDynamic (coreExpressionType held), [(_, payload)] <- members =
        let (bound, local) = bindLocal current "" payload
            (ready, answer) = select bound (reading local)
         in (ready, CoreArm at (CoreVariantPattern tag [CoreBindPattern local]) Nothing <$> answer)
    | coreVariantRecord variant
    , Just fieldKind <- lookup plain members =
        let (ready, local) = bindLocal current "" fieldKind
            pattern' = CoreVariantPattern tag
              [if label == plain then CoreBindPattern local else CoreWildcardPattern | (label, _) <- members]
         in (ready, Just (CoreArm at pattern' Nothing (reading local)))
    | not (coreVariantRecord variant), tag == plain =
        (current, Just (CoreArm at tagged Nothing held))
    | otherwise =
        let reported = if coreVariantRecord variant then owner else tag
            message = CoreExpression at CoreTextType
              (CoreTextLiteral ("no field or method " <> plain <> " on a " <> reported))
            failure = CoreExpression at CoreNeverType (CoreFailText "E7001" Nothing message Nothing)
            (ready, answer) = fallback current held failure
         in (ready, CoreArm at tagged Nothing <$> answer)
   where
    tag = coreVariantName variant
    members = coreVariantFields variant
    tagged = CoreVariantPattern tag (map (const CoreWildcardPattern) members)

lowerFields :: LowerExpression -> LowerState -> [Located FieldInit] -> (LowerState, Maybe [(Text, CoreExpression)])
lowerFields lower state = go state []
 where
  go current done [] = (current, Just (reverse done))
  go current done (Located fieldSpan (FieldInit (Located nameSpan name) written) : rest) =
    let source = maybe (Located nameSpan (NameExpression (name :| []))) id written
     in case lower current source of
          (next, Nothing) -> refused next
          (next, Just (core, _))
            | expressionIsPrintValued core -> halt fieldSpan "a Result[(), Str] field value" next
            | coreExpressionType core == CoreNeverType -> (next, Just (reverse ((name, core) : done)))
            | otherwise -> go next ((name, core) : done) rest

stopped :: Span -> [CoreExpression] -> CoreExpression
stopped at operands = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock
  [CoreStatement (coreExpressionSpan operand) (CoreEvaluate operand) | operand <- operands] Nothing))
