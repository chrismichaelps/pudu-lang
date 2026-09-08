{-| @Program.Foreign.Call.Library — opens a library and resolves symbols. -}
module Pudu.Foreign.Call.Library
  ( ForeignHandle (..)
  , candidates
  , findSymbol
  , openLibrary
  , openProcess
  , resolveSymbol
  , tryCandidates
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar)
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Foreign.C.String (CString, peekCString, withCString)
import Foreign.Ptr (Ptr, nullPtr)
import System.IO.Unsafe (unsafePerformIO)

foreign import ccall unsafe "pudu_ffi_open" c_open :: CString -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_symbol" c_symbol :: Ptr () -> CString -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_error" c_error :: IO CString

{-| An opened library. -}
newtype ForeignHandle = ForeignHandle (Ptr ())

{-| Libraries opened so far, by the name the declaration wrote.

    One handle per name for the lifetime of the program: a library with
    internal state — and a graphics library is nothing but internal state —
    must not be opened twice into two of it. -}
openedLibraries :: MVar (Map.Map (Text, Maybe Text) ForeignHandle)
openedLibraries = unsafePerformIO (newMVar Map.empty)
{-# NOINLINE openedLibraries #-}

{-| Open a library by the name a declaration gave.

    The candidates are the platform's own conventions, tried in the order a
    person would: what they wrote, then what the platform would have called it. -}
openLibrary :: Text -> Maybe Text -> IO (Either Text ForeignHandle)
openLibrary name version = modifyMVar openedLibraries $ \opened ->
  case Map.lookup key opened of
    Just found -> pure (opened, Right found)
    Nothing -> do
      attempted <-
        if name == "c" then openProcess else tryCandidates (candidates name version)
      case attempted of
        Right handle -> pure (Map.insert key handle opened, Right handle)
        Left problem -> pure (opened, Left problem)
 where
  key = (name, version)

{-| Ask the running program for its own symbols. -}
openProcess :: IO (Either Text ForeignHandle)
openProcess = do
  handle <- c_open nullPtr
  pure
    ( if handle == nullPtr
        then Left "the program cannot see its own symbols"
        else Right (ForeignHandle handle)
    )

{-| What to ask the loader for, in the order a person would.

    What the declaration wrote comes first, so a full path or an exact file name
    is honoured as written. Then the platform's own spellings. -}
candidates :: Text -> Maybe Text -> [Text]
candidates name version = name : versioned <> plain
 where
  versioned = case version of
    Nothing -> []
    Just number ->
      [ "lib" <> name <> ".so." <> number
      , "lib" <> name <> "." <> number <> ".dylib"
      , "lib" <> name <> "-" <> number <> ".dll"
      , name <> ".so." <> number
      , name <> "." <> number <> ".dylib"
      , name <> "-" <> number <> ".dll"
      ]
  plain =
    [ "lib" <> name <> ".dylib"
    , "lib" <> name <> ".so"
    , name <> ".dylib"
    , name <> ".so"
    , name <> ".dll"
    ]

tryCandidates :: [Text] -> IO (Either Text ForeignHandle)
tryCandidates [] = pure (Left "no candidate name opened")
tryCandidates (candidate : rest) = do
  handle <- withCString (Text.unpack candidate) c_open
  if handle == nullPtr
    then do
      remaining <- tryCandidates rest
      case remaining of
        Right found -> pure (Right found)
        Left _ -> do
          reported <- c_error
          detail <-
            if reported == nullPtr then pure "" else Text.pack <$> peekCString reported
          pure
            ( Left
                ( "could not open the library; tried "
                    <> Text.intercalate ", " (candidate : rest)
                    <> (if Text.null detail then "" else " (" <> detail <> ")")
                )
            )
    else pure (Right (ForeignHandle handle))

{-| Every symbol resolved so far, by the library and the name it was found
    under. An address, once found, does not change for the life of the process. -}
resolvedSymbols :: IORef (Map.Map (Text, Maybe Text, Text) (Ptr ()))
resolvedSymbols = unsafePerformIO (newIORef Map.empty)
{-# NOINLINE resolvedSymbols #-}

{-| The address of one function in one library, found once. -}
resolveSymbol :: Text -> Maybe Text -> Text -> IO (Either Text (Ptr ()))
resolveSymbol library version symbol = do
  remembered <- readIORef resolvedSymbols
  case Map.lookup key remembered of
    Just found -> pure (Right found)
    Nothing -> do
      opened <- openLibrary library version
      case opened of
        Left problem -> pure (Left problem)
        Right handle -> do
          found <- findSymbol handle symbol
          case found of
            Left problem -> pure (Left problem)
            Right address -> do
              atomicModifyIORef' resolvedSymbols
                (\table -> (Map.insert key address table, ()))
              pure (Right address)
 where
  key = (library, version, symbol)

{-| Find one function in an opened library. -}
findSymbol :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
findSymbol (ForeignHandle handle) name = do
  found <- withCString (Text.unpack name) (c_symbol handle)
  pure
    ( if found == nullPtr
        then Left ("the library exports no " <> name)
        else Right found
    )
