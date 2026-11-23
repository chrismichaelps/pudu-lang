{-| @Pudu.Compiler.Lower.Keyed — maps and sets: `mapOf`, `setOf`, `#{...}`
    and their methods, as `Eval.Builtin.Collection` answers them. The receiver runs
    before arguments. A key whose type could hold a function is tested
    before it is stored, and one that can't be ordered stops the program with
    E7008, as `comparableValue` decides. -}
module Pudu.Compiler.Lower.Keyed
  (lowerKeyedBuilder, keyedFromArray, keyedBuilderCarrier, lowerSetLiteral, lowerKeyedMethod, setMembership, Blame (..), orderable, mayHoldFunction) where

import Data.List (mapAccumL)
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler.Lower.Arguments
  ( ArgumentSlot (..), argumentFailure, callWithRuntimeArguments, collectArguments, methodArgumentBlame, wrappedPosition )
import Pudu.Compiler.Lower.Array (collect, reboxArray, stopped, stops)
import Pudu.Compiler.Lower.Control (popLoop, pushLoop)
import Pudu.Compiler.Lower.Dynamic (commonAggregateCarrier, hasRuntimeChoice, projectRuntimeValue, runtimeCarriers, storageCarrier, widen)
import Pudu.Compiler.Lower.Sum (constructVariant)
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
  (Just kind, [argument]) -> case lower state argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (core, CoreNeverType))
    (after, Just (core, CoreArrayType _)) ->
      maybe (halt at ("a call to " <> name <> " with incompatible item layouts") after) id
        (buildFromArray AtCall after at name kind core)
    (after, Just _) -> halt (locatedSpan argument) ("a call to " <> name <> " with this argument") after
  _ -> halt at ("this call to " <> name) state
 where
  types = contextTypes (lowerContext state)

{-| The body of a `mapOf` or `setOf` value: what the call builds, except that
    an unorderable key is blamed on the call made through the value. Nothing
    when the result is not that builtin's collection. -}
keyedFromArray :: LowerState -> Span -> Text -> CoreType -> CoreExpression -> Maybe Lowered
keyedFromArray = buildFromArray AtCaller

buildFromArray :: Blame -> LowerState -> Span -> Text -> CoreType -> CoreExpression -> Maybe Lowered
buildFromArray blame state at name kind array = do
  let types = contextTypes (lowerContext state)
      base = case (kind, coreExpressionShape array) of
        (CoreMapType key value, CoreArray []) -> array{coreExpressionType = CoreArrayType (CoreTupleType [key, value])}
        (CoreSetType member, CoreArray []) -> array{coreExpressionType = CoreArrayType member}
        (CoreMapType key value, _) -> widen types (CoreArrayType (CoreTupleType [key, value])) array
        (CoreSetType member, _) -> widen types (CoreArrayType member) array
        _ -> array
  (result, element) <- keyedBuilderCarrier types name kind (coreExpressionType base)
  (keyOf, described) <- builderOf at name result
  CoreArrayType old <- Just (coreExpressionType base)
  let (ready, items) = reboxArray state at old element base
  pure (built blame ready at result keyOf described items)

keyedBuilderCarrier :: LowerTypes -> Text -> CoreType -> CoreType -> Maybe (CoreType, CoreType)
keyedBuilderCarrier types name checked (CoreArrayType item) = case (name, checked) of
  ("mapOf", CoreMapType key value)
    | CoreTupleType [actualKey, actualValue] <- item ->
        Just (CoreMapType actualKey actualValue, item)
    | Just pair@(CoreTupleType [actualKey, actualValue]) <- commonAggregateCarrier types
        (CoreTupleType [key, value]) (Set.toList (runtimeCarriers item)) ->
          Just (CoreMapType actualKey actualValue, pair)
  ("setOf", CoreSetType _) -> Just (CoreSetType item, item)
  _ -> Nothing
keyedBuilderCarrier _ _ _ _ = Nothing

builderOf :: Span -> Text -> CoreType -> Maybe (CoreExpression -> CoreExpression, Text)
builderOf at name kind = case (name, kind) of
  ("mapOf", CoreMapType key _) -> Just (\item -> CoreExpression at key (CoreTupleIndex 0 item), "map key")
  ("setOf", CoreSetType _) -> Just (id, "set member")
  _ -> Nothing

{-| Where a key refusal points: the call itself, or the value call that
    reached a builtin body. -}
data Blame = AtCall | AtCaller

{-| `#{a, b}`: every member runs in order, and only then are they checked. -}
lowerSetLiteral :: LowerExpression -> LowerState -> Span -> [Located Expression] -> Lowered
lowerSetLiteral lower state at members = case typeForSpan (contextTypes (lowerContext state)) at of
  Just kind@(CoreSetType member) -> case collect lower state members of
    (after, Nothing) -> refused after
    (after, Just written)
      | any stops written -> (after, Just (stopped at written, CoreNeverType))
      | let types = contextTypes (lowerContext after)
            widened = map (widen types member) written
            layouts = map coreExpressionType widened
            stored = if any hasRuntimeChoice layouts then storageCarrier types member layouts else member
            (ready, projected) = mapAccumL (\current -> projectRuntimeValue types current stored) after widened
      , all ((== stored) . coreExpressionType) projected ->
          built AtCall ready at (if stored == member then kind else CoreSetType stored) id "set member"
            (CoreExpression at (CoreArrayType stored) (CoreArray projected))
      | otherwise -> halt at "a set literal whose members have different types" after
  _ -> halt at "a set without a native member type" state

{-| `candidate in set`: the candidate is held before the set, the order the
    interpreter evaluates them in, and the probe is the set's `contains`. -}
setMembership :: LowerState -> Span -> CoreExpression -> CoreExpression -> Lowered
setMembership state at candidate set =
  let (withCandidate, candidateLocal) = bindLocal state "" (coreExpressionType candidate)
      (withSet, setLocal) = bindLocal withCandidate "" (coreExpressionType set)
      read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
      (converted, source, operands) = carryOperands withSet at (coreExpressionType set) "contains"
        (read' setLocal) [read' candidateLocal]
      held = [CoreStatement at (CoreDeclare candidateLocal candidate), CoreStatement at (CoreDeclare setLocal set)]
   in case (coreExpressionType source, operands) of
        (CoreSetType member, [operand]) ->
          let types = contextTypes (lowerContext converted)
              (ready, key) = projectRuntimeValue types converted member operand
              probe = CoreExpression at CoreBoolType (CoreKeyedMethod KeyedContains source [key])
           in if coreExpressionType key == member
                then (ready, Just (CoreExpression at CoreBoolType (CoreBlockValue (CoreBlock held (Just probe))), CoreBoolType))
                else halt at "a set membership probe with an incompatible layout" ready
        _ -> halt at "set membership without its operands" converted

carryOperands :: LowerState -> Span -> CoreType -> Text -> CoreExpression -> [CoreExpression]
  -> (LowerState, CoreExpression, [CoreExpression])
carryOperands state at checked name source operands = case (checked, actual, operands) of
  (CoreMapType key value, CoreMapType oldKey oldValue, [probe, item]) | name == "insert" ->
    retain (CoreMapType (input key oldKey probe) (input value oldValue item))
  (CoreMapType key _, CoreMapType oldKey oldValue, [probe]) | name `elem` ["get", "containsKey", "remove"] ->
    retain (CoreMapType (input key oldKey probe) oldValue)
  (CoreSetType member, CoreSetType old, [probe]) | name `elem` ["contains", "insert", "remove"] ->
    retain (CoreSetType (input member old probe))
  (CoreStoreType value, CoreStoreType old, [_, item]) | name == "insert" ->
    retain (CoreStoreType (input value old item))
  (CoreMapType key value, CoreMapType oldKey oldValue, [right])
    | name == "merge", CoreMapType rightKey rightValue <- coreExpressionType right ->
        combine (CoreMapType (shared key oldKey rightKey) (shared value oldValue rightValue)) right
  (CoreSetType member, CoreSetType old, [right])
    | name `elem` ["union", "intersect", "difference"], CoreSetType rightMember <- coreExpressionType right ->
        combine (CoreSetType (shared member old rightMember)) right
  _ -> (state, source, operands)
 where
  types = contextTypes (lowerContext state)
  actual = coreExpressionType source
  input declared held operand =
    let kind = coreExpressionType (widen types held operand)
     in shared declared held kind
  shared declared left right
    | left /= right = storageCarrier types declared [left, right]
    | otherwise = left
  retain kind =
    let (ready, rebuilt) = reboxKeyed state at kind source
     in (ready, rebuilt, operands)
  combine kind right =
    let (leftReady, left) = reboxKeyed state at kind source
        (ready, right') = reboxKeyed leftReady at kind right
     in (ready, left, [right'])

reboxKeyed :: LowerState -> Span -> CoreType -> CoreExpression -> (LowerState, CoreExpression)
reboxKeyed state at expected value
  | expected /= actual
  , Just (old, method) <- items actual
  , Just (new, _) <- items expected =
      let entries = CoreExpression at (CoreArrayType old) (CoreKeyedMethod method value [])
          (ready, projected) = reboxArray state at old new entries
       in if coreExpressionType projected == CoreArrayType new
            then (ready, CoreExpression at expected (CoreKeyedMethod KeyedFromArray projected []))
            else (ready, value)
  | otherwise = (state, value)
 where
  actual = coreExpressionType value
  items (CoreMapType key held) = Just (CoreTupleType [key, held], KeyedEntries)
  items (CoreStoreType held) = Just (CoreTupleType [intType, held], KeyedEntries)
  items (CoreSetType member) = Just (member, KeyedKeys)
  items _ = Nothing

{-| A built-in map, set or store method when the receiver is one; Nothing
    otherwise. A store is addressed by the Int folded into one word, which is
    what `&+ 0` answers. -}
lowerKeyedMethod :: LowerExpression -> LowerState -> Span -> CoreType -> CoreExpression -> Text
  -> [Located Expression] -> Lowered
lowerKeyedMethod lower state at checked target member arguments = case collectArguments lower state arguments of
  (after, Nothing) -> refused after
  (after, Just operands) ->
    let failure = case coreExpressionType target of
          CoreStoreType _ -> argumentFailure blame at "E7003" ("wrong arguments for store method " <> member)
          _ -> argumentFailure blame at "E7012" ("wrong arguments for " <> member)
        apply current (held : written) =
          let (ready, source, projected) = carryOperands current at checked member held written
           in dispatch ready source projected
        apply current _ = refused current
     in callWithRuntimeArguments at failure (ExactSlot (coreExpressionType target) : slots) apply after (target : operands)
 where
  types = contextTypes (lowerContext state)
  blame = methodArgumentBlame state
  slots = case (coreExpressionType target, member) of
    (CoreMapType{}, "merge") -> [ShapedSlot isMap]
    (CoreSetType{}, name) | name `elem` ["union", "intersect", "difference"] -> [ShapedSlot isSet]
    (CoreStoreType{}, "insert") -> [IntegerSlot, AnySlot]
    (CoreStoreType{}, name) | name `elem` ["get", "remove"] -> [IntegerSlot]
    (_, "insert") -> replicate (case coreExpressionType target of CoreMapType{} -> 2; _ -> 1) AnySlot
    (_, name) | name `elem` ["get", "containsKey", "contains", "remove"] -> [AnySlot]
    _ -> []
  isMap CoreMapType{} = True
  isMap _ = False
  isSet CoreSetType{} = True
  isSet _ = False
  dispatch current source written =
    let kind = coreExpressionType source
     in case kind of
          CoreMapType key value -> run current source written kind key (mapMethods kind key value)
          CoreSetType key -> run current source written kind key (setMethods kind key)
          CoreStoreType value -> run current source written kind intType (storeMethods kind value)
          _ -> halt at "a keyed operation without its collection" current
  run current source written kind key table = case lookup member table of
    Nothing -> halt at ("the " <> collectionName kind <> " method '" <> member <> "'") current
    Just (parameters, result, shape)
      | length parameters == length written
      , let scope = contextTypes (lowerContext current)
            (ready, projected) = mapAccumL (\prior (parameter, operand) -> projectRuntimeValue scope prior parameter operand)
              current (zip parameters (indexed kind written))
      , map coreExpressionType projected == parameters ->
          shape ready kind key (source : projected) result
      | otherwise -> halt at ("a call to " <> member <> " with these arguments") current
  collectionName kind = case kind of
    CoreMapType _ _ -> "Map"
    CoreStoreType _ -> "Buckets"
    _ -> "Set"
  indexed kind cores = case (kind, cores) of
    (CoreStoreType _, probe : rest) -> wrappedPosition at probe : rest
    _ -> cores
  storeMethods kind value =
    [ ("size", ([], intType, plain KeyedSize))
    , ("isEmpty", ([], CoreBoolType, plain KeyedIsEmpty))
    , ("get", ([intType], CoreUnitType, getting))
    , ("insert", ([intType, value], kind, plain KeyedInsert))
    , ("remove", ([intType], kind, plain KeyedRemove))
    , ("keys", ([], CoreArrayType intType, plain KeyedKeys))
    , ("values", ([], CoreArrayType value, plain KeyedValues)) ]
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
  plain name current _ _ cores result = case cores of
    collection : operands -> (current, Just (CoreExpression at result (CoreKeyedMethod name collection operands), result))
    [] -> refused current
  -- get: Some(lookup) when contains says the key is there, None otherwise.
  getting current kind _ cores _ = case cores of
    [collection, probe] ->
      let (withKey, keyLocal) = bindLocal current "" (coreExpressionType probe)
          (withMap, mapLocal) = bindLocal withKey "" kind
          valueType = case kind of
            CoreMapType _ held -> held
            CoreStoreType held -> held
            other -> other
          option = CoreSumType "Option" [valueType]
          read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
          found = CoreExpression at CoreBoolType (CoreKeyedMethod KeyedContains (read' mapLocal) [read' keyLocal])
          looked = CoreExpression at valueType (CoreKeyedMethod KeyedLookup (read' mapLocal) [read' keyLocal])
       in case constructVariant withMap at option "Some" [("0", looked)] of
            (ready, Just (some, result)) ->
              let none = CoreExpression at result (CoreConstruct "None" [])
                  choice = CoreExpression at result (CoreIfValue found (CoreBlock [] (Just some)) none)
                  statements = [CoreStatement at (CoreDeclare mapLocal collection), CoreStatement at (CoreDeclare keyLocal probe)]
               in (ready, Just (CoreExpression at result (CoreBlockValue (CoreBlock statements (Just choice))), result))
            (ready, Nothing) -> refused ready
    _ -> halt at "an Option result of get without a native form" current
  -- insert: everything runs, then the key is checked, then stored.
  inserting described current kind key cores result
    | not (mayHoldFunction types key) = plain KeyedInsert current kind key cores result
    | otherwise =
        let (final, locals) = foldl (\(now, done) core -> let (next, local) = bindLocal now "" (coreExpressionType core) in (next, done <> [local])) (current, []) cores
            read' local = CoreExpression at (coreLocalType local) (CoreReadLocal local)
            declares = [CoreStatement at (CoreDeclare local core) | (local, core) <- zip locals cores]
         in case locals of
              collection : operands@(keyLocal : _) ->
                let check = orderable AtCall at described (read' keyLocal)
                    stored = CoreExpression at result (CoreKeyedMethod KeyedInsert (read' collection) (map read' operands))
                 in (final, Just (CoreExpression at result (CoreBlockValue (CoreBlock (declares <> [check]) (Just stored))), result))
              _ -> refused final

{-| The array goes into a local, its keys are checked when they could need
    it, then the tree is built from it. -}
built :: Blame -> LowerState -> Span -> CoreType -> (CoreExpression -> CoreExpression) -> Text -> CoreExpression -> Lowered
built blame state at kind keyOf described array
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
              [ orderable blame at described (keyOf item)
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
orderable :: Blame -> Span -> Text -> CoreExpression -> CoreStatement
orderable blame at described key =
  CoreStatement at (CoreIf (expression CoreBoolType (CoreNot (expression CoreBoolType (CoreComparable key))))
    (CoreBlock [CoreStatement at (CoreEvaluate failure)] Nothing) Nothing)
 where
  expression kind shape = CoreExpression at kind shape
  text value = expression CoreTextType (CoreTextLiteral value)
  joined = foldl1 (\left right -> expression CoreTextType (CoreBinary CoreAdd left right))
  kindName = case coreExpressionType key of
    CoreSumType _ _ -> expression CoreTextType (CoreRuntimeKind key)
    CoreRecordType name _ -> text (displayName name)
    CoreTupleType _ -> text "tuple"
    CoreArrayType _ -> text "array"
    CoreMapType _ _ -> text "map"
    CoreSetType _ -> text "set"
    CoreStoreType _ -> text "store"
    CoreFunctionType _ _ -> expression CoreTextType (CoreRuntimeKind key)
    other -> text (coreTypeName other)
  help = Just "use a value the language can order, such as text, a number, or a tuple of those"
  message = joined [text "a ", kindName, text (" cannot be a " <> described)]
  failure = expression CoreNeverType $ case blame of
    AtCall -> CoreFailText "E7008" help message Nothing
    AtCaller -> CoreFailCaller "E7008" help message

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
        CoreStoreType held -> go (kind : seen) held
        CoreRecordType _ _ -> maybe False (any (go (kind : seen) . snd)) (recordFields types kind)
        CoreSumType _ _ -> maybe False (any (go (kind : seen) . snd) . concatMap coreVariantFields) (sumVariants types kind)
        _ -> False
