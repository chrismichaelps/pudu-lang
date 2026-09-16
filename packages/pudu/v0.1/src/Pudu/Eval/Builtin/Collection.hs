{-| @Program.Eval.Builtin.Collection — map and set method dispatch and constructors -}
module Pudu.Eval.Builtin.Collection
  ( callMapMethod
  , callMapOf
  , callSetMethod
  , callSetOf
  , optionOf
  , pairOf
  , unorderableKey
  ) where

import Data.Foldable (toList)
import Data.Text (Text)

import Pudu.Eval.Env (Evaluator (..), abortAt)
import Pudu.Eval.Keyed
  ( mapContainsKey
  , mapEntriesArray
  , mapFromEntries
  , mapGet
  , mapInsert
  , mapKeysArray
  , mapMerge
  , mapRemove
  , mapSize
  , mapValuesArray
  , setContains
  , setDifference
  , setFromMembers
  , setInsert
  , setIntersect
  , setIsEmpty
  , setMembersArray
  , setRemove
  , setSize
  , setUnion
  )
import Pudu.Eval.Order (comparableValue)
import Pudu.Eval.Render (valueKind)
import Pudu.Eval.Value
  ( MapMethod (..)
  , SetMethod (..)
  , Value (..)
  , intOf
  , mapMethodName
  , setMethodName
  )
import Pudu.Source (Span)

{-| Build a map from an array of key and value pairs.
    A key must be comparable: a map keeps its entries in key order so that two
    maps built differently with the same entries are the same map, and a
    function has no order. The refusal is a diagnostic rather than a silent
    fallback to insertion order, which would make equality depend on how a map
    was assembled. -}
callMapOf :: Span -> [Value] -> Evaluator Value
callMapOf spanValue arguments = case arguments of
  [ArrayValue members] -> do
    entries <- mapM (pairOf spanValue) (toList members)
    case filter (not . comparableValue . fst) entries of
      (offender, _) : _ ->
        abortAt (Just spanValue) "E7008"
          ("a " <> valueKind offender <> " cannot be a map key")
          (Just "use a value the language can order, such as text, a number, or a tuple of those")
      [] -> pure (mapFromEntries entries)
  _ -> abortAt (Just spanValue) "E7012" "mapOf expects one array of pairs" Nothing

pairOf :: Span -> Value -> Evaluator (Value, Value)
pairOf spanValue value = case value of
  TupleValue [key, held] -> pure (key, held)
  _ -> abortAt (Just spanValue) "E7012" "mapOf expects an array of pairs" Nothing

{-| Build a set from an array of members, with the same ordering requirement a
    map places on its keys and for the same reason. -}
callSetOf :: Span -> [Value] -> Evaluator Value
callSetOf spanValue arguments = case arguments of
  [ArrayValue members] ->
    case filter (not . comparableValue) (toList members) of
      offender : _ ->
        abortAt (Just spanValue) "E7008"
          ("a " <> valueKind offender <> " cannot be a set member")
          (Just "use a value the language can order, such as text, a number, or a tuple of those")
      [] -> pure (setFromMembers (toList members))
  _ -> abortAt (Just spanValue) "E7012" "setOf expects one array" Nothing

{-| Apply a built-in map method. Every one answers with a new value. -}
callMapMethod :: Span -> MapMethod -> Value -> [Value] -> Evaluator Value
callMapMethod spanValue method receiver arguments = case (method, arguments) of
  (MapSize, []) -> pure (intOf (fromIntegral (mapSize receiver)))
  (MapIsEmpty, []) -> pure (BoolValue (mapSize receiver == 0))
  (MapGet, [key]) -> pure (optionOf (mapGet receiver key))
  (MapContainsKey, [key]) -> pure (BoolValue (mapContainsKey receiver key))
  (MapInsert, [key, held])
    | comparableValue key -> pure (mapInsert receiver key held)
    | otherwise -> unorderableKey spanValue key "map key"
  (MapRemove, [key]) -> pure (mapRemove receiver key)
  (MapKeys, []) -> pure (mapKeysArray receiver)
  (MapValues, []) -> pure (mapValuesArray receiver)
  (MapEntries, []) ->
    pure (mapEntriesArray receiver)
  (MapMerge, [other@(MapValue _)]) -> pure (mapMerge receiver other)
  _ ->
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> mapMethodName method) Nothing

{-| Apply a built-in set method. -}
callSetMethod :: Span -> SetMethod -> Value -> [Value] -> Evaluator Value
callSetMethod spanValue method receiver arguments = case (method, arguments) of
  (SetSize, []) -> pure (intOf (fromIntegral (setSize receiver)))
  (SetIsEmpty, []) -> pure (BoolValue (setIsEmpty receiver))
  (SetContains, [value]) -> pure (BoolValue (setContains receiver value))
  (SetInsert, [value])
    | comparableValue value -> pure (setInsert receiver value)
    | otherwise -> unorderableKey spanValue value "set member"
  (SetRemove, [value]) -> pure (setRemove receiver value)
  (SetToArray, []) -> pure (setMembersArray receiver)
  (SetUnion, [other@(SetValue _)]) -> pure (setUnion receiver other)
  (SetIntersect, [other@(SetValue _)]) -> pure (setIntersect receiver other)
  (SetDifference, [other@(SetValue _)]) -> pure (setDifference receiver other)
  _ ->
    abortAt (Just spanValue) "E7012"
      ("wrong arguments for " <> setMethodName method) Nothing

unorderableKey :: Span -> Value -> Text -> Evaluator Value
unorderableKey spanValue value described =
  abortAt (Just spanValue) "E7008"
    ("a " <> valueKind value <> " cannot be a " <> described)
    (Just "use a value the language can order, such as text, a number, or a tuple of those")

{-| A lookup that may find nothing, as the language's own absence carrier. -}
optionOf :: Maybe Value -> Value
optionOf found = case found of
  Just value -> VariantValue "Some" [value]
  Nothing -> VariantValue "None" []
