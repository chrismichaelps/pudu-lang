{-| @Pudu.Compiler.Lower.Place — places: a local, then field and index
    steps. Assigning one gives the root a copy of its value with the one field
    or element replaced, as `Eval.Place.storePlace` does. Indices run first,
    root to leaf, then the value, then the store; every failure of the place
    is reported at its root name. A lent place is held the same way: its
    indices run once, where the argument stands, and the store after the call
    reads the root again. -}
module Pudu.Compiler.Lower.Place (HeldPlace (..), holdPlace, lowerPlaceAssignment, readHeld, storeHeld) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Array (takeReceiver)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, lookupLocal, refuse, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

data Step = FieldStep !Text | IndexStep !(Located Expression)

{-| A place whose indices have run: its root, the root's span, each step with
    its index read from a held local, and the type the place holds. -}
data HeldPlace = HeldPlace
  { heldRoot :: !CoreLocal
  , heldSpan :: !Span
  , heldSteps :: ![Either Text CoreExpression]
  , heldType :: !CoreType
  }

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
      (after, Just (core, kind))
        | expressionIsPrintValued core -> halt at "assigning a Result[(), Str] value" after
        | kind /= heldType found && kind /= CoreNeverType -> halt at "an assignment whose value has a different type" after
        | otherwise ->
            let (withHeld, local) = bindLocal after "$assigned" kind
                root = heldRoot found
                replacement = CoreExpression at kind (CoreReadLocal local)
                statements = declarations <> [CoreStatement at (CoreDeclare local core)]
                stops = kind == CoreNeverType || any ((== CoreNeverType) . coreLocalType) [l | CoreStatement _ (CoreDeclare l _) <- declarations]
                blockKind = if stops then CoreNeverType else coreLocalType root
             in (withHeld, Just (CoreStatement at (CoreAssign root (CoreExpression at blockKind
                  (CoreBlockValue (CoreBlock statements (Just (storedValue (types after) found replacement))))))))
 where
  types = contextTypes . lowerContext

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

{-| What a held place holds, read through its root at the root's span. -}
readHeld :: LowerTypes -> HeldPlace -> CoreExpression
readHeld types found = foldl' step (rootRead found) (heldSteps found)
 where
  step current (Left field) = CoreExpression (heldSpan found) (fieldType types current field) (CoreField field current)
  step current (Right index) = CoreExpression (heldSpan found) (elementType current) (CoreArrayMethod ArrayGetAt current [index])

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
