{-| Controlled Pudu mutex admission and real local Database refusal. -}
module Pudu.Eval.MutexSpec (mutexProperties) where

import Control.Concurrent (ThreadId, forkIO, killThread, threadDelay)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar, tryReadMVar)
import Data.IORef (atomicModifyIORef', newIORef, readIORef)
import Control.Exception (bracket, finally)
import Control.Monad (replicateM, when)
import GHC.Conc (BlockReason (BlockedOnSTM), ThreadStatus (ThreadBlocked, ThreadDied, ThreadFinished), listThreads, threadStatus)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (compileProgram, programDependencies, programIntegerKinds, rootCompileResult, programDiagnostics)
import Pudu.Diagnostic (hasErrors)
import Pudu.Eval (EvalOutcome (..), outcomeOf)
import Pudu.Eval.Common (codesOf, codesOfConstant)
import Pudu.Eval.Concurrent (ConcurrentStore, closeConcurrentStore, concurrentCounts, mutexClose, mutexDispose, mutexLock, mutexLockWithin, mutexNew, mutexUnlock, newConcurrentStore)
import Pudu.Eval.Io (IoOutcome (..))
import Pudu.Eval.Program (evaluateInteractiveBlock, evaluateProgramEntry)
import Pudu.Eval.Env (Env (..), Evaluator (..))
import Pudu.Eval.Runtime (withRuntimeEnv)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Declaration (FunctionDeclaration), Function (..), FunctionBody (BlockBody), Module (..))
import qualified Data.Map.Strict as Map
import Pudu.Eval.Render (renderValue)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Timeout (timeout)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

mutexProperties :: [(String, IO Property)]
mutexProperties = [("mutex admission preserves owners and retires timers", nativeAdmission),
  ("local database admission is finite without interrupting transactions", publicAdmission),
  ("mutex close joins owners and survives closer interruption", joinedClose),
  ("database scope retirement removes registrations before teardown", scopeRetirement)]

nativeAdmission :: IO Property
nativeAdmission = bracket newConcurrentStore closeConcurrentStore $ \store -> do
  token <- mutexNew store
  held <- mutexLock store token
  recursive <- timeout 1000000 (mutexLock store token)
  boundedRecursive <- mutexLockWithin store (toInteger token) 0
  let refusal = IoFailed "the lock is already owned by this thread"
      competing millis = do
        answer <- newEmptyMVar
        worker <- forkIO (mutexLockWithin store (toInteger token) millis >>= putMVar answer)
        timeout 1000000 (takeMVar answer) `finally` killThread worker
  probe <- competing 0
  expired <- competing 1
  stillHeld <- timeout 1000000 (mutexLock store token)
  invalid <- mapM (mutexLockWithin store (toInteger token)) [-1, 3600001, toInteger (maxBound :: Int) * 2]
  unknown <- mutexLockWithin store (toInteger token + toInteger (maxBound :: Int) + 1) 0
  lifetimes <- mapM (parked store token) [False, True]
  _ <- mutexLock store token
  races <- replicateM 20 $ do
    current <- mutexNew store
    _ <- mutexLock store current
    answer <- newEmptyMVar
    worker <- forkIO $ do
      outcome <- mutexLockWithin store (toInteger current) 60000
      when (outcome == IoDone True) $ do { _ <- mutexUnlock store current; pure () }
      putMVar answer outcome
    waiting <- timeout 1000000 (untilBlocked worker)
    _ <- mutexUnlock store current
    disposed <- mutexDispose store current
    outcome <- timeout 1000000 (takeMVar answer) `finally` killThread worker
    _ <- mutexDispose store current
    pure (waiting == Just () && ((disposed == IoDone () && outcome == Just (IoFailed "no such lock"))
      || outcome == Just (IoDone True)))
  _ <- mutexUnlock store token
  inside <- newIORef (0 :: Int, 0 :: Int)
  answers <- newEmptyMVar
  _ <- mutexLock store token
  workers <- replicateM 8 $ forkIO $ do
    outcome <- mutexLockWithin store (toInteger token) 60000
    when (outcome == IoDone True) $ do
      atomicModifyIORef' inside (\(n, widest) -> ((n + 1, max widest (n + 1)), ()))
      threadDelay 1000
      atomicModifyIORef' inside (\(n, widest) -> ((n - 1, widest), ()))
      _ <- mutexUnlock store token
      pure ()
    putMVar answers outcome
  parkedOwners <- timeout 1000000 (mapM_ untilBlocked workers)
  _ <- mutexUnlock store token
  admitted <- timeout 5000000 (replicateM 8 (takeMVar answers)) `finally` mapM_ killThread workers
  widest <- readIORef inside
  _ <- mutexDispose store token
  retired <- mutexLockWithin store (toInteger token) 0
  counts <- concurrentCounts store
  constant <- codesOfConstant "{ let _ = mutexAcquireWithin(1, 0)\n true }"
  wrongType <- codesOf "mutexAcquireWithin(1, true)"
  wrongArity <- codesOf "mutexAcquireWithin(1)"
  pure $ conjoin [held === IoDone (), recursive === Just refusal, boundedRecursive === refusal,
    probe === Just (IoDone False), expired === Just (IoDone False), stillHeld === Just refusal,
    invalid === replicate 3 (IoFailed "invalid mutex wait"), unknown === IoFailed "no such lock",
    lifetimes === [True, True], races === replicate 20 True, parkedOwners === Just (),
    admitted === Just (replicate 8 (IoDone True)), widest === (0, 1), retired === IoFailed "no such lock",
    counts === (0, 0, 0, 0), constant === ["E7009"], wrongType === ["E3001"], wrongArity === ["E3003"]]

parked :: ConcurrentStore -> Int -> Bool -> IO Bool
parked store token canceled = do
  before <- listThreads
  answer <- newEmptyMVar
  stopped <- newEmptyMVar
  worker <- forkIO $ (do
    outcome <- mutexLockWithin store (toInteger token) 60000
    when (outcome == IoDone True) $ do { _ <- mutexUnlock store token; pure () }
    putMVar answer outcome) `finally` putMVar stopped ()
  waiting <- timeout 1000000 (untilBlocked worker)
  during <- listThreads
  let timers = filter (\thread -> thread /= worker && thread `notElem` before) during
  if canceled then killThread worker else do { _ <- mutexUnlock store token; pure () }
  result <- if canceled then pure Nothing else timeout 1000000 (takeMVar answer)
  ended <- timeout 1000000 (takeMVar stopped)
  retired <- timeout 1000000 (mapM_ untilRetired timers)
  mapM_ killThread (worker : timers)
  if canceled then do { _ <- mutexUnlock store token; pure () } else do { _ <- mutexLock store token; pure () }
  pure (waiting == Just () && ended == Just () && not (null timers) && retired == Just ()
    && (canceled || result == Just (IoDone True)))

untilBlocked :: ThreadId -> IO ()
untilBlocked thread = do
  status <- threadStatus thread
  case status of
    ThreadBlocked BlockedOnSTM -> pure ()
    _ -> threadDelay 100 >> untilBlocked thread

untilRetired :: ThreadId -> IO ()
untilRetired thread = do
  status <- threadStatus thread
  case status of
    ThreadFinished -> pure ()
    ThreadDied -> pure ()
    _ -> threadDelay 100 >> untilRetired thread

publicAdmission :: IO Property
publicAdmission = do
  program <- compileProgram "test-fixtures/stdlib/UsesMutexWait.pudu"
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (counterexample (show (programDiagnostics program)) False)
    Just parsed -> conjoin <$> mapM (\mode -> do
      previous <- lookupEnv "PUDU_EVAL"
      setEnv "PUDU_EVAL" mode
      outcome <- timeout 20000000 (evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" parsed)
        `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
      pure $ case outcome of
        Nothing -> counterexample (mode <> ": admission fixture exceeded external deadline") False
        Just result -> counterexample (mode <> ": " <> show (outcomeDiagnostics result)) $ conjoin
          [(renderValue <$> outcomeValue result) === Just "0", hasErrors (outcomeDiagnostics result) === False]) ["tree", "compiled"]

joinedClose :: IO Property
joinedClose = bracket newConcurrentStore closeConcurrentStore $ \store -> do
  token <- mutexNew store
  _ <- mutexLock store token
  self <- timeout 1000000 (mutexClose store (toInteger token))
  _ <- mutexUnlock store token
  closed <- mutexClose store (toInteger token)
  repeated <- mutexClose store (toInteger token)
  unknown <- mapM (mutexClose store) [0, -1, toInteger token + toInteger (maxBound :: Int) + 1]
  races <- mapM (closingOwner store) [False, True]
  counts <- concurrentCounts store
  constant <- codesOfConstant "{ let _ = mutexClose(1)\n true }"
  wrongType <- codesOf "mutexClose(true)"
  wrongArity <- codesOf "mutexClose()"
  pure $ conjoin [self === Just (IoFailed "cannot close a lock owned by this thread"), closed === IoDone (),
    repeated === IoFailed "no such lock", unknown === replicate 3 (IoFailed "no such lock"),
    races === [True, True], counts === (0, 0, 0, 0), constant === ["E7009"],
    wrongType === ["E3001"], wrongArity === ["E3003"]]

closingOwner :: ConcurrentStore -> Bool -> IO Bool
closingOwner store canceled = do
  token <- mutexNew store
  _ <- mutexLock store token
  entrants <- newEmptyMVar
  workers <- replicateM 3 $ forkIO (mutexLockWithin store (toInteger token) 60000 >>= putMVar entrants)
  parkedEntrants <- timeout 1000000 (mapM_ untilBlocked workers)
  answer <- newEmptyMVar
  stopped <- newEmptyMVar
  closer <- forkIO $ (mutexClose store (toInteger token) >>= putMVar answer) `finally` putMVar stopped ()
  parkedCloser <- timeout 1000000 (untilBlocked closer)
  early <- tryReadMVar answer
  denied <- mutexLockWithin store (toInteger token) 0
  disposed <- mutexDispose store token
  foreignResult <- newEmptyMVar
  outsider <- forkIO (mutexUnlock store token >>= putMVar foreignResult)
  foreignRelease <- timeout 1000000 (takeMVar foreignResult)
  refused <- timeout 1000000 (replicateM 3 (takeMVar entrants))
  when canceled (killThread closer)
  ownerRelease <- mutexUnlock store token
  completed <- if canceled then pure Nothing else timeout 1000000 (takeMVar answer)
  ended <- timeout 1000000 (takeMVar stopped)
  counts <- concurrentCounts store
  mapM_ killThread (closer : outsider : workers)
  pure (parkedEntrants == Just () && parkedCloser == Just () && early == Nothing
    && denied == IoFailed "no such lock" && disposed == IoFailed "the lock is still held"
    && foreignRelease == Just (IoFailed "the lock is owned by another thread")
    && refused == Just (replicate 3 (IoFailed "no such lock")) && ownerRelease == IoDone ()
    && (canceled || completed == Just (IoDone ())) && ended == Just () && counts == (0, 0, 0, 0))

scopeRetirement :: IO Property
scopeRetirement = do
  program <- compileProgram "test-fixtures/stdlib/UsesDbScopeRetirement.pudu"
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (counterexample (show (programDiagnostics program)) False)
    Just parsed -> case [block | Located _ (FunctionDeclaration function) <- moduleDeclarations parsed,
      locatedValue (functionName function) == "main", Just (Located _ (BlockBody block)) <- [functionBody function]] of
      [block] -> conjoin <$> mapM (\mode -> do
        bodies <- if mode == "tree" then pure Nothing else Just <$> newIORef Map.empty
        result <- timeout 20000000 $ withRuntimeEnv $ \initial -> do
          let Evaluator execute = evaluateInteractiveBlock False (programIntegerKinds program) (programDependencies program) parsed block
          outcome <- execute initial{envEffects = True, envCompiledBodies = bodies}
          counts <- concurrentCounts (envConcurrentStore initial)
          pure (outcomeOf outcome, counts)
        pure $ case result of
          Nothing -> counterexample (mode <> ": scope retirement exceeded external deadline") False
          Just ((outcome, counts), problems) -> counterexample (mode <> ": " <> show (outcomeDiagnostics outcome <> problems)) $ conjoin
            [(renderValue <$> outcomeValue outcome) === Just "0", hasErrors (outcomeDiagnostics outcome <> problems) === False,
              counterexample "completed scopes leave no private registrations" (counts === (0, 0, 0, 0))]) ["tree", "compiled"]
      _ -> pure (counterexample "scope fixture needs one main block" False)
