{-| @Eval.Runtime — owns resources for one evaluation lifetime. -}
module Pudu.Eval.Runtime
  ( withRuntimeEnv
  ) where

import Control.Exception (bracket)
import Data.Maybe (mapMaybe)
import Pudu.Diagnostic
  ( Diagnostic, Severity (Warning), diagnostic, diagnosticMessage, diagnosticSpan, mkDiagnosticCode )
import Pudu.Eval.Child (closeChildStore, newChildStore)
import Pudu.Eval.Concurrent (closeConcurrentStore, newConcurrentStore)
import Pudu.Eval.Desktop (closeDesktopStore, newDesktopStore)
import Pudu.Eval.AudioStream (closeAudioStreamStore, newAudioStreamStore)
import Pudu.Eval.Env (Env, emptyEnv)
import Pudu.Eval.Handle (closeHandleStore, newHandleStore)
import Pudu.Eval.Socket (closeSocketStore, newSocketStore)
import Pudu.Eval.Tls (closeTlsStore, newTlsStore)
import Pudu.Foreign.Callback.Native (closeNativeCallbackCache, newNativeCallbackCache)
import Pudu.Foreign.CallbackStore (closeCallbackStore, newCallbackStore)
import Pudu.Foreign.Ownership
  ( closeForeignStore
  , newForeignStore
  , takeForeignDiagnostics
  )

{-| The callback may run several actions before teardown. Workers and child
    processes stop before the transports and handles they can still access. -}
withRuntimeEnv :: (Env -> IO a) -> IO (a, [Diagnostic])
withRuntimeEnv action =
  bracket newHandleStore closeHandleStore $ \handles ->
    bracket newSocketStore closeSocketStore $ \sockets ->
      bracket newTlsStore closeTlsStore $ \secured ->
        bracket newForeignStore closeForeignStore $ \foreignStore -> do
          (result, callbackProblems) <-
            bracket newChildStore closeChildStore $ \children ->
              bracket newConcurrentStore closeConcurrentStore $ \concurrent ->
                bracket newDesktopStore closeDesktopStore $ \desktop ->
                  bracket newAudioStreamStore closeAudioStreamStore $ \audioStreams ->
                    bracket newCallbackStore closeCallbacks $ \callbacks ->
                      bracket newNativeCallbackCache closeNativeCallbackCache $ \nativeCallbacks -> do
                        value <- action (emptyEnv handles children sockets secured concurrent desktop audioStreams foreignStore callbacks nativeCallbacks)
                        closeNativeCallbackCache nativeCallbacks
                        failures <- closeCallbackStore callbackDrainPatience callbacks
                        pure (value, mapMaybe callbackCleanupWarning failures)
          closeForeignStore foreignStore
          problems <- takeForeignDiagnostics foreignStore
          pure (result, callbackProblems <> problems)
 where
  closeCallbacks store = closeCallbackStore callbackDrainPatience store >> pure ()

callbackDrainPatience :: Int
callbackDrainPatience = 5 * 1000 * 1000

callbackCleanupWarning :: Diagnostic -> Maybe Diagnostic
callbackCleanupWarning failure = do
  code <- mkDiagnosticCode "W7027"
  diagnostic code Warning (diagnosticSpan failure)
    ("foreign callback failed before teardown: " <> diagnosticMessage failure)
