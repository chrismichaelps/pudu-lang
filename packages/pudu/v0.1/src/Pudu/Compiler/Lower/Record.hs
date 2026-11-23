{-| @Pudu.Compiler.Lower.Record — record construction, update, field reads and
    assignment to a field path of a local. -}
module Pudu.Compiler.Lower.Record (lowerRecord, lowerRecordUpdate, lowerField) where

import Data.List (mapAccumL)
import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), halt, refused)
import Pudu.Compiler.Lower.Sum (constructVariant)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, mapRuntimeChoice, projectRuntimeValue, recordWithFields, storageCarrier, widen)
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
lowerRecordUpdate :: LowerExpression -> LowerState -> Span -> Located Expression -> [Located FieldInit]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerRecordUpdate lower state at source fields = case lower state source of
  (after, Nothing) -> refused after
  (after, Just (base, CoreNeverType)) -> (after, Just (base, CoreNeverType))
  (after, Just (base, _)) -> case lowerFields lower after fields of
    (final, Nothing) -> refused final
    (final, Just written)
      | any ((== CoreNeverType) . coreExpressionType) (base : map snd written) ->
          (final, Just (stopped at (base : map snd written), CoreNeverType))
      | otherwise -> case update written final base of
          (ready, Just value) -> (ready, Just (value, coreExpressionType value))
          (ready, Nothing) -> refused ready
 where
  update written current base
    | Just selected <- mapRuntimeChoice current at kind base (update written) = fmap (fmap fst) selected
    | Just declared <- recordFields types kind =
        let adjusted = carryFields types declared written
            actual = recordWithFields types kind (map snd adjusted)
            (ready, projected) = projectFields types current adjusted written
         in if fieldsMatch adjusted projected
              then (ready, Just (CoreExpression at actual (CoreRecordUpdate base projected)))
              else halt at "a record update with incompatible field layouts" ready
    | otherwise = halt at ("updating a " <> coreTypeName kind <> " value") current
   where
    kind = coreExpressionType base
    types = contextTypes (lowerContext current)

carryFields :: LowerTypes -> [(Text, CoreType)] -> [(Text, CoreExpression)] -> [(Text, CoreType)]
carryFields types declared given = [(name, carried name expected) | (name, expected) <- declared]
 where
  carried name expected
    | Just value <- lookup name given
    , let actual = coreExpressionType (widen types expected value)
    , actual /= expected
    , hasRuntimeChoice actual || hasRuntimeChoice expected =
        storageCarrier types expected [actual]
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
    (ready, Just value) -> (ready, Just (value, coreExpressionType value))
    (ready, Nothing) -> refused ready
 where
  select current core
    | Just selected <- mapRuntimeChoice current at CoreNeverType core select = fmap (fmap fst) selected
    | CoreRecordType{} <- kind = case recordFields (contextTypes (lowerContext current)) kind >>= lookup member of
        Just fieldKind -> (current, Just (CoreExpression at fieldKind (CoreField member core)))
        Nothing -> halt at ("the member '" <> member <> "'") current
    | otherwise = halt at ("member access on " <> coreTypeName kind) current
   where
    kind = coreExpressionType core

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
