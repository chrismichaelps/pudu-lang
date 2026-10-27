{-| @Pudu.Compiler.Lower.Place — assignment to a place: a local, then field
    and index steps. The root is given a copy of its value with the one field
    or element replaced, as `Eval.Place.storePlace` does. Indices run first,
    root to leaf, then the value, then the store; every failure of the place
    is reported at its root name. -}
module Pudu.Compiler.Lower.Place (lowerPlaceAssignment) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import Pudu.Compiler.Lower.Array (takeReceiver)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, lookupLocal, refuse, refused)
import Pudu.Compiler.Lower.Types (recordFields)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression (..), Located (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))

data Step = FieldStep !Text | IndexStep !(Located Expression)

{-| Nothing when the target is not a field or element path from a local. -}
lowerPlaceAssignment :: LowerExpression -> LowerState -> Span -> Located Expression -> Located Expression
  -> Maybe (LowerState, Maybe CoreStatement)
lowerPlaceAssignment lower state at target value = do
  (root, rootSpan, steps@(_ : _)) <- place target
  local <- lookupLocal state root
  let fieldsOf = recordFields (contextTypes (lowerContext state))
      -- The type at each step of the path, ending with the assigned place's.
      projections kind remaining = case remaining of
        [] -> Just [kind]
        FieldStep field : rest -> do
          next <- fieldsOf kind >>= lookup field
          (kind :) <$> projections next rest
        IndexStep _ : rest -> case kind of
          CoreArrayType element -> (kind :) <$> projections element rest
          _ -> Nothing
      expression kind shape = CoreExpression rootSpan kind shape
      rebuilt current remaining indices replacement = case (remaining, indices) of
        ([], _) -> replacement
        (FieldStep field : rest, _) ->
          let kind = coreExpressionType current
              inner = case fieldsOf kind >>= lookup field of
                Just fieldKind -> CoreExpression rootSpan fieldKind (CoreField field current)
                Nothing -> current
           in expression kind (CoreRecordUpdate current [(field, rebuilt inner rest indices replacement)])
        (IndexStep _ : rest, index : later) ->
          let kind = coreExpressionType current
              element = case kind of
                CoreArrayType held -> held
                other -> other
              inner = expression element (CoreArrayMethod ArrayGetAt current [index])
           in expression kind (CoreArrayMethod ArrayReplaceAt current [index, rebuilt inner rest later replacement])
        (IndexStep _ : _, []) -> replacement
  Just $ case projections (coreLocalType local) steps of
    Nothing -> halt at "this assignment target" state
    Just kinds -> case heldIndices state [] [key | IndexStep key <- steps] of
      (afterIndices, Nothing) -> refused afterIndices
      (afterIndices, Just (declarations, indices)) -> case lower afterIndices value of
        (after, Nothing) -> refused after
        (after, Just (core, kind))
          | expressionIsPrintValued core -> halt at "assigning a Result[(), Str] value" after
          | kind /= last kinds && kind /= CoreNeverType -> halt at "an assignment whose value has a different type" after
          | otherwise ->
              let (withHeld, held) = bindLocal after "$assigned" kind
                  replacement = CoreExpression at kind (CoreReadLocal held)
                  whole = rebuilt (CoreExpression rootSpan (coreLocalType local) (CoreReadLocal local)) steps indices replacement
                  -- Only a lone element step leaves nothing else reading the
                  -- local, so only then may the store take it.
                  stored = case steps of
                    [IndexStep _] -> takeReceiver local whole
                    _ -> whole
                  statements = declarations <> [CoreStatement at (CoreDeclare held core)]
                  stops = kind == CoreNeverType || any ((== CoreNeverType) . coreLocalType) [l | CoreStatement _ (CoreDeclare l _) <- declarations]
                  blockKind = if stops then CoreNeverType else coreLocalType local
               in (withHeld, Just (CoreStatement at (CoreAssign local (CoreExpression at blockKind (CoreBlockValue (CoreBlock statements (Just stored)))))))
 where
  place (Located spanValue expression) = case expression of
    NameExpression (name :| []) -> Just (name, spanValue, [])
    MemberExpression inner (Located _ field) -> (\(root, rootSpan, path) -> (root, rootSpan, path <> [FieldStep field])) <$> place inner
    IndexExpression inner key -> (\(root, rootSpan, path) -> (root, rootSpan, path <> [IndexStep key])) <$> place inner
    _ -> Nothing
  heldIndices current done [] = (current, Just (unzip (reverse done)))
  heldIndices current done (key : rest) = case lower current key of
    (next, Just (core, kind))
      | kind == intType || kind == CoreNeverType ->
          let (bound, local) = bindLocal next "" kind
              read' = CoreExpression (locatedSpan key) kind (CoreReadLocal local)
           in heldIndices bound ((CoreStatement (locatedSpan key) (CoreDeclare local core), read') : done) rest
      | otherwise -> (refuse (locatedSpan key) "an index that is not an Int" next, Nothing)
    (next, Nothing) -> (next, Nothing)
