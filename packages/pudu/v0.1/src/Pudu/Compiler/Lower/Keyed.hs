{-| @Pudu.Compiler.Lower.Keyed — maps and sets: `mapOf`, `setOf`, `#{...}`
    and their methods, as `Eval.Builtin.Collection` answers them. Arguments run
    before the receiver. A key whose type could hold a function is tested
    before it is stored, and one that can't be ordered stops the program with
    E7008, as `comparableValue` decides. -}
module Pudu.Compiler.Lower.Keyed (lowerKeyedBuilder, lowerSetLiteral, lowerKeyedMethod) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (collect, stopped, stops)
import Pudu.Compiler.Lower.Control (popLoop, pushLoop)
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type LowerExpression = LowerState -> Located Expression -> (LowerState, Maybe (CoreExpression, CoreType))
type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| `mapOf(pairs)` or `setOf(members)`: the array runs, every key is checked
    once all are in hand, then the tree is built. -}
lowerKeyedBuilder :: LowerExpression -> LowerState -> Span -> Text -> [Located Expression] -> Lowered
lowerKeyedBuilder lower state at name arguments = case (typeForSpan types at, arguments) of
  (Just kind, [argument]) | Just (keyOf, described) <- builderOf kind -> case lower state argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, CoreArrayType _)) -> built after at kind keyOf described core
    (after, Just _) -> halt (locatedSpan argument) ("a call to " <> name <> " with this argument") after
  _ -> halt at ("this call to " <> name) state
 where
  types = contextTypes (lowerContext state)
  builderOf kind = case (name, kind) of
    ("mapOf", CoreMapType key _) -> Just (\item -> CoreExpression at key (CoreTupleIndex 0 item), "map key")
    ("setOf", CoreSetType _) -> Just (id, "set member")
    _ -> Nothing

{-| `#{a, b}`: every member runs in order, and only then are they checked. -}
lowerSetLiteral :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerSetLiteral lower state at members = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind@(CoreSetType member) -> case collect lower state members of
    (after, Nothing) -> refused after
    (after, Just cores)
      | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
      | all ((== member) . coreExpressionType) cores ->
          built after at kind id "set member" (CoreExpression at (CoreArrayType member) (CoreArray cores))
      | otherwise -> halt at "a set literal whose members have different types" after
  _ -> halt at "a set without a native member type" state

{-| A built-in map or set method when the receiver is one; Nothing otherwise. -}
lowerKeyedMethod :: LowerExpression -> LowerState -> Span -> Located Expression -> Text -> [Located Expression] -> Maybe Lowered
lowerKeyedMethod lower state at receiver member arguments = case typeForSpan types (locatedSpan receiver) of
  Just kind@(CoreMapType key value) -> Just (dispatch kind key (mapMethods kind key value))
  Just kind@(CoreSetType key) -> Just (dispatch kind key (setMethods kind key))
  _ -> Nothing
 where
  types = contextTypes (lowerContext state)
  dispatch kind key table = case lookup member table of
    Nothing -> halt at ("the " <> collectionName kind <> " method '" <> member <> "'") state
    Just (parameters, result, shape)
      | length parameters /= length arguments -> halt at ("a call to " <> member <> " with this many arguments") state
      | otherwise -> case collect lower state (arguments <> [receiver]) of
          (after, Nothing) -> refused after
          (after, Just cores)
            | any stops cores -> (after, Just (stopped at cores, CoreNeverType))
            | and (zipWith (\expected core -> coreExpressionType core == expected) parameters cores) ->
                shape after kind key cores result
            | otherwise -> halt at ("a call to " <> member <> " with these arguments") after
  collectionName kind = case kind of
    CoreMapType _ _ -> "Map"
    _ -> "Set"
  mapMethods kind key value =
    [ ("size", ([], intType, plain KeyedSize))
    , ("isEmpty", ([], CoreBoolType, plain KeyedIsEmpty))
    , ("get", ([key], CoreUnitType, getting))
    , ("containsKey", ([key], CoreBoolType, plain KeyedContains))
    , ("insert", ([key, value], kind, inserting "map key"))
    , ("remove", ([key], kind, plain KeyedRemove))
    , ("keys", ([], CoreArrayType key, plain KeyedKeys))
    , ("values", ([], CoreArrayType value, plain KeyedValues))
    , ("entries", ([], CoreArrayType (CoreTupleType [key, value]), plain KeyedEntries))
    , ("merge", ([kind], kind, plain KeyedMerge)) ]
  setMethods kind key =
    [ ("size", ([], intType, plain KeyedSize))
    , ("isEmpty", ([], CoreBoolType, plain KeyedIsEmpty))
    , ("contains", ([key], CoreBoolType, plain KeyedContains))
    , ("insert", ([key], kind, inserting "set member"))
    , ("remove", ([key], kind, plain KeyedRemove))
    , ("toArray", ([], CoreArrayType key, plain KeyedKeys))
    , ("union", ([kind], kind, plain KeyedUnion))
    , ("intersect", ([kind], kind, plain KeyedIntersect))
    , ("difference", ([kind], kind, plain KeyedDifference)) ]
  plain name current _ _ cores result = case reverse cores of
    target : backwards -> (current, Just (CoreExpression at result (CoreKeyedMethod name target (reverse backwards)), result))
    [] -> refused current
  -- get: Some(lookup) when contains says the key is there, None otherwise.
  getting current kind _ cores _ = case (typeForSpan types at, cores) of
    (Just option@(CoreSumType _ _), [probe, collection]) ->
      let (withKey, keyLocal) = bindLocal current "" (coreExpressionType probe)
          (withMap, mapLocal) = bindLocal withKey "" kind
          valueType = case kind of
            CoreMapType _ held -> held
            other -> other
          read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
          found = CoreExpression at CoreBoolType (CoreKeyedMethod KeyedContains (read' mapLocal) [read' keyLocal])
          looked = CoreExpression at valueType (CoreKeyedMethod KeyedLookup (read' mapLocal) [read' keyLocal])
          some = CoreExpression at option (CoreConstruct "Some" [("0", looked)])
          none = CoreExpression at option (CoreConstruct "None" [])
          choice = CoreExpression at option (CoreIfValue found (CoreBlock [] (Just some)) none)
       in ( withMap
          , Just (CoreExpression at option (CoreBlockValue (CoreBlock
              [CoreStatement at (CoreDeclare keyLocal probe), CoreStatement at (CoreDeclare mapLocal collection)] (Just choice))), option) )
    _ -> halt at "an Option result of get without a native form" current
  -- insert: everything runs, then the key is checked, then stored.
  inserting described current kind key cores result
    | not (mayHoldFunction types key) = plain KeyedInsert current kind key cores result
    | otherwise =
        let (final, locals) = foldl (\(now, done) core -> let (next, local) = bindLocal now "" (coreExpressionType core) in (next, done <> [local])) (current, []) cores
            read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
            declares = [CoreStatement at (CoreDeclare local core) | (local, core) <- zip locals cores]
         in case locals of
              keyLocal : _ ->
                let check = orderable at described (read' keyLocal)
                    target = last locals
                    stored = CoreExpression at result (CoreKeyedMethod KeyedInsert (read' target) (map read' (init locals)))
                 in (final, Just (CoreExpression at result (CoreBlockValue (CoreBlock (declares <> [check]) (Just stored))), result))
              [] -> refused final

{-| The array goes into a local, its keys are checked when they could need
    it, then the tree is built from it. -}
built :: LowerState -> Span -> CoreType -> (CoreExpression -> CoreExpression) -> Text -> CoreExpression -> Lowered
built state at kind keyOf described array
  | not (mayHoldFunction types keyType) = (state, Just (expression kind (CoreKeyedMethod KeyedFromArray array []), kind))
  | otherwise =
      let (withItems, items) = bindLocal state "" (coreExpressionType array)
          (withCount, count) = bindLocal withItems "" intType
          (withIndex, index) = bindLocal withCount "" intType
          (pushed, identity) = pushLoop Nothing withIndex
          element = case coreExpressionType array of
            CoreArrayType held -> held
            other -> other
          item = expression element (CoreIndex (reading items) (reading index))
          loop = expression CoreUnitType (CoreWhileValue identity
            (expression CoreBoolType (CoreBinary CoreLess (reading index) (reading count)))
            (CoreBlock
              [ orderable at described (keyOf item)
              , CoreStatement at (CoreAssign index (expression intType (CoreBinary CoreAdd (reading index) (number 1)))) ] Nothing))
          statements =
            [ CoreStatement at (CoreDeclare items array)
            , CoreStatement at (CoreDeclare count (expression intType (CoreArrayMethod ArrayLengthOf (reading items) [])))
            , CoreStatement at (CoreDeclare index (number 0))
            , CoreStatement at (CoreEvaluate loop) ]
       in ( popLoop pushed
          , Just (expression kind (CoreBlockValue (CoreBlock statements
              (Just (expression kind (CoreKeyedMethod KeyedFromArray (reading items) []))))), kind) )
 where
  types = contextTypes (lowerContext state)
  keyType = case kind of
    CoreMapType key _ -> key
    CoreSetType member -> member
    other -> other
  expression kind' shape = CoreExpression at kind' shape
  reading local = expression (coreLocalType local) (CoreReadLocal local)
  number value = expression intType (CoreIntegerLiteral PlatformSigned value)

{-| `if !comparable(key) { E7008 }`, naming the key as `valueKind` does: a
    sum by the variant it holds. -}
orderable :: Span -> Text -> CoreExpression -> CoreStatement
orderable at described key =
  CoreStatement at (CoreIf (expression CoreBoolType (CoreNot (expression CoreBoolType (CoreComparable key))))
    (CoreBlock [CoreStatement at (CoreEvaluate failure)] Nothing) Nothing)
 where
  expression kind shape = CoreExpression at kind shape
  text value = expression CoreTextType (CoreTextLiteral value)
  joined = foldl1 (\left right -> expression CoreTextType (CoreBinary CoreAdd left right))
  kindName = case coreExpressionType key of
    CoreSumType _ _ -> expression CoreTextType (CoreVariantName key)
    CoreRecordType name _ -> text (displayName name)
    CoreTupleType _ -> text "tuple"
    CoreArrayType _ -> text "array"
    CoreMapType _ _ -> text "map"
    CoreSetType _ -> text "set"
    CoreFunctionType _ _ -> text "function"
    other -> text (coreTypeName other)
  failure = expression CoreNeverType (CoreFailText "E7008" (Just "use a value the language can order, such as text, a number, or a tuple of those")
    (joined [text "a ", kindName, text (" cannot be a " <> described)]) Nothing)

{-| Whether a value of the type could hold a function somewhere, and so might
    not be orderable. Every other key always is, and needs no test. -}
mayHoldFunction :: LowerTypes -> CoreType -> Bool
mayHoldFunction types = go []
 where
  go seen kind
    | kind `elem` seen = False
    | otherwise = case kind of
        CoreFunctionType _ _ -> True
        CoreTupleType members -> any (go (kind : seen)) members
        CoreArrayType element -> go (kind : seen) element
        CoreMapType key value -> any (go (kind : seen)) [key, value]
        CoreSetType member -> go (kind : seen) member
        CoreRecordType _ _ -> maybe False (any (go (kind : seen) . snd)) (recordFields types kind)
        CoreSumType _ _ -> maybe False (any (go (kind : seen) . snd) . concatMap coreVariantFields) (sumVariants types kind)
        _ -> False
