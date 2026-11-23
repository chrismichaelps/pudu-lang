{-| @Pudu.Compiler.Lower.Place — places: a local, then field and index
    steps. Assigning one gives the root a copy of its value with the one field
    or element replaced, as `Eval.Place.storePlace` does. Indices run first,
    root to leaf, then the value, then the store; every failure of the place
    is reported at its root name. A lent place is held the same way: its
    indices run once, where the argument stands, and the store after the call
    reads the root again. -}
module Pudu.Compiler.Lower.Place
  ( HeldPlace (..), holdPlace, withMemberReceiver, lowerPlaceAssignment, observeHeldLayout
  , readHeld, readHeldAtKeys, storeHeld ) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments (ArgumentBlame (AtInvocation), argumentFailure, exactPosition)
import Pudu.Compiler.Lower.Array (takeReceiver)
import Pudu.Compiler.Lower.Control (blockType, expressionIsPrintValued)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, mapRuntimeChoice, missingRuntimeMember, preserveRuntimeResult, projectRuntimeValue, recordWithFields, storageCarrier)
import Pudu.Compiler.Lower.Slice (lowerIndexOn)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, lookupLocal, observeMutableLayout, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.IntegerLiteral (IntegerKind (PlatformSigned))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

data Step = FieldStep !Text | IndexStep !(Located Expression)

data HeldIndex = HeldIndex !CoreExpression !(Maybe CoreExpression) !CoreExpression

{-| A place whose indices have run: its root, the root's span, each step with
    its index read from a held local, and the type the place holds. -}
data HeldPlace = HeldPlace
  { heldRoot :: !CoreLocal
  , heldSpan :: !Span
  , heldSteps :: ![Either Text HeldIndex]
  , heldType :: !CoreType
  }

{-| A member receives either a place read or an ordinary value.
    Keep receiver indices outside the selected invocation so their
    effects and transfers occur before member selection. -}
withMemberReceiver :: LowerExpression -> LowerState -> Span -> Located Expression
  -> (LowerState -> CoreExpression -> Maybe HeldPlace -> Lowered) -> Lowered
withMemberReceiver lower state at receiver select = case receive of
  (after, Nothing) -> refused after
  (after, Just (prelude, value, place))
    | blockType prelude (Just value) == CoreNeverType ->
        (after, Just (wrap prelude (value, CoreNeverType)))
    | otherwise -> fmap (fmap (wrap prelude)) (select after value place)
 where
  receive = case holdPlace lower state (locatedSpan receiver) receiver of
    Just (after, Just (prelude, place)) ->
      fmap (fmap (\(value, _) -> (prelude, value, Just place))) (readHeldAtKeys after place)
    _ -> fmap (fmap (\(value, _) -> ([], value, Nothing))) (lower state receiver)
  wrap [] answer = answer
  wrap prelude (answer, kind) =
    (CoreExpression at kind (CoreBlockValue (CoreBlock prelude (Just answer))), kind)

{-| Nothing when the target is not a field or element path from a local, or
    is the local itself; `*value = x` assigns the local through the place. -}
lowerPlaceAssignment :: LowerExpression -> LowerState -> Span -> Located Expression -> Located Expression
  -> Maybe (LowerState, Maybe CoreStatement)
lowerPlaceAssignment lower state at target value = do
  (_, _, steps) <- place target
  case (locatedValue target, steps) of
    (NameExpression _, []) -> Nothing
    _ -> Just ()
  held <- holdPlace lower state at target
  Just $ case held of
    (afterIndices, Nothing) -> refused afterIndices
    (afterIndices, Just (declarations, _))
      | blockType declarations Nothing == CoreNeverType ->
          let stopped = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock declarations Nothing))
           in (afterIndices, Just (CoreStatement at (CoreEvaluate stopped)))
    (afterIndices, Just (declarations, found)) -> case lower afterIndices value of
      (after, Nothing) -> refused after
      (after, Just (replacementValue, _))
        | expressionIsPrintValued core -> halt at "assigning a Result[(), Str] value" after
        | kind /= heldType found && kind /= CoreNeverType ->
            halt at "an assignment whose value has a different type" (observeHeldLayout after found kind)
        | otherwise ->
            let (withHeld, local) = bindLocal ready "$assigned" kind
                root = heldRoot found
                replacement = CoreExpression at kind (CoreReadLocal local)
                statements = declarations <> [CoreStatement at (CoreDeclare local core)]
                stops = kind == CoreNeverType || any ((== CoreNeverType) . coreLocalType) [l | CoreStatement _ (CoreDeclare l _) <- declarations]
                blockKind = if stops then CoreNeverType else coreLocalType root
             in (withHeld, Just (CoreStatement at (CoreAssign root (CoreExpression at blockKind
                  (CoreBlockValue (CoreBlock statements (Just (storedValue (types after) found replacement))))))))
        where
          (ready, core) = projectRuntimeValue (types after) after (heldType found) replacementValue
          kind = coreExpressionType core
 where
  types = contextTypes . lowerContext

observeHeldLayout :: LowerState -> HeldPlace -> CoreType -> LowerState
observeHeldLayout state found actual
  | hasRuntimeChoice actual
  , Just expanded <- grow (coreLocalType root) (heldSteps found) =
      observeMutableLayout state root expanded
  | otherwise = state
 where
  root = heldRoot found
  types = contextTypes (lowerContext state)
  grow checked [] = Just (storageCarrier types checked [actual])
  grow checked (Left field : rest) = do
    fields <- recordFields types checked
    before <- lookup field fields
    expanded <- grow before rest
    pure (recordWithFields types checked [if label == field then expanded else kind | (label, kind) <- fields])
  grow (CoreArrayType member) (Right _ : rest) = CoreArrayType <$> grow member rest
  grow _ _ = Nothing

{-| Resolve a place and run its indices into held locals, in order. Nothing
    when the expression is not a place; a refusal at `at` when it is one
    native code cannot follow. -}
holdPlace :: LowerExpression -> LowerState -> Span -> Located Expression -> Maybe (LowerState, Maybe ([CoreStatement], HeldPlace))
holdPlace lower state at target = do
  (root, rootSpan, steps) <- place target
  local <- lookupLocal state root
  let fieldsOf = recordFields (contextTypes (lowerContext state))
      -- The type the path ends at, through each field and element.
      projected kind remaining = case remaining of
        [] -> Just kind
        FieldStep field : rest -> fieldsOf kind >>= lookup field >>= (`projected` rest)
        IndexStep _ : rest -> case kind of
          CoreArrayType element -> projected element rest
          _ -> Nothing
  Just $ case projected (coreLocalType local) steps of
    Nothing -> halt at "this assignment target" state
    Just kind -> case heldIndices state [] [key | IndexStep key <- steps] of
      (afterIndices, Nothing) -> refused afterIndices
      (afterIndices, Just (declarations, indices)) ->
        (afterIndices, Just (declarations, HeldPlace local rootSpan (paired steps indices) kind))
 where
  paired (FieldStep field : rest) indices = Left field : paired rest indices
  paired (IndexStep _ : rest) (index : later) = Right index : paired rest later
  paired _ _ = []
  heldIndices current done [] = (current, Just (finishIndices done))
  heldIndices current done (key : rest) = case lower current key of
    (next, Just (core, CoreNeverType)) ->
      let (prior, indices) = finishIndices done
          placeholder = outOfBounds (locatedSpan key)
          skipped = replicate (length rest + 1) (HeldIndex placeholder Nothing placeholder)
       in (next, Just (prior <> [CoreStatement (locatedSpan key) (CoreEvaluate core)], indices <> skipped))
    (next, Just (core, _)) ->
      let (ready, prepared) = holdIndex next (locatedSpan key) core
       in heldIndices ready (prepared : done) rest
    (next, Nothing) -> (next, Nothing)
  finishIndices done =
    let ordered = reverse done
     in (concatMap fst ordered, map snd ordered)

holdIndex :: LowerState -> Span -> CoreExpression -> (LowerState, ([CoreStatement], HeldIndex))
holdIndex state at value = case kind of
  CoreIntegerType _ -> (bound, ([declare raw value], HeldIndex (position reading) Nothing reading))
  _ ->
    let (selected, normal) = case mapRuntimeChoice bound at keyType reading (\current held -> (current, Just (classify held))) of
          Just (after, Just (key, _)) -> (after, key)
          _ -> (bound, classify reading)
        (ready, keyLocal) = bindLocal selected "" keyType
        saved = CoreExpression at keyType (CoreReadLocal keyLocal)
        valid = CoreExpression at CoreBoolType (CoreTupleIndex 0 saved)
        normalized = CoreExpression at intType (CoreTupleIndex 1 saved)
     in (ready, ([declare raw value, declare keyLocal normal], HeldIndex normalized (Just valid) reading))
 where
  kind = coreExpressionType value
  (bound, raw) = bindLocal state "" kind
  reading = CoreExpression at kind (CoreReadLocal raw)
  declare local expression = CoreStatement at (CoreDeclare local expression)
  keyType = CoreTupleType [CoreBoolType, intType]
  classify held =
    let (integer, normalized) = case coreExpressionType held of
          CoreIntegerType _ -> (True, position held)
          _ -> (False, outOfBounds at)
        flag = CoreExpression at CoreBoolType (CoreBoolLiteral integer)
     in CoreExpression at keyType (CoreTuple [flag, normalized])
  position held
    | coreExpressionType held == intType = held
    | otherwise =
        let (fits, narrow) = exactPosition at held
         in CoreExpression at intType (CoreIfValue fits (CoreBlock [] (Just narrow)) (outOfBounds at))

outOfBounds :: Span -> CoreExpression
outOfBounds at = CoreExpression at intType (CoreIntegerLiteral PlatformSigned (-1))

useIndex :: Span -> Text -> HeldIndex -> CoreExpression -> (CoreExpression -> CoreExpression) -> CoreExpression
useIndex _ _ (HeldIndex position Nothing _) _ use = use position
useIndex at message (HeldIndex position (Just valid) _) receiver use =
  let answer = use position
      failure = argumentFailure AtInvocation at "E7001" message
      checked = CoreStatement (coreExpressionSpan receiver) (CoreEvaluate receiver)
      failed = CoreExpression at CoreNeverType (CoreBlockValue (CoreBlock [checked] (Just failure)))
   in CoreExpression at (coreExpressionType answer) (CoreIfValue valid (CoreBlock [] (Just answer)) failed)

place :: Located Expression -> Maybe (Text, Span, [Step])
place (Located spanValue expression) = case expression of
  NameExpression (name :| []) -> Just (name, spanValue, [])
  MemberExpression inner (Located _ field) -> (\(root, rootSpan, path) -> (root, rootSpan, path <> [FieldStep field])) <$> place inner
  IndexExpression inner key -> (\(root, rootSpan, path) -> (root, rootSpan, path <> [IndexStep key])) <$> place inner
  UnaryExpression "*" inner -> place inner
  _ -> Nothing

{-| What a held place holds, read through its root at the root's span: a lent
    argument fails where a store into the same place would. -}
readHeld :: LowerState -> HeldPlace -> Lowered
readHeld state found = readHeldBy (const (heldSpan found)) state found

{-| What a held receiver holds, each element read at its own key: a receiver
    chosen by an element fails where reading that element as a value does,
    whether its method reads it or changes it. -}
readHeldAtKeys :: LowerState -> HeldPlace -> Lowered
readHeldAtKeys = readHeldBy coreExpressionSpan

readHeldBy :: (CoreExpression -> Span) -> LowerState -> HeldPlace -> Lowered
readHeldBy spanOfIndex state found =
  fmap (fmap preserve) (foldl' step initial (heldSteps found))
 where
  types = contextTypes (lowerContext state)
  root = rootRead found
  initial = (state, Just (root, coreExpressionType root))
  preserve (value, _) =
    let carried = preserveRuntimeResult (heldType found) value
     in (carried, coreExpressionType carried)
  step (current, Nothing) _ = refused current
  step previous@(_, Just (_, CoreNeverType)) _ = previous
  step (current, Just (value, _)) (Left field) = selectField current value field
  step (current, Just (value, _)) (Right (HeldIndex _ _ key)) =
    lowerIndexOn current (spanOfIndex key) value key
  selectField current value field
    | Just selected <- mapRuntimeChoice current (heldSpan found) CoreNeverType value
        (\ready held -> fmap (fmap fst) (selectField ready held field)) = selected
    | Just kind <- recordFields types (coreExpressionType value) >>= lookup field =
        (current, Just (CoreExpression (heldSpan found) kind (CoreField field value), kind))
    | otherwise =
        (current, Just (missingRuntimeMember (heldSpan found) field value, CoreNeverType))

{-| Store a value through a held place, reading the root as it is now. -}
storeHeld :: LowerTypes -> Span -> HeldPlace -> CoreExpression -> CoreStatement
storeHeld types at found replacement = CoreStatement at (CoreAssign (heldRoot found) (storedValue types found replacement))

{-| The root's new value: a copy with the place replaced. Only a lone
    element step leaves nothing else reading the root, so only then may the
    store take it. -}
storedValue :: LowerTypes -> HeldPlace -> CoreExpression -> CoreExpression
storedValue types found replacement = case heldSteps found of
  [] -> takeReceiver root replacement
  [Right _] -> takeReceiver root whole
  _ -> whole
 where
  root = heldRoot found
  at = heldSpan found
  whole = rebuilt (rootRead found) (heldSteps found)
  rebuilt current remaining = case remaining of
    [] -> replacement
    Left field : rest ->
      let inner = CoreExpression at (fieldType types current field) (CoreField field current)
       in CoreExpression at (coreExpressionType current) (CoreRecordUpdate current [(field, rebuilt inner rest)])
    Right index : rest ->
      let message = "an element of a " <> coreStaticRuntimeKind (coreExpressionType current) <> " cannot be assigned"
       in useIndex at message index current $ \key ->
            let inner = CoreExpression at (elementType current) (CoreArrayMethod ArrayGetAt current [key])
             in CoreExpression at (coreExpressionType current) (CoreArrayMethod ArrayReplaceAt current [key, rebuilt inner rest])

rootRead :: HeldPlace -> CoreExpression
rootRead found = CoreExpression (heldSpan found) (coreLocalType (heldRoot found)) (CoreReadLocal (heldRoot found))

fieldType :: LowerTypes -> CoreExpression -> Text -> CoreType
fieldType types current field = maybe (coreExpressionType current) id
  (recordFields types (coreExpressionType current) >>= lookup field)

elementType :: CoreExpression -> CoreType
elementType current = case coreExpressionType current of
  CoreArrayType held -> held
  other -> other
