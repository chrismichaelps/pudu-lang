{-| @Type.Check.Subscript — `[]` on declared types through `Std.Index`, and the refusal of several indices on a built-in -}
module Pudu.Type.Check.Subscript
  ( builtinMultiIndex
  , copiedElement
  , indexedByMember
  , readThroughIndex
  , subscriptAssignment
  , subscriptType
  , subscriptWrite
  ) where

import qualified Data.Text as Text
import Pudu.Semantic.Prelude (wiredInTypeNames)
import Pudu.Source (Span)
import Pudu.Type.Check.Method (methodScheme)
import Pudu.Type.Check.Rule (elementType, instantiate)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Expression (..))
import Pudu.Type.Env (Checker, SubscriptKey (..), lookupRecordedExpression, recordSubscript, report)
import Pudu.Type.Unify (unify, zonk)
import Pudu.Type.Value (NominalId (..), Type (..), renderType)

{-| Whether `[]` on a value of this type calls the type's `index` member: a
    declared type or a type parameter. A built-in keeps its own indexing. -}
indexedByMember :: Type -> Bool
indexedByMember typeValue = case typeValue of
  ReferenceTypeValue _ target -> indexedByMember target
  NominalType (NominalId Nothing name) _ -> name `notElem` wiredInTypeNames
  NominalType _ _ -> True
  RigidType _ -> True
  _ -> False

throughReference :: Type -> Type
throughReference typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReference target
  other -> other

{-| The type of `target[i]` or `target[i, j, ...]` through `index`. A type with
    no `index` member is reported as one that cannot be indexed, exactly as a
    built-in that cannot be. -}
subscriptType :: Span -> Type -> [(Span, Type)] -> Checker Type
subscriptType spanValue target indices = do
  let receiver = throughReference target
  member <- memberType spanValue receiver "index"
  case member of
    Nothing -> elementType spanValue Nothing receiver
    Just ErrorType -> pure ErrorType
    Just (FunctionTypeValue _ [self, key] result) -> do
      _ <- unify spanValue (ReferenceTypeValue False receiver) self
      shape <- keyShape spanValue receiver key indices
      case shape of
        Just found -> recordSubscript spanValue found >> pure result
        Nothing -> pure ErrorType
    Just other -> do
      report "E3095" spanValue
        ("the index of a " <> renderType receiver <> " is " <> renderType other)
        (Just "index must be fn index(self: &Self, key: K) -> V, as Std.Index.Index declares it")
      pure ErrorType

{-| Several indices on a built-in type, which takes one. -}
builtinMultiIndex :: Span -> Type -> Int -> Checker Type
builtinMultiIndex spanValue target count = do
  resolved <- zonk target
  case throughReference resolved of
    ErrorType -> pure ErrorType
    VariableType _ -> pure ErrorType
    held -> do
      report "E3094" spanValue
        ("a " <> renderType held <> " takes one index, and this gives it " <> Text.pack (show count))
        ( Just
            ( "a[i, j] is one indexing with two indices; to index an element again, write a[i][j], "
                <> "or implement Std.Index.Index for a type that takes several"
            )
        )
      pure ErrorType

{-| `target[...] = item` through `setIndex`, whose key takes the same indices
    as the read did and whose value takes the item. -}
subscriptWrite :: Span -> Type -> [(Span, Type)] -> Type -> Checker ()
subscriptWrite spanValue target indices item = do
  let receiver = throughReference target
  member <- memberType spanValue receiver "setIndex"
  case member of
    Nothing ->
      report "E3097" spanValue
        ("a " <> renderType receiver <> " can be read through [] but not assigned through it")
        (Just "implement Std.Index.IndexMut for it, which is setIndex(self: &mut Self, key: K, value: V)")
    Just ErrorType -> pure ()
    Just (FunctionTypeValue _ [self, key, value] _) -> do
      _ <- unify spanValue (ReferenceTypeValue True receiver) self
      _ <- keyShape spanValue receiver key indices
      _ <- unify spanValue value item
      pure ()
    Just other ->
      report "E3095" spanValue
        ("the setIndex of a " <> renderType receiver <> " is " <> renderType other)
        (Just "setIndex must be fn setIndex(self: &mut Self, key: K, value: V) -> (), as Std.Index.IndexMut declares it")

{-| `whole = item` where `whole` reads `target` through `[]`, typed from what
    checking recorded for the target, the indices and the element. -}
subscriptAssignment :: Span -> Located Expression -> Located Expression -> [Located Expression] -> Checker ()
subscriptAssignment spanValue whole target indices = do
  base <- recorded target
  indexTypes <- mapM recorded indices
  item <- recorded whole
  case (base, sequence indexTypes, item) of
    (Just held, Just found, Just element) ->
      subscriptWrite spanValue held (zip (map locatedSpan indices) found) element
    _ -> pure ()

{-| Whether an expression reads through `[]` on a type implementing
    `Std.Index`, which answers a value rather than naming a place. -}
readThroughIndex :: Located Expression -> Checker Bool
readThroughIndex (Located _ expression) = case expression of
  IndexExpression target _ -> member target
  MultiIndexExpression target _ -> member target
  _ -> pure False
 where
  member target = maybe False indexedByMember <$> recorded target

copiedElement :: Span -> Checker Bool
copiedElement spanValue = do
  report "E3096" spanValue "an element read through [] is a copy, so it cannot be changed in place"
    (Just "assign the whole element, as value[i, j] = updated, or give the type a method that changes it")
  pure False

recorded :: Located Expression -> Checker (Maybe Type)
recorded (Located spanValue _) = lookupRecordedExpression spanValue >>= traverse zonk

memberType :: Span -> Type -> Text.Text -> Checker (Maybe Type)
memberType spanValue receiver name = do
  found <- methodScheme spanValue receiver name
  traverse (instantiate spanValue) found

{-| How the indices form the member's key. A key of `Array[I]` holds the
    indices as an array, one index included, unless that one index is already
    an array. Otherwise one index is the key, and several are a tuple of exactly
    that many members; a key not yet settled becomes the tuple. -}
keyShape :: Span -> Type -> Type -> [(Span, Type)] -> Checker (Maybe SubscriptKey)
keyShape spanValue receiver key indices = case indices of
  [(indexSpan, indexType)] -> do
    resolvedKey <- zonk key
    resolvedIndex <- zonk indexType
    case (resolvedKey, resolvedIndex) of
      (NominalType (NominalId Nothing "Array") [element], held) | not (isArray held) -> do
        _ <- unify indexSpan element indexType
        pure (Just SubscriptArray)
      _ -> do
        _ <- unify indexSpan key indexType
        pure (Just SubscriptSingle)
  _ -> do
    resolved <- zonk key
    case resolved of
      ErrorType -> pure Nothing
      TupleTypeValue members
        | length members == count -> do
            mapM_ (\(member, (indexSpan, indexType)) -> unify indexSpan member indexType) (zip members indices)
            pure (Just SubscriptTuple)
        | otherwise -> refuse
            ( "a " <> renderType receiver <> " is indexed by " <> Text.pack (show (length members))
                <> " indices, and this gives it " <> Text.pack (show count) )
      NominalType (NominalId Nothing "Array") [element] -> do
        mapM_ (\(indexSpan, indexType) -> unify indexSpan element indexType) indices
        pure (Just SubscriptArray)
      VariableType _ -> do
        _ <- unify spanValue resolved (TupleTypeValue (map snd indices))
        pure (Just SubscriptTuple)
      other -> refuse
        ( "a " <> renderType receiver <> " is indexed by one " <> renderType other
            <> ", and this gives it " <> Text.pack (show count) <> " indices" )
 where
  count = length indices
  isArray held = case held of
    NominalType (NominalId Nothing "Array") _ -> True
    _ -> False
  refuse message = do
    report "E3095" spanValue message
      (Just "write one index per member of the key's tuple, or give the type a key of Array[I]")
    pure Nothing
