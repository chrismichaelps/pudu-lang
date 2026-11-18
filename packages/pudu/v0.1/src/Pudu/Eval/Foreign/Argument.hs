{-| @Program.Eval.Foreign.Argument — prepares arguments crossing the foreign boundary -}
module Pudu.Eval.Foreign.Argument
  ( crossArguments
  , crossOne
  , crossField
  , isIntegral
  , slotsOf
  , count
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Foreign.Ptr (nullPtr)
import qualified Data.Text as Text
import Pudu.Eval.Array (arrayToList)
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Foreign.Binding (ForeignCallbackSlot (..))
import Pudu.Eval.Place (Place)
import Pudu.Eval.Value (CallbackValue (..), ForeignBinding (..), ForeignSlot (..), Value (..))
import Pudu.Foreign.Callback
  ( CallbackPair (..), CallbackPlacement (..), callbackHiddenPositions, callbackInputPosition )
import Pudu.Foreign.CallbackStore (CallbackKey)
import Pudu.Foreign.Call (CrossedValue (..))
import Pudu.Foreign.Crossing (Crossing (..), crossingName, fitsCrossing)
import Pudu.Source (Span)

{-| Narrow each argument to what the declaration said it crosses as.

    An integer that does not fit the declared width is refused rather than
    wrapped. Silent wraparound at this boundary is the oldest way for a program
    calling a library to keep running with a value it never computed. -}
crossArguments
  :: Span -> ForeignBinding -> [Maybe Place] -> [Value]
  -> Evaluator ([(Crossing, Bool, CrossedValue)], [(ForeignCallbackSlot, Maybe CallbackKey)], Map.Map Int (Crossing, Place))
crossArguments spanValue binding places values
  | length wanted /= length values =
      abortAt (Just spanValue) "E7016"
        ( foreignBindingSymbol binding <> " takes "
            <> count (length wanted) <> " but was given "
            <> Text.pack (show (length values))
        )
        (Just "the declaration in the foreign block says how many it takes")
  | otherwise = weave positions (zip (places <> repeat Nothing) values)
 where
  positions = zip [0 ..] (zip (foreignBindingArguments binding) (slotsOf binding))
  callbacks = foreignBindingCallbacks binding
  placement = callbackPlacement . foreignCallbackPair
  byArgument = Map.fromList [(index, slot) | slot <- callbacks, Just index <- [callbackInputPosition (placement slot)]]
  contexts = Set.fromList (concatMap (callbackHiddenPositions . placement) callbacks)
  projections = Map.fromList [(index, slot) | slot <- callbacks, StaticTrampoline index <- [placement slot]]
  wanted = [crossing | (index, (crossing, Nothing)) <- positions, Set.notMember index contexts]
  pointer = (NothingCrossing, False, CrossedPointer nullPtr)
  weave [] _ = pure ([], [], Map.empty)
  weave ((index, (crossing, slot)) : rest) remaining
    | Just callback <- Map.lookup index projections = do
        (crossed, tokens, loans) <- weave rest remaining
        pure (pointer : crossed, (callback, Nothing) : tokens, loans)
    | Set.member index contexts = prepend pointer <$> weave rest remaining
    | Just _ <- slot = prepend (crossing, True, CrossedInteger 0) <$> weave rest remaining
    | otherwise = case remaining of
        [] -> abortAt (Just spanValue) "E7016" "foreign arguments do not match their native slots" Nothing
        (place, value) : more -> case Map.lookup index byArgument of
          Just callback -> case value of
            ForeignCallbackValue (CallbackToken owner key)
              | owner == foreignCallbackOwner callback -> do
                  (crossed, tokens, loans) <- weave rest more
                  pure (pointer : crossed, (callback, Just key) : tokens, loans)
            _ -> abortAt (Just spanValue) "E7017" "expected a token of the declared callback type" Nothing
          Nothing
            | Set.member index (foreignBindingNullableLoans binding)
            , SumValue "Option" "None" [] <- value ->
                prepend pointer <$> weave rest more
          Nothing -> case Map.lookup index (foreignBindingRuns binding) of
            Just mutable -> case arrayToList value of
              Nothing -> abortAt (Just spanValue) "E7019"
                "a foreign run needs an array value" (Just "pass a reference to the declared array type")
              Just elements -> do
                copied <- traverse (fmap snd . crossOne spanValue binding crossing) elements
                lend mutable (CrossedRun mutable copied)
            Nothing -> do
              (_, one) <- crossOne spanValue binding crossing value
              case Map.lookup index (foreignBindingLoans binding) of
                Nothing -> prepend (crossing, False, one) <$> weave rest more
                Just mutable -> lend mutable (CrossedLoan mutable one)
         where
          lend mutable one
            | not mutable = prepend (crossing, False, one) <$> weave rest more
            | otherwise = case place of
                Nothing -> abortAt (Just spanValue) "E7019"
                  "a mutable foreign loan needs a writable place" (Just "pass &mut place")
                Just target -> do
                  (crossed, tokens, loans) <- weave rest more
                  pure ( (crossing, False, one) : crossed
                       , tokens, Map.insert index (crossing, target) loans )
  prepend one (crossed, tokens, loans) = (one : crossed, tokens, loans)

{-| Which native positions the library writes, in order. -}
slotsOf :: ForeignBinding -> [Maybe ForeignSlot]
slotsOf binding =
  take (length (foreignBindingArguments binding))
    (foreignBindingSlots binding <> repeat Nothing)

count :: Int -> Text
count value
  | value == 1 = "1 argument"
  | otherwise = Text.pack (show value) <> " arguments"

crossOne :: Span -> ForeignBinding -> Crossing -> Value -> Evaluator (Crossing, CrossedValue)
crossOne spanValue binding crossing value = case (crossing, value) of
  (TextCrossing, StrValue written)
    | Text.any (== '\0') written ->
        abortAt (Just spanValue) "E7017"
          "text carrying a nought cannot cross a foreign boundary"
          ( Just
              ( "the other side reads until the first nought, so it would see "
                  <> "less than this text says"
              )
          )
    | otherwise -> pure (crossing, CrossedText written)
  (FloatingCrossing _, FloatValue _ held) -> pure (crossing, CrossedDouble held)
  {-| The run is lent, not given: the library reads it for the length of the
      call, and the value it belongs to outlives that. Nothing is copied. -}
  (BytesCrossing, BytesValue held) -> pure (crossing, CrossedBytes held)
  (BooleanCrossing, BoolValue held) -> pure (crossing, CrossedInteger (if held then 1 else 0))
  (HandleCrossing expected, ForeignHandleValue actual address _)
    | expected == actual -> pure (crossing, CrossedHandle actual address)
  {-| `Some` crosses as the handle it holds, so it is checked live as a bare
      one is; `None` crosses as the null address, which nothing claims. -}
  (OptionalHandleCrossing expected, SumValue "Option" "Some" [ForeignHandleValue actual address _])
    | expected == actual -> pure (crossing, CrossedHandle actual address)
  (OptionalHandleCrossing name, SumValue "Option" "None" []) -> pure (crossing, CrossedHandle name 0)
  {-| A record crosses by value, field by field, in the order its declaration
      wrote them. The value's own fields are matched by name rather than by
      position, so a record built with its fields written in another order still
      crosses as the declaration says it does. -}
  (RecordCrossing name declared, RecordValue actual held)
    | name == actual -> do
        fields <- mapM (crossField spanValue binding name held) declared
        pure (crossing, CrossedRecord name fields)
  (_, IntValue _ held)
    | isIntegral crossing ->
        if fitsCrossing crossing held
          then pure (crossing, CrossedInteger (fromIntegral held))
          else
            abortAt (Just spanValue) "E7018"
              ( Text.pack (show held) <> " does not fit the "
                  <> crossingName crossing <> " this argument crosses as"
              )
              ( Just
                  ( "a value that does not fit would arrive as a different value; "
                      <> "widen the declaration or narrow what is passed"
                  )
              )
  _ ->
    abortAt (Just spanValue) "E7019"
      ( "this argument to " <> foreignBindingSymbol binding
          <> " is not the " <> crossingName crossing <> " it crosses as"
      )
      (Just "pass what the foreign declaration names")

{-| One field of a record on its way across. -}
crossField
  :: Span
  -> ForeignBinding
  -> Text
  -> [(Text, Value)]
  -> (Text, Crossing)
  -> Evaluator (Text, CrossedValue)
crossField spanValue binding record held (label, crossing) =
  case lookup label held of
    Nothing ->
      abortAt (Just spanValue) "E7023"
        (record <> " has no " <> label <> " to cross")
        (Just "a record crossing a foreign boundary carries every field its declaration names")
    Just value -> do
      (_, crossed) <- crossOne spanValue binding crossing value
      pure (label, crossed)

isIntegral :: Crossing -> Bool
isIntegral crossing = case crossing of
  SignedCrossing _ -> True
  UnsignedCrossing _ -> True
  _ -> False
