{-| @Eval.Runtime — owns resources for one evaluation lifetime. -}
module Pudu.Eval.Runtime
  ( withRuntimeEnv
  ) where

import Control.Exception (bracket)
import Pudu.Diagnostic (Diagnostic)
import Pudu.Eval.Child (closeChildStore, newChildStore)
import Pudu.Eval.Concurrent (closeConcurrentStore, newConcurrentStore)
import Pudu.Eval.Env (Env, emptyEnv)
import Pudu.Eval.Handle (closeHandleStore, newHandleStore)
import Pudu.Eval.Socket (closeSocketStore, newSocketStore)
import Pudu.Eval.Tls (closeTlsStore, newTlsStore)
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
          result <- bracket newChildStore closeChildStore $ \children ->
            bracket newConcurrentStore closeConcurrentStore $ \concurrent ->
              action (emptyEnv handles children sockets secured concurrent foreignStore)
          closeForeignStore foreignStore
          problems <- takeForeignDiagnostics foreignStore
          pure (result, problems)
