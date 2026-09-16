{-| @Eval.Handle.Module — open files, held for the length of a bracket -}
module Pudu.Eval.Handle
  ( HandleStore
  , closeHandleStore
  , closeHandleAt
  , flushHandleAt
  , openAppendHandle
  , openReadHandle
  , openWriteHandle
  , readHandleChunk
  , newHandleStore
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

{-| @Eval.Handle.Open — one file the program has open, and which way.

    The direction is kept because the operations differ by it: reading from a
    handle opened for writing is a mistake worth naming rather than an error
    from the operating system about a file descriptor the program never saw. -}
data OpenHandle
  = OpenReader !Handle
  | OpenWriter !Handle

{-| Every handle one evaluation has open, keyed by its opaque token.

    The environment carries this store by identity, so copied frames and child
    threads observe the same close while concurrent evaluations remain
    isolated. -}
data HandleStore = HandleStore
  { handleTable :: !(IORef (IntMap OpenHandle))
  , handleNextToken :: !(IORef Int)
  }

{-| Allocate an isolated handle store. Tokens are never reused within it. -}
newHandleStore :: IO HandleStore
newHandleStore = HandleStore <$> newIORef IntMap.empty <*> newIORef 1

{-| Open a file for reading, answering the token that names it. -}
openReadHandle :: HandleStore -> FilePath -> IO (IoOutcome Int)
openReadHandle store path = openWith store path ReadMode OpenReader

{-| Open a file for writing, replacing whatever it held. -}
openWriteHandle :: HandleStore -> FilePath -> IO (IoOutcome Int)
openWriteHandle store path = openWith store path WriteMode OpenWriter

{-| Open a file for writing after what it already holds. -}
openAppendHandle :: HandleStore -> FilePath -> IO (IoOutcome Int)
openAppendHandle store path = openWith store path AppendMode OpenWriter

openWith :: HandleStore -> FilePath -> IOMode -> (Handle -> OpenHandle) -> IO (IoOutcome Int)
openWith store path mode wrap = do
  attempted <- try (openFile path mode) :: IO (Either IOException Handle)
  case attempted of
    Left problem -> pure (IoFailed (Text.pack (show problem)))
    Right handle -> do
      hSetBinaryMode handle True
      hSetBuffering handle (BlockBuffering Nothing)
      token <- atomicModifyIORef' (handleNextToken store) (\value -> (value + 1, value))
      atomicModifyIORef' (handleTable store) (\table -> (IntMap.insert token (wrap handle) table, ()))
      pure (IoDone token)

{-| Read at most the requested count of bytes.

    An answer of `Nothing` is the end of the input, and is distinct from an
    answer of zero bytes: a reader that could not tell them apart would either
    stop early on a slow source or never stop at all. -}
readHandleChunk :: HandleStore -> Int -> Int -> IO (IoOutcome (Maybe ByteString.ByteString))
readHandleChunk store token count
  | count <= 0 = pure (IoDone (Just ByteString.empty))
  | otherwise = do
      found <- lookupHandle store token
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
writeHandleChunk :: HandleStore -> Int -> ByteString.ByteString -> IO (IoOutcome ())
writeHandleChunk store token chunk = do
  found <- lookupHandle store token
  case found of
    Nothing -> pure closedFailure
    Just (OpenReader _) -> pure (IoFailed "the handle was opened for reading")
    Just (OpenWriter handle) -> guarded (ByteString.hPut handle chunk)

{-| Push what is buffered out to the file. -}
flushHandleAt :: HandleStore -> Int -> IO (IoOutcome ())
flushHandleAt store token = do
  found <- lookupHandle store token
  case found of
    Nothing -> pure closedFailure
    Just (OpenReader _) -> pure (IoDone ())
    Just (OpenWriter handle) -> guarded (hFlush handle)

{-| Close a handle and forget its token.

    Closing one that is already closed is not a failure. A bracket closes on
    every path out of it, and a caller who closed early should not be reported
    against for the bracket doing what it promised. -}
closeHandleAt :: HandleStore -> Int -> IO (IoOutcome ())
closeHandleAt store token = do
  taken <-
    atomicModifyIORef' (handleTable store) $ \table ->
      (IntMap.delete token table, IntMap.lookup token table)
  case taken of
    Nothing -> pure (IoDone ())
    Just entry -> guarded (hClose (handleOf entry))

{-| Close everything this evaluation still has open.

    A program that ended holding a handle has buffered writes that nothing has
    pushed to the file yet, and a process exiting does not push them. This is
    what makes the last bytes a program wrote actually reach the disk. -}
closeHandleStore :: HandleStore -> IO ()
closeHandleStore store = do
  table <-
    atomicModifyIORef' (handleTable store) (\current -> (IntMap.empty, current))
  mapM_ closeQuietly (IntMap.elems table)
 where
  closeQuietly entry = do
    _ <- try (hClose (handleOf entry)) :: IO (Either IOException ())
    pure ()

handleOf :: OpenHandle -> Handle
handleOf entry = case entry of
  OpenReader handle -> handle
  OpenWriter handle -> handle

lookupHandle :: HandleStore -> Int -> IO (Maybe OpenHandle)
lookupHandle store token = IntMap.lookup token <$> readIORef (handleTable store)

closedFailure :: IoOutcome a
closedFailure = IoFailed "the handle is closed"

guarded :: IO () -> IO (IoOutcome ())
guarded action = do
  attempted <- try action :: IO (Either IOException ())
  pure $ case attempted of
    Left problem -> IoFailed (Text.pack (show problem))
    Right () -> IoDone ()
