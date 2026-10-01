{-| @Pudu.Eval.Compile.Cache.Module — compiled function bodies kept for a run -}
module Pudu.Eval.Compile.Cache
  ( compiledBody
  ) where

import Data.IORef (IORef, atomicModifyIORef', readIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Pudu.Eval.Env (Evaluator, runtimeIO)
import Pudu.Eval.Value (Value)
import Pudu.Source (Span)

{-| A function's body compiled, read from the run's cache when it was compiled
    before. The cache is shared by every thread of the run, so it is updated
    atomically; two threads compiling the same body at once both answer a
    correct compilation and one of them is kept. -}
compiledBody
  :: IORef (Map Span (Evaluator Value)) -> Span -> Evaluator (Evaluator Value) -> Evaluator (Evaluator Value)
compiledBody cache bodySpan compile = do
  held <- runtimeIO (readIORef cache)
  case Map.lookup bodySpan held of
    Just code -> pure code
    Nothing -> do
      code <- compile
      runtimeIO (atomicModifyIORef' cache (\known -> (Map.insert bodySpan code known, ())))
      pure code
