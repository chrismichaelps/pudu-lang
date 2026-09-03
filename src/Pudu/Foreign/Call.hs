{-| @Program.Foreign.Call — opens a library and calls into it

    The library is named rather than pathed, and this is where the name becomes
    a file: a path in source is a claim about somebody else's machine, which
    every other part of this language refuses to let a program make. What it
    tries is the naming convention of the platform it is running on.

    An opened library is kept, because opening one twice and holding two handles
    to the same code is how a library with internal state acquires two of it. -}
module Pudu.Foreign.Call
  ( ForeignHandle
  , openLibrary
  , findSymbol
  , callSymbol
  , CrossedValue (..)
  , kindCode
  , claimOwned
  , ownsAddress
  , releaseOwned
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar, readMVar)
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Foreign.C.String (CString, newCString, peekCString, withCString)
import Foreign.C.Types (CChar (..), CDouble (..), CInt (..))
import Foreign.Marshal.Alloc (alloca, free)
import Foreign.Marshal.Array (withArray)
import Foreign.Ptr (Ptr, nullPtr)
import Foreign.Storable (peek)
import Data.Word (Word8)
import Pudu.Foreign.Crossing (Crossing (..))
import System.IO.Unsafe (unsafePerformIO)

foreign import ccall unsafe "pudu_ffi_open" c_open :: CString -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_symbol" c_symbol :: Ptr () -> CString -> IO (Ptr ())
foreign import ccall unsafe "pudu_ffi_error" c_error :: IO CString
foreign import ccall safe "pudu_ffi_call"
  c_call
    :: Ptr ()
    -> CInt
    -> Ptr Word8
    -> Ptr Int64
    -> Ptr CDouble
    -> Ptr (Ptr CChar)
    -> Word8
    -> Ptr Int64
    -> Ptr CDouble
    -> IO CInt

{-| An opened library. -}
newtype ForeignHandle = ForeignHandle (Ptr ())

{-| Libraries opened so far, by the name the declaration wrote.

    One handle per name for the lifetime of the program: a library with
    internal state — and a graphics library is nothing but internal state —
    must not be opened twice into two of it. -}
openedLibraries :: MVar (Map.Map Text ForeignHandle)
openedLibraries = unsafePerformIO (newMVar Map.empty)
{-# NOINLINE openedLibraries #-}

{-| Open a library by the name a declaration gave.

    The candidates are the platform's own conventions, tried in the order a
    person would: what they wrote, then what the platform would have called it.
    Reporting which candidates were tried matters more here than elsewhere,
    because the usual cause is that the library is not installed and the usual
    remedy is to install it. -}
openLibrary :: Text -> IO (Either Text ForeignHandle)
openLibrary name = modifyMVar openedLibraries $ \opened ->
  case Map.lookup name opened of
    Just found -> pure (opened, Right found)
    Nothing -> do
      attempted <- if name == "c" then openProcess else tryCandidates (candidates name)
      case attempted of
        Right handle -> pure (Map.insert name handle opened, Right handle)
        Left problem -> pure (opened, Left problem)

{-| The C library is the one library every program already has, and every
    platform files under a different name — libc.so.6 here, libSystem.B.dylib
    there, and a linker script rather than a library in the place a person would
    look. A binding that hardcodes one of those names is a binding that works on
    one machine, which is why nearly every language's C bindings carry a table
    of them.

    So `foreign "c"` asks the running program for its own symbols instead. The C
    library is linked into it already, and asking the program is both correct
    everywhere and free. -}
openProcess :: IO (Either Text ForeignHandle)
openProcess = do
  handle <- c_open nullPtr
  pure
    ( if handle == nullPtr
        then Left "the program cannot see its own symbols"
        else Right (ForeignHandle handle)
    )

candidates :: Text -> [Text]
candidates name =
  [ name
  , "lib" <> name <> ".dylib"
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

{-| Find one function in an opened library. -}
findSymbol :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
findSymbol (ForeignHandle handle) name = do
  found <- withCString (Text.unpack name) (c_symbol handle)
  pure
    ( if found == nullPtr
        then Left ("the library exports no " <> name)
        else Right found
    )

{-| The owned addresses a program is currently holding.

    Kept because the declaration says what frees each one, which makes two
    things checkable that are otherwise found by a crash much later: releasing
    the same address twice, and releasing something this program never owned.
    Nothing else in a foreign boundary knows enough to check either. -}
ownedAddresses :: MVar (Set Int64)
ownedAddresses = unsafePerformIO (newMVar Set.empty)
{-# NOINLINE ownedAddresses #-}

{-| Record that the program now owns an address and must release it. -}
claimOwned :: Int64 -> IO Bool
claimOwned address =
  modifyMVar ownedAddresses $ \held ->
    pure (Set.insert address held, not (Set.member address held))

{-| Whether the program still owns an address.

    A handle value may outlive the ownership it represents because values are
    immutable and can be aliased. Checking at every call turns that alias into
    a deterministic refusal after release rather than a pointer handed back to
    code that is free to dereference it. -}
ownsAddress :: Int64 -> IO Bool
ownsAddress address = Set.member address <$> readMVar ownedAddresses

{-| Give up an owned address, answering whether the program held it.

    A false answer is a release of something already released or never owned,
    and the call is not made. Making it is undefined behaviour in the library —
    typically a crash somewhere else, later, in code that did nothing wrong. -}
releaseOwned :: Int64 -> IO Bool
releaseOwned address =
  modifyMVar ownedAddresses $ \held ->
    pure (Set.delete address held, Set.member address held)

{-| A value on its way across, already narrowed to what the declaration said. -}
data CrossedValue
  = CrossedInteger !Int64
  | CrossedDouble !Double
  | CrossedText !Text
  {-| An address the library handed back, under the name its block gave it. -}
  | CrossedHandle !Text !Int64
  deriving stock (Eq, Show)

{-| The code the other side reads for a kind.

    Shared with the C file and not to be reordered: one side knows the
    declaration and the other knows the machine, and this is the only thing
    they agree on. -}
kindCode :: Crossing -> Word8
kindCode crossing = case crossing of
  SignedCrossing 8 -> 0
  SignedCrossing 16 -> 1
  SignedCrossing 32 -> 2
  SignedCrossing _ -> 3
  UnsignedCrossing 8 -> 4
  UnsignedCrossing 16 -> 5
  UnsignedCrossing 32 -> 6
  UnsignedCrossing _ -> 7
  FloatingCrossing 32 -> 8
  FloatingCrossing _ -> 9
  BooleanCrossing -> 10
  TextCrossing -> 11
  NothingCrossing -> 12
  HandleCrossing _ -> 13

{-| Make the call.

    Text is copied to a nought-terminated buffer for the duration and freed
    after, which is what "borrowed for the call" means: a library that keeps the
    pointer is a library whose declaration is wrong, and no arrangement here can
    detect that. -}
callSymbol :: Ptr () -> [(Crossing, CrossedValue)] -> Crossing -> IO (Either Text CrossedValue)
callSymbol symbol arguments result = do
  strings <- mapM allocate arguments
  let kinds = map (kindCode . fst) arguments
      integers = map integerOf arguments
      doubles = map doubleOf arguments
  outcome <-
    withArray kinds $ \kindArray ->
      withArray integers $ \integerArray ->
        withArray (map CDouble doubles) $ \doubleArray ->
          withArray strings $ \stringArray ->
            alloca $ \producedInteger ->
              alloca $ \producedDouble -> do
                code <-
                  c_call symbol (fromIntegral (length arguments)) kindArray integerArray
                    doubleArray stringArray (kindCode result) producedInteger producedDouble
                if code /= 0
                  then pure (Left (refusal code))
                  else do
                    asInteger <- peek producedInteger
                    CDouble asDouble <- peek producedDouble
                    pure (Right (received result asInteger asDouble))
  mapM_ freeString strings
  pure outcome
 where
  allocate (crossing, value) = case (crossing, value) of
    (TextCrossing, CrossedText written) -> newCString (Text.unpack written)
    _ -> pure nullPtr
  freeString pointer = if pointer == nullPtr then pure () else free pointer
  integerOf (_, value) = case value of
    CrossedInteger held -> held
    CrossedHandle _ held -> held
    _ -> 0
  doubleOf (_, value) = case value of
    CrossedDouble held -> held
    _ -> 0

received :: Crossing -> Int64 -> Double -> CrossedValue
received crossing asInteger asDouble = case crossing of
  FloatingCrossing _ -> CrossedDouble asDouble
  HandleCrossing name -> CrossedHandle name asInteger
  _ -> CrossedInteger asInteger

refusal :: CInt -> Text
refusal code = case code of
  1 -> "the function was not found in the library"
  2 -> "too many arguments for a foreign call"
  3 -> "an argument's type cannot cross"
  4 -> "the result's type cannot cross"
  _ -> "the call's signature could not be assembled"
