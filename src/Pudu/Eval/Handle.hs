{-| @Eval.Handle.Module — open files, held for the length of a bracket -}
module Pudu.Eval.Handle
  ( closeAllHandles
  , closeHandleAt
  , flushHandleAt
  , openAppendHandle
  , openReadHandle
  , openWriteHandle
  , readHandleChunk
  , writeHandleChunk
  ) where

import Control.Exception (IOException, try)
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Text as Text
import Pudu.Eval.Io (IoOutcome (..))
import System.IO
  ( BufferMode (BlockBuffering)
  , Handle
  , IOMode (AppendMode, ReadMode, WriteMode)
  , hClose
  , hFlush
  , hSetBinaryMode
  , hSetBuffering
  , openFile
  )
import System.IO.Unsafe (unsafePerformIO)

{-| @Eval.Handle.Open — one file the program has open, and which way.

    The direction is kept because the operations differ by it: reading from a
    handle opened for writing is a mistake worth naming rather than an error
    from the operating system about a file descriptor the program never saw. -}
data OpenHandle
  = OpenReader !Handle
  | OpenWriter !Handle

{-| Every handle the program has open, keyed by the token the program holds.

    The table lives here rather than in the evaluation environment because an
    open file is already process-wide: the environment is threaded and copied
    through evaluation, and a handle closed down one branch has to be closed on
    every other. Keeping it beside the operations that use it also means the
    token a program holds is an ordinary integer with no meaning outside this
    module, so a program cannot manufacture one. -}
handleTable :: IORef (IntMap OpenHandle)
{-# NOINLINE handleTable #-}
handleTable = unsafePerformIO (newIORef IntMap.empty)

{-| The next token to hand out.

    Tokens are never reused. A reused token would let a program holding a stale
    one reach a file opened later by something else, which is the failure a
    closed handle exists to prevent. -}
nextToken :: IORef Int
{-# NOINLINE nextToken #-}
nextToken = unsafePerformIO (newIORef 1)

{-| Open a file for reading, answering the token that names it. -}
openReadHandle :: FilePath -> IO (IoOutcome Int)
openReadHandle path = openWith path ReadMode OpenReader

{-| Open a file for writing, replacing whatever it held. -}
openWriteHandle :: FilePath -> IO (IoOutcome Int)
openWriteHandle path = openWith path WriteMode OpenWriter

{-| Open a file for writing after what it already holds. -}
openAppendHandle :: FilePath -> IO (IoOutcome Int)
openAppendHandle path = openWith path AppendMode OpenWriter

openWith :: FilePath -> IOMode -> (Handle -> OpenHandle) -> IO (IoOutcome Int)
openWith path mode wrap = do
  attempted <- try (openFile path mode) :: IO (Either IOException Handle)
  case attempted of
    Left problem -> pure (IoFailed (Text.pack (show problem)))
    Right handle -> do
      hSetBinaryMode handle True
      hSetBuffering handle (BlockBuffering Nothing)
      token <- atomicModifyIORef' nextToken (\value -> (value + 1, value))
      atomicModifyIORef' handleTable (\table -> (IntMap.insert token (wrap handle) table, ()))
      pure (IoDone token)

{-| Read at most the requested count of bytes.

    An answer of `Nothing` is the end of the input, and is distinct from an
    answer of zero bytes: a reader that could not tell them apart would either
    stop early on a slow source or never stop at all. -}
readHandleChunk :: Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
readHandleChunk token count
  | count <= 0 = pure (IoDone (Just ByteString.empty))
  | otherwise = do
      found <- lookupHandle token
      case found of
        Nothing -> pure closedFailure
        Just (OpenWriter _) -> pure (IoFailed "the handle was opened for writing")
        Just (OpenReader handle) -> do
          attempted <-
            try (ByteString.hGet handle count) :: IO (Either IOException ByteString.ByteString)
          case attempted of
            Left problem -> pure (IoFailed (Text.pack (show problem)))
            Right chunk
              | ByteString.null chunk -> pure (IoDone Nothing)
              | otherwise -> pure (IoDone (Just chunk))

{-| Write bytes to an open handle. -}
writeHandleChunk :: Int -> ByteString.ByteString -> IO (IoOutcome ())
writeHandleChunk token chunk = do
  found <- lookupHandle token
  case found of
    Nothing -> pure closedFailure
    Just (OpenReader _) -> pure (IoFailed "the handle was opened for reading")
    Just (OpenWriter handle) -> guarded (ByteString.hPut handle chunk)

{-| Push what is buffered out to the file. -}
flushHandleAt :: Int -> IO (IoOutcome ())
flushHandleAt token = do
  found <- lookupHandle token
  case found of
    Nothing -> pure closedFailure
    Just (OpenReader _) -> pure (IoDone ())
    Just (OpenWriter handle) -> guarded (hFlush handle)

{-| Close a handle and forget its token.

    Closing one that is already closed is not a failure. A bracket closes on
    every path out of it, and a caller who closed early should not be reported
    against for the bracket doing what it promised. -}
closeHandleAt :: Int -> IO (IoOutcome ())
closeHandleAt token = do
  taken <-
    atomicModifyIORef' handleTable $ \table ->
      (IntMap.delete token table, IntMap.lookup token table)
  case taken of
    Nothing -> pure (IoDone ())
    Just entry -> guarded (hClose (handleOf entry))

{-| Close everything still open.

    A program that ended holding a handle has buffered writes that nothing has
    pushed to the file yet, and a process exiting does not push them. This is
    what makes the last bytes a program wrote actually reach the disk. -}
closeAllHandles :: IO ()
closeAllHandles = do
  table <-
    atomicModifyIORef' handleTable (\current -> (IntMap.empty, current))
  mapM_ closeQuietly (IntMap.elems table)
 where
  closeQuietly entry = do
    _ <- try (hClose (handleOf entry)) :: IO (Either IOException ())
    pure ()

handleOf :: OpenHandle -> Handle
handleOf entry = case entry of
  OpenReader handle -> handle
  OpenWriter handle -> handle

lookupHandle :: Int -> IO (Maybe OpenHandle)
lookupHandle token = IntMap.lookup token <$> readIORef handleTable

closedFailure :: IoOutcome a
closedFailure = IoFailed "the handle is closed"

guarded :: IO () -> IO (IoOutcome ())
guarded action = do
  attempted <- try action :: IO (Either IOException ())
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right () -> IoDone ()
