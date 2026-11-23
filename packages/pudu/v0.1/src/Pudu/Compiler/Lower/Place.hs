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
import Pudu.Compiler.Lower.Array (takeReceiver)
import Pudu.Compiler.Lower.Control (blockType, expressionIsPrintValued)
import Pudu.Compiler.Lower.Dynamic (hasRuntimeChoice, projectRuntimeValue, recordWithFields, storageCarrier)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, lookupLocal, observeMutableLayout, refuse, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

data Step = FieldStep !Text | IndexStep !(Located Expression)

{-| A place whose indices have run: its root, the root's span, each step with
    its index read from a held local, and the type the place holds. -}
data HeldPlace = HeldPlace
  { heldRoot :: !CoreLocal
  , heldSpan :: !Span
  , heldSteps :: ![Either Text CoreExpression]
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
      (after, Just (prelude, readHeldAtKeys (contextTypes (lowerContext after)) place, Just place))
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
  heldIndices current done [] = (current, Just (unzip (reverse done)))
  heldIndices current done (key : rest) = case lower current key of
    (next, Just (core, kind))
      | kind == intType || kind == CoreNeverType ->
          let (bound, local) = bindLocal next "" kind
              read' = CoreExpression (locatedSpan key) kind (CoreReadLocal local)
           in heldIndices bound ((CoreStatement (locatedSpan key) (CoreDeclare local core), read') : done) rest
      | otherwise -> (refuse (locatedSpan key) "an index that is not an Int" next, Nothing)
    (next, Nothing) -> (next, Nothing)

place :: Located Expression -> Maybe (Text, Span, [Step])
place (Located spanValue expression) = case expression of
  NameExpression (name :| []) -> Just (name, spanValue, [])
  MemberExpression inner (Located _ field) -> (\(root, rootSpan, path) -> (root, rootSpan, path <> [FieldStep field])) <$> place inner
  IndexExpression inner key -> (\(root, rootSpan, path) -> (root, rootSpan, path <> [IndexStep key])) <$> place inner
  UnaryExpression "*" inner -> place inner
  _ -> Nothing

{-| What a held place holds, read through its root at the root's span: a lent
    argument fails where a store into the same place would. -}
readHeld :: LowerTypes -> HeldPlace -> CoreExpression
readHeld types found = readHeldBy types (const (heldSpan found)) found

{-| What a held receiver holds, each element read at its own key: a receiver
    chosen by an element fails where reading that element as a value does,
    whether its method reads it or changes it. -}
readHeldAtKeys :: LowerTypes -> HeldPlace -> CoreExpression
readHeldAtKeys types = readHeldBy types (\(CoreExpression keyAt _ _) -> keyAt)

readHeldBy :: LowerTypes -> (CoreExpression -> Span) -> HeldPlace -> CoreExpression
readHeldBy types spanOfIndex found = foldl' step (rootRead found) (heldSteps found)
 where
  step current (Left field) = CoreExpression (heldSpan found) (fieldType types current field) (CoreField field current)
  step current (Right index) = CoreExpression (spanOfIndex index) (elementType current) (CoreArrayMethod ArrayGetAt current [index])

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
      let inner = CoreExpression at (elementType current) (CoreArrayMethod ArrayGetAt current [index])
       in CoreExpression at (coreExpressionType current) (CoreArrayMethod ArrayReplaceAt current [index, rebuilt inner rest])

rootRead :: HeldPlace -> CoreExpression
rootRead found = CoreExpression (heldSpan found) (coreLocalType (heldRoot found)) (CoreReadLocal (heldRoot found))

fieldType :: LowerTypes -> CoreExpression -> Text -> CoreType
fieldType types current field = maybe (coreExpressionType current) id
  (recordFields types (coreExpressionType current) >>= lookup field)

elementType :: CoreExpression -> CoreType
elementType current = case coreExpressionType current of
  CoreArrayType held -> held
  other -> other
