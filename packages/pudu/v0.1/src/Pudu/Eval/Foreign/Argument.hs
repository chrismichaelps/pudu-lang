{-| @Program.Eval.Foreign.Argument — prepares arguments crossing the foreign boundary -}
module Pudu.Eval.Foreign.Argument
  ( crossArguments
  , crossOne
  , crossField
  , isIntegral
  , slotsOf
  , count
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Env (Evaluator, abortAt)
import Pudu.Eval.Value (ForeignBinding (..), ForeignSlot (..), Value (..))
import Pudu.Foreign.Call (CrossedValue (..))
import Pudu.Foreign.Crossing (Crossing (..), crossingName, fitsCrossing)
import Pudu.Source (Span)

{-| Narrow each argument to what the declaration said it crosses as.

    An integer that does not fit the declared width is refused rather than
    wrapped. Silent wraparound at this boundary is the oldest way for a program
    calling a library to keep running with a value it never computed. -}
crossArguments
  :: Span -> ForeignBinding -> [Value] -> Evaluator [(Crossing, Bool, CrossedValue)]
crossArguments spanValue binding values
  | length wanted /= length values =
      abortAt (Just spanValue) "E7016"
        ( foreignBindingSymbol binding <> " takes "
            <> count (length wanted) <> " but was given "
            <> Text.pack (show (length values))
        )
        (Just "the declaration in the foreign block says how many it takes")
  | otherwise = weave positions values
 where
  positions = zip (foreignBindingArguments binding) (slotsOf binding)
  wanted = [crossing | (crossing, Nothing) <- positions]
  {-| The caller's values go to the positions the caller supplies. A slot takes
      no value from this side, so it passes through carrying nothing and the
      bridge is told to write it instead. -}
  weave [] _ = pure []
  weave ((crossing, Just _) : rest) remaining = do
    crossed <- weave rest remaining
    pure ((crossing, True, CrossedInteger 0) : crossed)
  weave ((crossing, Nothing) : rest) remaining = case remaining of
    [] -> pure []
    value : more -> do
      (_, one) <- crossOne spanValue binding crossing value
      crossed <- weave rest more
      pure ((crossing, False, one) : crossed)

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
