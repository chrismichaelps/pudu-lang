{-| @Pudu.Compiler.Lower.Record — record construction, update, field reads and
    assignment to a field path of a local. -}
module Pudu.Compiler.Lower.Record (lowerRecord, lowerRecordUpdate, lowerField, lowerFieldAssignment) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, lookupLocal, refused)
import Pudu.Compiler.Lower.Types (recordFields, sumVariants, typeForSpan)
import Pudu.Core
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
        built kind (CoreConstruct name)
  _ -> halt at "this record" state
 where
  types = contextTypes (lowerContext state)
  built kind shape = case lowerFields lower state fields of
    (after, Just written)
      | any ((== CoreNeverType) . coreExpressionType . snd) written -> (after, Just (stopped at (map snd written), CoreNeverType))
      | otherwise -> (after, Just (CoreExpression at kind (shape written), kind))
    (after, Nothing) -> refused after

{-| The base runs first, then the written fields. -}
lowerRecordUpdate :: LowerExpression -> LowerState -> Span -> Located Expression -> [Located FieldInit]
  -> (LowerState, Maybe (CoreExpression, CoreType))
lowerRecordUpdate lower state at source fields = case lower state source of
  (after, Nothing) -> refused after
  (after, Just (base, kind)) -> case lowerFields lower after fields of
    (final, Nothing) -> refused final
    (final, Just written)
      | any ((== CoreNeverType) . coreExpressionType) (base : map snd written) ->
          (final, Just (stopped at (base : map snd written), CoreNeverType))
      | CoreRecordType _ _ <- kind -> (final, Just (CoreExpression at kind (CoreRecordUpdate base written), kind))
      | otherwise -> halt at ("updating a " <> coreTypeName kind <> " value") final

lowerField :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> (LowerState, Maybe (CoreExpression, CoreType))
lowerField lower state at receiver member = case lower state receiver of
  (after, Nothing) -> refused after
  (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
  (after, Just (core, kind@(CoreRecordType _ _))) -> case recordFields (contextTypes (lowerContext after)) kind >>= lookup member of
    Just fieldKind -> (after, Just (CoreExpression at fieldKind (CoreField member core), fieldKind))
    Nothing -> halt at ("the member '" <> member <> "'") after
  (after, Just (_, kind)) -> halt at ("member access on " <> coreTypeName kind) after

{-| `local.a.b = value`: the place is a local, so resolving it has no effect,
    and the value runs next. The record stored is the local's value as it is
    after the value ran (the value may itself assign the local), with that
    path replaced; the evaluator stores the same way. -}
lowerFieldAssignment :: LowerExpression -> LowerState -> Span -> Located Expression -> Located Expression
  -> Maybe (LowerState, Maybe CoreStatement)
lowerFieldAssignment lower state at target value = do
  (root, path) <- place (locatedValue target)
  local <- lookupLocal state root
  let fieldsOf = recordFields (contextTypes (lowerContext state))
      -- The type at each step of the path, ending with the assigned field's.
      projections kind steps = case steps of
        [] -> Just [kind]
        field : rest -> do
          next <- fieldsOf kind >>= lookup field
          (kind :) <$> projections next rest
      rebuilt held steps replacement = go (CoreExpression at (coreLocalType held) (CoreReadLocal held)) steps
       where
        go _ [] = replacement
        go current (field : rest) =
          let kind = coreExpressionType current
              inner = case fieldsOf kind >>= lookup field of
                Just fieldKind -> CoreExpression at fieldKind (CoreField field current)
                Nothing -> current
           in CoreExpression at kind (CoreRecordUpdate current [(field, go inner rest)])
  Just $ case (projections (coreLocalType local) path, lower state value) of
    (_, (after, Nothing)) -> refused after
    (Nothing, (after, _)) -> halt at "this assignment target" after
    (Just kinds, (after, Just (core, kind)))
      | expressionIsPrintValued core -> halt at "assigning a Result[(), Str] value" after
      | kind /= last kinds && kind /= CoreNeverType -> halt at "an assignment whose value has a different type" after
      | otherwise ->
          let (withHeld, held) = bindLocal after "$assigned" kind
              value' = CoreExpression at kind (CoreReadLocal held)
              block = CoreBlock [CoreStatement at (CoreDeclare held core)] (Just (rebuilt local path value'))
              blockKind = if kind == CoreNeverType then CoreNeverType else coreLocalType local
           in (withHeld, Just (CoreStatement at (CoreAssign local (CoreExpression at blockKind (CoreBlockValue block)))))
 where
  place expression = case expression of
    MemberExpression (Located _ inner) (Located _ field) -> do
      (root, path) <- place inner
      Just (root, path <> [field])
    NameExpression (name :| []) -> Just (name, [])
    _ -> Nothing

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
