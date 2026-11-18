{-| @Eval.Foreign.Callback — registers handlers and settles token retirement. -}
module Pudu.Eval.Foreign.Callback (callCallbackValue, withCallbackDispatch) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, bracket, displayException, try)
import Control.Monad (join, unless, when)
import Data.Int (Int64)
import qualified Data.IntMap.Strict as IntMap
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Foreign.Ptr (Ptr, nullPtr, ptrToWordPtr)
import Foreign.StablePtr (castPtrToStablePtr, castStablePtrToPtr, deRefStablePtr, freeStablePtr, newStablePtr)
import Pudu.Diagnostic (Diagnostic, Severity (..), diagnostic, diagnosticMessage, mkDiagnosticCode)
import Pudu.Eval.Env
  ( Env (..), Eval (..), Evaluator (..), abortAt, currentCallbackAncestry, currentCallbackStore
  , currentForeignStore, effectsAdmitted, runtimeIO )
import Pudu.Eval.Foreign.Binding (DelegateBinding (..), ForeignCallbackSlot (..))
import Pudu.Eval.Foreign.Result (convertForeignValue)
import Pudu.Eval.Value (ForeignClaim (..), Value (..))
import qualified Pudu.Eval.Value as Value
import Pudu.Foreign.Call (CrossedValue (..), ForeignCallFailure (InvalidReturnedText))
import Pudu.Foreign.Callback (CallbackPair (..), CallbackPlacement (..), CallbackParameter (..), CallbackResult (..), CallbackSignature (..))
import Pudu.Foreign.Callback.Native
  ( NativeCallbackCache, decodeCallbackArguments, findNativeCallback, nativeCallbackCode
  , callbackAdapterCode, createDelegate, findCallbackAdapter, nativeCallbackBlockCode, nativeCallbackContext
  , releaseDelegate, withBlockLiterals )
import Pudu.Foreign.CallbackStore
  ( CallbackAttempt (..), CallbackKey, CallbackUnregistration (..), invokeCallback
  , registerCallback, unregisterCallback, withCallbackLeases )
import Pudu.Foreign.Crossing (Crossing (..), fitsCrossing)
import Pudu.Foreign.Ownership (claimOwnedGeneration, recordForeignDiagnostic)
import Pudu.Source (Span)

callCallbackValue
  :: (Span -> Value -> [Value] -> Evaluator Value) -> Span -> Value.CallbackValue -> [Value] -> Evaluator Value
callCallbackValue apply at target arguments = case (target, arguments) of
  (Value.CallbackConstructor owner, [handler]) -> do
    requireRuntime
    store <- currentCallbackStore
    allocated <- runtimeIO (registerCallback store handler)
    case allocated of
      Just key -> pure (ForeignCallbackValue (Value.CallbackToken owner key))
      Nothing -> abortAt (Just at) "E7001" "the callback registry cannot admit a new registration" Nothing
  (Value.CallbackUnregister owner Nothing, [ForeignCallbackValue (Value.CallbackToken actual key)])
    | owner == actual -> retire key
  (Value.CallbackUnregister _ (Just key), []) -> retire key
  (Value.CallbackToken _ _, _) ->
    abortAt (Just at) "E7001" "a callback token is not callable" Nothing
  (Value.CallbackConstructor _, _) ->
    abortAt (Just at) "E7003" "callback registration needs one handler" Nothing
  (Value.CallbackUnregister _ _, _) ->
    abortAt (Just at) "E7003" "unregister needs a callback token and no other arguments" Nothing
  (Value.DelegateConstructor delegate, [ForeignCallbackValue (Value.CallbackToken owner key)])
    | owner == foreignCallbackOwner (delegateSlot delegate) -> do
        requireRuntime
        construct delegate key
  (Value.DelegateConstructor delegate, _) ->
    abortAt (Just at) "E7003" ("delegate " <> delegateHandle delegate <> " needs one token of its callback group") Nothing
 where
  {-| The group's native registration is the one a foreign call crossing that
      token would use; the object carries its context and owns a release. -}
  construct delegate key = do
    created <- Evaluator $ \env -> do
      let slot = delegateSlot delegate
          cache = envNativeCallbacks env
          owner = foreignCallbackAdapterOwner slot
          members = foreignCallbackMembers slot
          adapterFor (selector, ordinal) = case IntMap.lookup ordinal members of
            Nothing -> pure Nothing
            Just (_, signature) -> fmap (selector,) <$> findCallbackAdapter cache owner ordinal signature
      leased <- withCallbackLeases (envCallbackStore env) [key] $ do
        native <- findNativeCallback cache key owner 0 (foreignCallbackSignature slot)
          (invokeHandler apply (invocationEnv env) at slot key)
        methods <- traverse adapterFor (delegateMethods delegate)
        case (native, sequence methods) of
          (Just registered, Just resolved) -> createDelegate (delegateClass delegate) resolved registered
          _ -> pure Nothing
      pure (Done (join leased) env)
    case created of
      Nothing -> abortAt (Just at) "E7001" ("delegate " <> delegateHandle delegate <> " could not be created")
        (Just "a delegate needs an Apple platform and a live token of its callback group")
      Just object -> do
        store <- currentForeignStore
        let address = fromIntegral (ptrToWordPtr object)
        claimed <- runtimeIO (claimOwnedGeneration store address (releaseDelegate object))
        case claimed of
          Just generation -> pure (ForeignHandleValue (delegateHandle delegate) address (OwnedClaim generation))
          Nothing -> abortAt (Just at) "E7021" ("delegate " <> delegateHandle delegate <> " could not be claimed") Nothing
  requireRuntime = do
    admitted <- effectsAdmitted
    unless admitted $
      abortAt (Just at) "E7009" "callback registration requires a running program" Nothing
  retire key = do
    requireRuntime
    store <- currentCallbackStore
    ancestry <- currentCallbackAncestry
    outcome <- runtimeIO (unregisterCallback store ancestry key)
    pure $ case outcome of
      CallbackUnknown -> SumValue "Result" "Err" [StrValue "unknown callback token"]
      CallbackUnregistered Nothing -> SumValue "Result" "Ok" [UnitValue]
      CallbackUnregistered (Just failure) ->
        SumValue "Result" "Err" [StrValue (diagnosticMessage failure)]

{-| A scoped native call carries the same-run failure sink and its callback
    ancestry. A foreign thread with no such scope enters independently. -}
data CallbackScope = CallbackScope !NativeCallbackCache !(Set.Set CallbackKey) !(IORef (Maybe Diagnostic))

withCallbackDispatch
  :: (Span -> Value -> [Value] -> Evaluator Value)
  -> Span
  -> [(ForeignCallbackSlot, Maybe CallbackKey)]
  -> (Ptr () -> [(Int, Ptr ())] -> IO a)
  -> Evaluator (Either Text (a, Maybe Diagnostic))
withCallbackDispatch apply at tokens action = Evaluator $ \env -> do
  leased <- withCallbackLeases (envCallbackStore env) ([key | (_, Just key) <- tokens]) $ do
    configured <- traverse (prepare env) tokens
    case sequence configured of
      Nothing -> pure (Left "a native callback context could not be prepared")
      Just native -> do
        failure <- newIORef Nothing
        let scope = CallbackScope (envNativeCallbacks env) (envCallbackAncestry env) failure
            plain = [entry | Left entry <- concat native]
            blocks = [entry | Right entry <- concat native]
        built <- withBlockLiterals blocks $ \literals ->
          bracket (newStablePtr scope) freeStablePtr $ \pointer ->
            action (castStablePtrToPtr pointer) (plain <> literals)
        case built of
          Nothing -> pure (Left "an Objective-C block needs a platform with a block runtime")
          Just result -> do
            retained <- readIORef failure
            pure (Right (result, retained))
  pure (Done (fromMaybe (Left "a callback token is no longer registered") leased) env)
 where
  prepare env (slot, token) =
    let cache = envNativeCallbacks env
        owner = foreignCallbackAdapterOwner slot
        signature = foreignCallbackSignature slot
        member = maybe (-1) fst (callbackProjection (foreignCallbackPair slot))
        representative = if IntMap.null (foreignCallbackMembers slot) then -1 else 0
        adapter = findCallbackAdapter cache owner member signature
        registration key = findNativeCallback cache key owner representative signature
          (invokeHandler apply (invocationEnv env) at slot key)
     in case (callbackPlacement (foreignCallbackPair slot), token) of
          (StaticTrampoline position, Nothing) ->
            fmap (\valid -> [Left (position, callbackAdapterCode valid)]) <$> adapter
          (PairedCallback function context, Just key) ->
            fmap (\held -> [Left (function, nativeCallbackCode held), Left (context, nativeCallbackContext held)])
              <$> registration key
          (RegistrationContext context, Just key) ->
            fmap (\held -> [Left (context, nativeCallbackContext held)]) <$> registration key
          (BlockCallback position, Just key) -> do
            held <- registration key
            case held of
              Nothing -> pure Nothing
              Just native ->
                fmap (\code -> [Right (position, code, nativeCallbackContext native)]) <$> nativeCallbackBlockCode native
          _ -> pure Nothing

invocationEnv :: Env -> Env
invocationEnv env = env
  { envFrames = drop (max 0 (length (envFrames env) - envModuleDepth env)) (envFrames env)
  , envDepth = 0
  , envScopes = []
  , envSlots = Nothing
  , envCallbackAncestry = Set.empty
  }

invokeHandler
  :: (Span -> Value -> [Value] -> Evaluator Value)
  -> Env -> Span -> ForeignCallbackSlot -> CallbackKey
  -> Int -> Ptr () -> Maybe [(Int64, Double)] -> IO (Maybe (Int64, Double))
invokeHandler apply env at slot key member scopePointer leaves = do
  scope <- if scopePointer == nullPtr then pure Nothing else do
    active@(CallbackScope owner _ _) <- deRefStablePtr (castPtrToStablePtr scopePointer)
    pure (if owner == envNativeCallbacks env then Just active else Nothing)
  let ancestry = case scope of
        Nothing -> Set.empty
        Just (CallbackScope _ ancestors _) -> ancestors
      local = env{envCallbackAncestry = Set.insert key ancestry}
  outcome <- invokeCallback (envCallbackStore env) key $ \registration -> do
    performed <- try @SomeException (runHandler local registration)
    case performed of
      Left problem -> Left <$> callbackDiagnostic Error "E7001" at (Text.pack (displayException problem))
      Right (Done value _) -> pure (Right value)
      Right (Aborted failure) -> pure (Left failure)
      Right Unwound{} -> Left <$> callbackDiagnostic Error "E7001" at "control escaped a callback invocation"
  case outcome of
    CallbackCompleted value -> pure (Just value)
    CallbackFailed failure -> do
      case scope of
        Just (CallbackScope _ _ sink) -> atomicModifyIORef' sink (\held -> (held <|> Just failure, ()))
        Nothing -> pure ()
      pure Nothing
    CallbackRetired shouldWarn -> do
      when shouldWarn $ do
        warning <- callbackDiagnostic Warning "W7027" at "a foreign library invoked a retired callback"
        recordForeignDiagnostic (envForeignStore env) warning
      pure Nothing
    CallbackUnavailable -> pure Nothing
 where
  runHandler local registration = do
    let Evaluator evaluate = do
          (signature, handler) <- case (member, registration) of
            (-1, _) | IntMap.null (foreignCallbackMembers slot) ->
              pure (foreignCallbackSignature slot, registration)
            (_, RecordValue _ fields)
              | Just (field, signature) <- IntMap.lookup member (foreignCallbackMembers slot)
              , Just handler <- lookup field fields -> pure (signature, handler)
            _ -> abortAt (Just at) "E7017" "a callback group member has no registered handler" Nothing
          raw <- case leaves of
            Nothing -> abortAt (Just at) "E7017" "could not decode callback argument storage" Nothing
            Just fields -> do
              decoded <- runtimeIO (decodeCallbackArguments signature fields)
              case decoded of
                Left InvalidReturnedText ->
                  abortAt (Just at) "E7025" "a callback received text that is not valid UTF-8" Nothing
                Left _ -> abortAt (Just at) "E7017" "invalid input to a foreign callback" Nothing
                Right values -> pure values
          let kinds = [crossing | CallbackValue crossing <- callbackParameters signature]
          arguments <- traverse (uncurry (incoming at)) (zip kinds raw)
          result <- apply at handler arguments
          case outgoing (callbackResult signature) result of
            Nothing -> abortAt (Just at) "E7017" "callback returned a value outside its declared result type" Nothing
            Just returned -> pure returned
    evaluate local

incoming :: Span -> Crossing -> CrossedValue -> Evaluator Value
incoming at crossing value = case (crossing, value) of
  (BytesCrossing, CrossedBytes bytes) -> pure (BytesValue bytes)
  (HandleCrossing expected, CrossedHandle actual address)
    | expected == actual && address /= 0 -> pure (ForeignHandleValue actual address BorrowedClaim)
  _ -> either (\_ -> abortAt (Just at) "E7017" "foreign callback argument does not match its declaration" Nothing)
         pure (convertForeignValue "callback argument" crossing value)

outgoing :: CallbackResult -> Value -> Maybe (Int64, Double)
outgoing result value = case (result, value) of
  (CallbackVoid, UnitValue) -> Just (0, 0)
  (CallbackBool _, BoolValue flag) -> Just (if flag then 1 else 0, 0)
  (CallbackSigned width _, IntValue _ integer)
    | fitsCrossing (SignedCrossing width) integer -> Just (fromInteger integer, 0)
  (CallbackUnsigned width _, IntValue _ integer)
    | fitsCrossing (UnsignedCrossing width) integer -> Just (fromInteger integer, 0)
  (CallbackFloat width _, FloatValue actual floating)
    | width == actual -> Just (0, floating)
  _ -> Nothing

callbackDiagnostic :: Severity -> Text -> Span -> Text -> IO Diagnostic
callbackDiagnostic severity code at message =
  case mkDiagnosticCode code >>= \valid -> diagnostic valid severity at message of
    Just found -> pure found
    Nothing -> ioError (userError "invalid callback diagnostic")
