{-| @Eval.Child — programs started and still running

    `runProgram` starts a program, waits for it to finish, and answers
    everything it wrote. That is the right shape for a step in a script and the
    wrong shape for three things a tool has to do: show output while it is
    still being produced, feed one program's output into another's input, and
    stop a program that is taking too long.

    Each of those needs the program to be a thing the language holds rather
    than a call that has already finished, so a started program is kept here
    and named by a token — the same arrangement open files use, and for the
    same reason: a running program is not a value that may be copied, and two
    copies each believing they own its output would each read half of it.

    A store belongs to one evaluation. When that evaluation ends, whatever it
    started is stopped rather than left behind: a program that outlived the one
    that started it would hold its output pipes open and keep running with
    nobody to read them. -}
module Pudu.Eval.Child
  ( ChildStore
  , newChildStore
  , closeChildStore
  , startChild
  , readChildChunk
  , readChildErrorChunk
  , writeChildChunk
  , closeChildInput
  , waitChild
  , waitChildWithin
  , stopChild
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception (IOException, try)
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Eval.Io (IoOutcome (..))
import System.Exit (ExitCode (ExitFailure, ExitSuccess))
import System.IO (Handle, hClose, hSetBinaryMode)
import System.Process
  ( CreateProcess (..)
  , ProcessHandle
  , StdStream (CreatePipe)
  , createProcess
  , getProcessExitCode
  , proc
  , terminateProcess
  , waitForProcess
  )

{-| One started program: its three pipes and the handle that waits for it. -}
data Child = Child
  { childInput :: !(Maybe Handle)
  , childOutput :: !(Maybe Handle)
  , childErrors :: !(Maybe Handle)
  , childProcess :: !ProcessHandle
  }

data ChildStore = ChildStore
  { childTable :: !(IORef (IntMap Child))
  , childNextToken :: !(IORef Int)
  }

newChildStore :: IO ChildStore
newChildStore = ChildStore <$> newIORef IntMap.empty <*> newIORef 1

{-| Stop everything this evaluation started, in whatever state it is in.

    Asking rather than waiting: a program that has not finished by the time the
    one that started it has is not going to be read from again, and waiting for
    it would hang the compiler behind a child nobody is listening to. -}
closeChildStore :: ChildStore -> IO ()
closeChildStore store = do
  children <- atomicModifyIORef' (childTable store) (\table -> (IntMap.empty, table))
  mapM_ release (IntMap.elems children)
 where
  release child = do
    _ <- try (mapM_ hClose (childInput child)) :: IO (Either IOException ())
    _ <- try (mapM_ hClose (childOutput child)) :: IO (Either IOException ())
    _ <- try (mapM_ hClose (childErrors child)) :: IO (Either IOException ())
    _ <- try (terminateProcess (childProcess child)) :: IO (Either IOException ())
    pure ()

{-| Start a program, answering the token that names it.

    All three of its streams are pipes, because which of them a caller will
    want is not known here and a stream left attached to this program's own
    would put a child's output where the compiler's belongs. -}
startChild :: ChildStore -> FilePath -> [Text] -> IO (IoOutcome Int)
startChild store program arguments = do
  started <-
    try
      ( createProcess
          (proc program (map Text.unpack arguments))
            { std_in = CreatePipe
            , std_out = CreatePipe
            , std_err = CreatePipe
            }
      )
  case started of
    Left problem -> pure (IoFailed (Text.pack (show (problem :: IOException))))
    Right (input, output, errors, handle) -> do
      mapM_ (`hSetBinaryMode` True) input
      mapM_ (`hSetBinaryMode` True) output
      mapM_ (`hSetBinaryMode` True) errors
      token <- atomicModifyIORef' (childNextToken store) (\next -> (next + 1, next))
      atomicModifyIORef'
        (childTable store)
        (\table -> (IntMap.insert token (Child input output errors handle) table, ()))
      pure (IoDone token)

withChild :: ChildStore -> Int -> (Child -> IO (IoOutcome a)) -> IO (IoOutcome a)
withChild store token action = do
  table <- readIORef (childTable store)
  case IntMap.lookup token table of
    Nothing -> pure (IoFailed "this token names no started program")
    Just child -> action child

{-| Read what a program has written, waiting only until there is something.

    Nothing means the stream ended, which for a child's output means it has
    stopped writing — usually because it has finished. An empty run of bytes is
    not used for that, because a reader could not tell it from a pause. -}
readChildChunk :: ChildStore -> Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
readChildChunk store token wanted =
  withChild store token (readFrom wanted . childOutput)

readChildErrorChunk :: ChildStore -> Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
readChildErrorChunk store token wanted =
  withChild store token (readFrom wanted . childErrors)

readFrom :: Int -> Maybe Handle -> IO (IoOutcome (Maybe ByteString.ByteString))
readFrom _ Nothing = pure (IoFailed "this program has no such stream")
readFrom wanted (Just handle)
  | wanted < 1 = pure (IoFailed "a read of no bytes reads nothing")
  | otherwise = do
      outcome <- try (ByteString.hGetSome handle wanted)
      pure $ case outcome of
        Left problem -> IoFailed (Text.pack (show (problem :: IOException)))
        Right piece
          | ByteString.null piece -> IoDone Nothing
          | otherwise -> IoDone (Just piece)

{-| Write to a program's input. -}
writeChildChunk :: ChildStore -> Int -> ByteString.ByteString -> IO (IoOutcome ())
writeChildChunk store token payload =
  withChild store token $ \child -> case childInput child of
    Nothing -> pure (IoFailed "this program has no input to write to")
    Just handle -> do
      outcome <- try (ByteString.hPut handle payload >> pure ())
      pure (either (IoFailed . Text.pack . show @IOException) IoDone outcome)

{-| Close a program's input, which is how it is told there is no more.

    A program reading until its input ends waits forever if nothing closes it,
    so this is not an optimisation: it is the difference between a pipeline
    that finishes and one that hangs. -}
closeChildInput :: ChildStore -> Int -> IO (IoOutcome ())
closeChildInput store token =
  withChild store token $ \child -> case childInput child of
    Nothing -> pure (IoDone ())
    Just handle -> do
      outcome <- try (hClose handle)
      pure (either (IoFailed . Text.pack . show @IOException) IoDone outcome)

{-| Wait for a program to finish, answering the status it left. -}
waitChild :: ChildStore -> Int -> IO (IoOutcome Int)
waitChild store token =
  withChild store token $ \child -> do
    outcome <- try (waitForProcess (childProcess child))
    pure (either (IoFailed . Text.pack . show @IOException) (IoDone . statusOf) outcome)

{-| Wait a bounded time, answering nothing when the program is still running.

    Asked repeatedly rather than by an alarm, because what a caller does about
    a program that is taking too long — wait longer, read more of its output,
    stop it — is the caller's decision and cannot be made here. -}
waitChildWithin :: ChildStore -> Int -> Int -> IO (IoOutcome (Maybe Int))
waitChildWithin store token millis =
  withChild store token $ \child -> poll child (max 0 millis)
 where
  step = 10
  poll child remaining = do
    outcome <- try (getProcessExitCode (childProcess child))
    case outcome of
      Left problem -> pure (IoFailed (Text.pack (show (problem :: IOException))))
      Right (Just code) -> pure (IoDone (Just (statusOf code)))
      Right Nothing
        | remaining <= 0 -> pure (IoDone Nothing)
        | otherwise -> do
            threadDelay (step * 1000)
            poll child (remaining - step)

{-| Stop a program, and wait for it to actually be gone.

    Waiting afterwards is what makes this an answer rather than a request: a
    caller that stopped a program and moved on would leave it being cleaned up
    at some later moment, and a test asserting it had stopped would be right
    only sometimes. -}
stopChild :: ChildStore -> Int -> IO (IoOutcome Int)
stopChild store token =
  withChild store token $ \child -> do
    outcome <-
      try
        ( do
            terminateProcess (childProcess child)
            waitForProcess (childProcess child)
        )
    pure (either (IoFailed . Text.pack . show @IOException) (IoDone . statusOf) outcome)

statusOf :: ExitCode -> Int
statusOf code = case code of
  ExitSuccess -> 0
  ExitFailure status -> fromIntegral status
