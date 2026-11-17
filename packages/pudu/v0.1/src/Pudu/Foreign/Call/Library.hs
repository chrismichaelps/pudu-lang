{-| @Program.Foreign.Call.Library — owns dynamic library references and resolves symbols. -}
module Pudu.Foreign.Call.Library
  ( ForeignHandle
  , ForeignCallee (..)
  , resolveObjectiveC
  , candidates
  , closeLibrary
  , findSymbol
  , openLibrary
  , openProcess
  , resolveSymbol
  , tryCandidates
  , withSymbol
  ) where

import Control.Concurrent.MVar (MVar, modifyMVarMasked, newMVar, withMVar)
import Control.Concurrent.STM
  ( TVar, atomically, check, modifyTVar', newTVarIO, readTVar, writeTVar )
import Control.Exception (finally, mask, mask_, onException)
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Data.Text.Encoding.Error (lenientDecode)
import Foreign.C.String (CString)
import Foreign.C.Types (CInt (..), CSize (..))
import Foreign.Marshal.Alloc (allocaBytes)
import Foreign.Ptr (FunPtr, Ptr, castPtrToFunPtr, nullPtr)
import Pudu.Foreign.Crossing (ObjectiveCMethod (..))
import System.Info (arch, os)
import System.IO.Unsafe (unsafePerformIO)

foreign import ccall safe "pudu_ffi_open"
  c_open :: CString -> CString -> CSize -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_symbol"
  c_symbol :: Ptr () -> CString -> IO (Ptr ())
foreign import ccall safe "pudu_ffi_close"
  c_close :: Ptr () -> CString -> CSize -> IO CInt

foreign import ccall safe "dynamic"
  callObjCLookup :: FunPtr (CString -> IO (Ptr ())) -> CString -> IO (Ptr ())

data ForeignCallee
  = ForeignSymbol !(Ptr ())
  | ObjectiveCSend !(Ptr ()) !(Ptr ()) !(Ptr ()) !(Ptr ())

data LibraryAdmission = Open !Int | Closing !Int | Closed

data ForeignHandle = ForeignHandle !(Ptr ()) !(TVar LibraryAdmission) !(MVar ())

errorCapacity :: Int
errorCapacity = 4096

loaderError :: CString -> IO Text
loaderError = fmap (Encoding.decodeUtf8With lenientDecode) . ByteString.packCString

withUtf8 :: Text -> (CString -> IO a) -> IO a
withUtf8 value = ByteString.useAsCString (Encoding.encodeUtf8 value)

openHandle :: CString -> IO (Either Text ForeignHandle)
openHandle path = mask_ $ allocaBytes errorCapacity $ \buffer -> do
  pointer <- c_open path buffer (fromIntegral errorCapacity)
  if pointer == nullPtr
    then Left <$> loaderError buffer
    else Right <$> (ForeignHandle pointer <$> newTVarIO (Open 0) <*> newMVar ())

{-| Each explicitly opened handle owns one loader reference. -}
openLibrary :: Text -> Maybe Text -> IO (Either Text ForeignHandle)
openLibrary name version
  | Text.any (== '\0') name || maybe False (Text.any (== '\0')) version =
      pure (Left "a foreign library name or version carries a nought")
  | name == "c" = openProcess
  | otherwise = tryCandidates (candidates name version)

openProcess :: IO (Either Text ForeignHandle)
openProcess = do
  opened <- openHandle nullPtr
  pure $ case opened of
    Left _ -> Left "the program cannot see its own symbols"
    Right handle -> Right handle

{-| Close admission before waiting for active users. A cancelled wait returns
    the handle to Open so another close can drain it. -}
closeLibrary :: ForeignHandle -> IO (Either Text ())
closeLibrary (ForeignHandle pointer admission closure) = withMVar closure $ \_ -> mask_ $ do
  opened <- atomically $ do
    state <- readTVar admission
    case state of
      Open count -> writeTVar admission (Closing count) >> pure True
      _ -> pure False
  if opened then drain else pure (Right ())
 where
  drain = do
    atomically awaitDrained `onException` atomically (modifyTVar' admission reopen)
    result <- allocaBytes errorCapacity $ \buffer -> do
      closed <- c_close pointer buffer (fromIntegral errorCapacity)
      if closed == 0 then Left <$> loaderError buffer else pure (Right ())
    atomically (writeTVar admission Closed)
    pure result
  awaitDrained = do
    state <- readTVar admission
    check (case state of Closing 0 -> True; _ -> False)
  reopen (Closing count) = Open count
  reopen state = state

{-| Run one scoped use of a symbol. The address is valid through the action.
    The action may perform nested symbol uses and must let its lease end
    before closing the same handle. -}
withSymbol :: ForeignHandle -> Text -> (Ptr () -> IO a) -> IO (Either Text a)
withSymbol (ForeignHandle pointer admission _) name action = mask $ \restore -> do
  entered <- atomically $ do
    state <- readTVar admission
    case state of
      Open count -> writeTVar admission (Open (count + 1)) >> pure True
      _ -> pure False
  if entered
    then restore use `finally` atomically (modifyTVar' admission release)
    else pure (Left "the foreign library is closed")
 where
  use
    | Text.any (== '\0') name = pure (Left "a foreign symbol name carries a nought")
    | otherwise = do
        found <- withUtf8 name (c_symbol pointer)
        if found == nullPtr
          then pure (Left ("the library exports no " <> name))
          else Right <$> action found
  release (Open count) = Open (count - 1)
  release (Closing count) = Closing (count - 1)
  release Closed = Closed

{-| Borrow an address when the caller controls the handle's open lifetime.
    Use withSymbol when another caller can close the handle. -}
findSymbol :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
findSymbol handle name = withSymbol handle name pure

{-| Try the written name first so explicit paths retain their meaning. -}
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
    ] <> ["lib" <> name <> ".dll" | os == "mingw32"]

tryCandidates :: [Text] -> IO (Either Text ForeignHandle)
tryCandidates [] = pure (Left "no candidate name opened")
tryCandidates names = go "" names
 where
  go detail [] = pure (Left ("could not open the library; tried " <> Text.intercalate ", " names
    <> if Text.null detail then "" else " (" <> detail <> ")"))
  go previous (name : rest)
    | Text.any (== '\0') name = go previous rest
    | otherwise = do
        attempted <- withUtf8 name openHandle
        case attempted of
          Right handle -> pure (Right handle)
          Left detail -> go (if Text.null previous then detail else previous) rest

{-| Declaration calls and their destructors may retain addresses outside
    this function, so the cache owns a separate, process-long reference. -}
openedLibraries :: MVar (Map.Map (Text, Maybe Text) ForeignHandle)
openedLibraries = unsafePerformIO (newMVar Map.empty)
{-# NOINLINE openedLibraries #-}

cachedLibrary :: Text -> Maybe Text -> IO (Either Text ForeignHandle)
cachedLibrary name version = modifyMVarMasked openedLibraries $ \opened ->
  case Map.lookup key opened of
    Just found -> pure (opened, Right found)
    Nothing -> do
      attempted <- openLibrary name version
      case attempted of
        Right handle -> pure (Map.insert key handle opened, Right handle)
        Left problem -> pure (opened, Left problem)
 where
  key = (name, version)

resolvedSymbols :: IORef (Map.Map (Text, Maybe Text, Text) (Ptr ()))
resolvedSymbols = unsafePerformIO (newIORef Map.empty)
{-# NOINLINE resolvedSymbols #-}

resolveSymbol :: Text -> Maybe Text -> Text -> IO (Either Text (Ptr ()))
resolveSymbol library version symbol = do
  remembered <- readIORef resolvedSymbols
  case Map.lookup key remembered of
    Just found -> pure (Right found)
    Nothing -> do
      opened <- cachedLibrary library version
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

objectiveCTargets :: MVar (Map.Map (Text, Maybe Text, ObjectiveCMethod) ForeignCallee)
objectiveCTargets = unsafePerformIO (newMVar Map.empty)
{-# NOINLINE objectiveCTargets #-}

resolveObjectiveC :: Text -> Maybe Text -> ObjectiveCMethod -> IO (Either Text ForeignCallee)
resolveObjectiveC library version method
  | os /= "darwin" = pure (Left "Objective-C dispatch requires an Apple target")
  | otherwise = modifyMVarMasked objectiveCTargets $ \cache ->
      case Map.lookup key cache of
        Just target -> pure (cache, Right target)
        Nothing -> do
          found <- load
          pure (either (const cache) (\target -> Map.insert key target cache) found, found)
 where
  key = (library, version, method)
  runtime = "/usr/lib/libobjc.A.dylib"
  resolve name = resolveSymbol runtime Nothing name
  lookupObject function name missing = do
    found <- resolve function
    case found of
      Left problem -> pure (Left problem)
      Right implementation -> do
        pointer <- withUtf8 name (callObjCLookup (castPtrToFunPtr implementation))
        pure (if pointer == nullPtr then Left missing else Right pointer)
  load = do
    framework <- cachedLibrary library version
    case framework of
      Left problem -> pure (Left problem)
      Right _ -> do
        implementation <- resolve "objc_msgSend"
        stret <- if arch == "x86_64" then resolve "objc_msgSend_stret" else pure (Right nullPtr)
        receiver <- case objectiveCClass method of
          Nothing -> pure (Right nullPtr)
          Just name -> lookupObject "objc_getClass" name ("the Objective-C runtime has no class " <> name)
        selector <- lookupObject "sel_registerName" (objectiveCSelector method) "the Objective-C selector is unavailable"
        pure (ObjectiveCSend <$> implementation <*> stret <*> receiver <*> selector)
