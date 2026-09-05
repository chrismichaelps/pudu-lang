{-| @Eval.Foreign — makes a call into a library written elsewhere

    Everything the declaration promised is enforced here, on the way through.
    That order matters: past this point the value is in somebody else's hands
    and a mistake stops being a diagnostic and becomes a corrupted stack, so
    every check that can happen before the call happens before the call. -}
module Pudu.Eval.Foreign
  ( callForeign
  ) where

import Control.Exception (mask_, onException)
import Data.Maybe (fromMaybe)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Foreign.Ptr (Ptr)
import Pudu.Diagnostic
  ( Diagnostic
  , Related (..)
  , diagnosticMessage
  , diagnosticSpan
  , withRelated
  , Severity (Error)
  , diagnostic
  , mkDiagnosticCode
  , withHelp
  )
import Pudu.Eval.Env (Evaluator (..), Eval (..), abortAt, currentForeignStore, performEffect)
import Pudu.Eval.Value (ForeignBinding (..), ForeignSlot (..), Value (..))
import Pudu.Foreign.Call
  ( CrossedValue (..)
  , ForeignCallFailure (..)
  , callSymbol
  , resolveSymbol
  )
import Pudu.Foreign.Crossing (Crossing (..), crossingName, fitsCrossing)
import Pudu.Foreign.Ownership
  ( ForeignResource
  , ForeignStore
  , discardOwnedGenerations
  , claimAllOwnedGenerations
  , claimOwnedGeneration
  , restoreOwned
  , takeOwnedGeneration
  , takeForeignDiagnostics
  , withOwnedGenerations
  )
import Pudu.Source (Span)
import Pudu.Eval.Foreign.Result (ConversionFailure (..), convertForeignValue)
import Pudu.Eval.Foreign.Resource (prepareReleases, releaseHandle, cleanupFailedOutputs, cleanupUnclaimed)

{-| Make the call the binding describes.

    A foreign call is an effect, and the same rule applies to it as to reading a
    file: a compile-time constant is folded while the compiler runs, and letting
    one reach a graphics library would make what the program compiles to depend
    on what was installed on the machine that compiled it. -}
callForeign :: Span -> ForeignBinding -> [Value] -> Evaluator Value
callForeign spanValue binding values = maskedBoundary $ do
  crossed <- crossArguments spanValue binding values
  let claims = [(address, generation) | ForeignHandleValue _ address generation <- values]
  store <- currentForeignStore
  found <-
    performEffect (refusal spanValue)
      (resolveSymbol (foreignBindingLibrary binding) (foreignBindingVersion binding)
        (foreignBindingSymbol binding))
  case found of
    Left problem -> abortForeign spanValue binding problem
    Right symbol -> do
      ready <- performEffect (refusal spanValue) (prepareReleases binding)
      case ready of
        Left problem -> abortForeign spanValue binding problem
        Right () -> pure ()
      released <- prepareHandles spanValue binding store claims crossed
      attempted <- invoke spanValue binding store symbol claims crossed
      case attempted of
        Nothing -> deadHandle spanValue binding (firstHandleName crossed)
        Just (Left problem) -> do
          case problem of
            PostCallFailure _ handles -> performEffect (refusal spanValue)
              (cleanupFailedOutputs spanValue binding store handles)
            _ -> restoreReleased spanValue store released
          abortForeignCall spanValue binding problem
        Just (Right (produced, written)) ->
          answer spanValue binding store produced written

{-| Settle native resources before asynchronous cancellation is delivered. -}
maskedBoundary :: Evaluator a -> Evaluator a
maskedBoundary (Evaluator action) = Evaluator $ \env -> mask_ $ do
  outcome <- action env
  case outcome of
    Aborted primary -> do
      let Evaluator current = currentForeignStore
      storeResult <- current env
      case storeResult of
        Done store _ -> do
          problems <- takeForeignDiagnostics store
          pure (Aborted (foldl (\held problem ->
            withRelated (Related (diagnosticSpan problem) (diagnosticMessage problem)) held)
            primary problems))
        _ -> pure outcome
    _ -> pure outcome

invoke
  :: Span
  -> ForeignBinding
  -> ForeignStore
  -> Ptr ()
  -> [(Int64, Integer)]
  -> [(Crossing, Bool, CrossedValue)]
  -> Evaluator (Maybe (Either ForeignCallFailure (CrossedValue, [Maybe CrossedValue])))
invoke spanValue binding store symbol claims arguments =
  case foreignBindingReleases binding of
    Just _ -> Just <$> perform
    Nothing ->
      performEffect (refusal spanValue)
        (withOwnedGenerations store claims
          (callSymbol symbol arguments (foreignBindingResult binding)))
 where
  perform =
    performEffect (refusal spanValue)
      (callSymbol symbol arguments (foreignBindingResult binding))

{-| Validate handle liveness immediately before control crosses the boundary.

    Releasing removes ownership before the call. That ordering closes the only
    window in which an aliased value could start a second release, while a
    failure to assemble the call restores the claim because foreign code never
    ran. -}
prepareHandles
  :: Span
  -> ForeignBinding
  -> ForeignStore
  -> [(Int64, Integer)]
  -> [(Crossing, Bool, CrossedValue)]
  -> Evaluator (Maybe (Int64, ForeignResource))
prepareHandles spanValue binding store claims arguments =
  case foreignBindingReleases binding of
    Just expected -> case handleAddresses arguments of
      [(actual, address)]
        | actual == expected -> do
            released <- case lookup address claims of
              Nothing -> pure Nothing
              Just generation -> performEffect (refusal spanValue)
                (takeOwnedGeneration store address generation)
            case released of
              Just resource -> pure (Just (address, resource))
              Nothing -> deadHandle spanValue binding actual
      _ ->
        abortAt (Just spanValue) "E7022"
          (foreignBindingSymbol binding <> " cannot release this handle")
          (Just "pass one live handle of the type named by its foreign declaration")
    Nothing -> pure Nothing

{-| The live handles a caller passed in, which are the ones a call leases.

    A slot carries no handle from this side: what it receives is claimed after
    the call, not leased through it. -}
handleAddresses :: [(Crossing, Bool, CrossedValue)] -> [(Text, Int64)]
handleAddresses arguments =
  [ (name, address)
  | (_, False, CrossedHandle name address) <- arguments
  ]

restoreReleased :: Span -> ForeignStore -> Maybe (Int64, ForeignResource) -> Evaluator ()
restoreReleased _ _ Nothing = pure ()
restoreReleased spanValue store (Just (address, resource)) =
  performEffect (refusal spanValue) (restoreOwned store address resource)

firstHandleName :: [(Crossing, Bool, CrossedValue)] -> Text
firstHandleName arguments = case handleAddresses arguments of
  (name, _) : _ -> name
  [] -> "foreign handle"

deadHandle :: Span -> ForeignBinding -> Text -> Evaluator a
deadHandle spanValue binding name =
  abortAt (Just spanValue) "E7022"
    ("the " <> name <> " passed to " <> foreignBindingSymbol binding <> " is no longer owned")
    (Just "a foreign handle cannot be used or released after its release function has run")

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

{-| What comes back, as a value of this language.

    A width goes out and an ordinary integer comes back: the declaration decides
    how much of a number crosses, and nothing above the boundary carries a
    machine width it did not ask for. -}
{-| Everything the call produced, as one Pudu value.

    Without slots that is the result alone, exactly as before. With them it is a
    tuple of the result and each slot in declaration order, and every resource
    the call handed back — the result's and the slots' — is claimed together
    before any of it is visible. A claim that cannot be made gives back what the
    library just made rather than leaking it, because a resource nobody can name
    is one nobody can release. -}
answer
  :: Span
  -> ForeignBinding
  -> ForeignStore
  -> CrossedValue
  -> [Maybe CrossedValue]
  -> Evaluator Value
answer spanValue binding store produced written
  | null (slotDescriptions binding) = receive spanValue binding store produced
  | otherwise = do
      claimed <-
        performEffect (refusal spanValue)
          (claimAllOwnedGenerations store [(address, releaseHandle store spanValue release name address)
            | (address, name, release) <- fresh <> resultFresh])
      case claimed of
        Left protected -> do
          performEffect (refusal spanValue)
            (cleanupUnclaimed store spanValue protected (fresh <> resultFresh))
          abortAt (Just spanValue) "E7021"
            (foreignBindingSymbol binding <> " handed back duplicate or already owned resources")
            (Just "an owned foreign value must transfer one new ownership claim")
        Right generations -> settleClaimed store generations $ do
          if length written == length described
            then pure ()
            else foreignResultMismatch spanValue binding
          native <- receiveClaimed spanValue binding store generations produced
          slots <- mapM (uncurry (receiveSlot spanValue binding generations)) (zip described written)
          pure (TupleValue (native : slots))
 where
  described = slotDescriptions binding
  fresh =
    [ (address, name, release)
    | (Just slot, Just (CrossedHandle name address)) <- zip (map Just described) written
    , address /= 0
    , Just release <- [foreignSlotReleasedBy slot]
    ]
  resultFresh = case (foreignBindingResult binding, produced, foreignBindingReleasedBy binding) of
    (HandleCrossing name, CrossedHandle _ address, Just release)
      | address /= 0 -> [(address, name, release)]
    _ -> []

{-| The slots this binding declares, in order. -}
slotDescriptions :: ForeignBinding -> [ForeignSlot]
slotDescriptions binding = [slot | Just slot <- foreignBindingSlots binding]

{-| One slot's value, once its ownership has already been settled.

    A pointer slot answers `Option`, so a library that wrote nothing is a `None`
    the program can read rather than an address it must not follow. -}
receiveSlot
  :: Span -> ForeignBinding -> [(Int64, Integer)] -> ForeignSlot -> Maybe CrossedValue -> Evaluator Value
receiveSlot spanValue binding generations slot received = case received of
  Nothing -> case foreignSlotCrossing slot of
    TextCrossing -> pure (VariantValue "None" [])
    HandleCrossing _ -> pure (VariantValue "None" [])
    _ -> foreignResultMismatch spanValue binding
  Just value -> do
    held <- case (foreignSlotCrossing slot, value) of
      (HandleCrossing name, CrossedHandle actual address)
        | name == actual -> ownedValue spanValue binding generations name address
      _ -> receivedField spanValue binding "slot" (foreignSlotCrossing slot) value
    pure
      ( case foreignSlotCrossing slot of
          TextCrossing -> VariantValue "Some" [held]
          HandleCrossing _ -> VariantValue "Some" [held]
          _ -> held
      )

{-| The native result, when its ownership was settled with the slots'. -}
receiveClaimed :: Span -> ForeignBinding -> ForeignStore -> [(Int64, Integer)] -> CrossedValue -> Evaluator Value
receiveClaimed spanValue binding store generations produced =
  case (foreignBindingResult binding, produced) of
    (HandleCrossing name, CrossedHandle actual address)
      | name /= actual -> foreignResultMismatch spanValue binding
      | address == 0 ->
          abortAt (Just spanValue) "E7020"
            (foreignBindingSymbol binding <> " returned a null " <> name)
            (Just "an owned foreign result must name a live object")
      | otherwise -> ownedValue spanValue binding generations name address
    _ -> receive spanValue binding store produced

ownedValue :: Span -> ForeignBinding -> [(Int64, Integer)] -> Text -> Int64 -> Evaluator Value
ownedValue spanValue binding generations name address = case lookup address generations of
  Just generation -> pure (ForeignHandleValue name address generation)
  Nothing -> foreignResultMismatch spanValue binding

receive :: Span -> ForeignBinding -> ForeignStore -> CrossedValue -> Evaluator Value
receive spanValue binding store produced =
  case (foreignBindingResult binding, produced) of
    (HandleCrossing name, CrossedHandle actual address)
      | name /= actual -> foreignResultMismatch spanValue binding
      | address == 0 ->
          abortAt (Just spanValue) "E7020"
            (foreignBindingSymbol binding <> " returned a null " <> name)
            (Just "an owned foreign result must name a live object")
      | otherwise -> case foreignBindingReleasedBy binding of
          Nothing -> foreignResultMismatch spanValue binding
          Just release -> do
            fresh <-
              performEffect (refusal spanValue)
                (claimOwnedGeneration store address (releaseHandle store spanValue release name address))
            case fresh of
              Just generation -> pure (ForeignHandleValue name address generation)
              Nothing ->
                abortAt (Just spanValue) "E7021"
                  (foreignBindingSymbol binding <> " returned a " <> name <> " already owned")
                  (Just "an owned foreign result must transfer one new ownership claim")
    (BytesCrossing, _) ->
      abortAt (Just spanValue) "E7026"
        (foreignBindingSymbol binding <> " cannot return Bytes")
        (Just "an owned buffer requires an explicit length and release contract")
    _ -> receivedField spanValue binding "result" (foreignBindingResult binding) produced

foreignResultMismatch :: Span -> ForeignBinding -> Evaluator a
foreignResultMismatch spanValue binding =
  abortAt (Just spanValue) "E7015"
    (foreignBindingSymbol binding <> " returned a value outside its declaration")
    (Just "check the foreign result type against the library's exported signature")

receivedField :: Span -> ForeignBinding -> Text -> Crossing -> CrossedValue -> Evaluator Value
receivedField spanValue binding label crossing produced =
  case convertForeignValue label crossing produced of
    Right value -> pure value
    Left InvalidShape -> foreignResultMismatch spanValue binding
    Left (MissingText field) ->
      abortAt (Just spanValue) "E7024"
        (foreignBindingSymbol binding <> " returned no text for " <> field)
        (Just "a declared Str must name valid UTF-8 text")

{-| Failed conversion cannot leave unexposed claims in the store. -}
settleClaimed :: ForeignStore -> [(Int64, Integer)] -> Evaluator a -> Evaluator a
settleClaimed store claims (Evaluator action) = Evaluator $ \env -> do
  outcome <- action env `onException` discardOwnedGenerations store claims
  case outcome of
    Done _ _ -> pure outcome
    _ -> discardOwnedGenerations store claims >> pure outcome

abortForeign :: Span -> ForeignBinding -> Text -> Evaluator a
abortForeign spanValue binding problem =
  abortAt (Just spanValue) "E7015"
    ( "cannot call " <> foreignBindingSymbol binding <> " in "
        <> foreignBindingLibrary binding <> ": " <> problem
    )
    ( Just
        ( "a foreign declaration names a library the platform must already have; "
            <> "install it, or check the name and the symbol against what it exports"
        )
    )

abortForeignCall :: Span -> ForeignBinding -> ForeignCallFailure -> Evaluator a
abortForeignCall spanValue binding failure = case failure of
  CallAssemblyFailure problem -> abortForeign spanValue binding problem
  PostCallFailure problem _ -> abortForeignCall spanValue binding problem
  InvalidReturnedText ->
    abortAt (Just spanValue) "E7025"
      (foreignBindingSymbol binding <> " returned text that is not valid UTF-8")
      (Just "fix the native binding or declare a byte-oriented result instead of Str")

refusal :: Span -> Diagnostic
refusal spanValue =
  fromMaybe (fallback spanValue) $ do
    code <- mkDiagnosticCode "E7009"
    value <- diagnostic code Error spanValue "a foreign call reaches outside the program"
    pure
      ( withHelp
          "a compile-time constant is folded while the compiler runs, so it cannot reach a library"
          value
      )

fallback :: Span -> Diagnostic
fallback spanValue =
  fromMaybe
    (error "the refusal diagnostic must exist")
    (mkDiagnosticCode "E7009" >>= \code -> diagnostic code Error spanValue "foreign call refused")
