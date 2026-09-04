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
  , resolveSymbol
  , findSymbol
  , callSymbol
  , CrossedValue (..)
  , ForeignCallFailure (..)
  , kindCode
  ) where

import Control.Concurrent.MVar (MVar, modifyMVar, newMVar)
import qualified Data.ByteString as ByteString
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef)
import Data.Int (Int32, Int64)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Foreign.C.String (CString, peekCString, withCString)
import Foreign.C.Types (CChar (..), CDouble (..), CInt (..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Array (allocaArray, peekArray, withArray)
import Foreign.Marshal.Utils (withMany)
import Foreign.Ptr (Ptr, intPtrToPtr, nullPtr)
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
    -> Ptr Int32
    -> Ptr Int32
    -> Ptr Word8
    -> Ptr Int64
    -> Ptr CDouble
    -> Ptr (Ptr CChar)
    {-| Which arguments the library writes through rather than reads, and where
        what it wrote is read back to. A nought address is a call with no
        output slots, which is every call the language can yet write. -}
    -> Ptr Word8
    -> Ptr Int64
    -> Ptr CDouble
    -> Ptr Int64
    -> Ptr CDouble
    -> Word8
    -> CInt
    -> Ptr Word8
    -> Ptr Int64
    -> Ptr CDouble
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

{-| Every symbol resolved so far, by the library and the name it was found
    under.

    A call used to ask the dynamic linker for its function every time it ran.
    That is a hash lookup through the linker's tables and a fresh
    nought-terminated copy of the name to hand it, paid once per call in a loop
    that may run millions of times — a game's draw call is the ordinary case
    here, not the exotic one.

    An address, once found, does not change for the life of the process. So it
    is remembered, and the read is lock-free: two threads racing to resolve the
    same symbol both call the linker and both write the same address, which
    costs one redundant lookup and no correctness. Taking a lock to prevent that
    would put a lock on the hot path to save work that is already rare. -}
resolvedSymbols :: IORef (Map.Map (Text, Text) (Ptr ()))
resolvedSymbols = unsafePerformIO (newIORef Map.empty)
{-# NOINLINE resolvedSymbols #-}

{-| The address of one function in one library, found once.

    Opening the library is part of what is remembered, so a call that hits does
    not touch the opened-library table either. -}
resolveSymbol :: Text -> Text -> IO (Either Text (Ptr ()))
resolveSymbol library symbol = do
  remembered <- readIORef resolvedSymbols
  case Map.lookup key remembered of
    Just found -> pure (Right found)
    Nothing -> do
      opened <- openLibrary library
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
  key = (library, symbol)

{-| Find one function in an opened library. -}
findSymbol :: ForeignHandle -> Text -> IO (Either Text (Ptr ()))
findSymbol (ForeignHandle handle) name = do
  found <- withCString (Text.unpack name) (c_symbol handle)
  pure
    ( if found == nullPtr
        then Left ("the library exports no " <> name)
        else Right found
    )

{-| A value on its way across, already narrowed to what the declaration said. -}
data CrossedValue
  = CrossedInteger !Int64
  | CrossedDouble !Double
  | CrossedText !Text
  {-| An address the library handed back, under the name its block gave it. -}
  | CrossedHandle !Text !Int64
  {-| A record crossing by value, its fields in the declaration's order. -}
  | CrossedRecord !Text ![(Text, CrossedValue)]
  {-| A nought where text was declared.

      Its own answer rather than an empty string, because those are different
      things: one is a library saying it has none, the other is a library
      saying it has none of it. Reading through the nought is the third
      possibility and is not one. -}
  | CrossedNoText
  deriving stock (Eq, Show)

{-| A native call that could not produce the value its declaration promised.

    Signature assembly remains distinct from text validation so the evaluator
    can tell a missing library contract from bytes that are not a Pudu string. -}
data ForeignCallFailure
  = CallAssemblyFailure !Text
  | InvalidReturnedText
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
  RecordCrossing _ _ -> 14

{-| Make the call.

    Text is copied to a nought-terminated buffer for the duration and freed
    after, which is what "borrowed for the call" means: a library that keeps the
    pointer is a library whose declaration is wrong, and no arrangement here can
    detect that. -}
callSymbol
  :: Ptr ()
  -> [(Crossing, CrossedValue)]
  -> Crossing
  -> IO (Either ForeignCallFailure CrossedValue)
callSymbol symbol arguments result =
  withMany ByteString.useAsCString (map encodedText arguments) $ \strings ->
    withMany ByteString.useAsCString (map encodedText fields) $ \fieldStrings -> do
      let kinds = map (kindCode . fst) arguments
          integers = map integerOf arguments
          doubles = map doubleOf arguments
          {-| Each argument's fields laid end to end, with the slice belonging to
              each recorded beside it. One buffer rather than one per argument,
              because the other side reads a span and the count of it. -}
          starts = scanl (+) 0 (map (fromIntegral . length) flattened) :: [Int32]
          sliceStart = [if null slice then -1 else start | (slice, start) <- zip flattened starts]
          sliceCount = map (fromIntegral . length) flattened :: [Int32]
          fieldKinds = map (kindCode . fst) fields
          fieldIntegers = map integerOf fields
          fieldDoubles = map doubleOf fields
          resultKinds = resultFieldKinds result
          resultCount = length resultKinds
      withArray kinds $ \kindArray ->
        withArray integers $ \integerArray ->
          withArray (map CDouble doubles) $ \doubleArray ->
            withArray strings $ \stringArray ->
              withArray sliceStart $ \startArray ->
                withArray sliceCount $ \countArray ->
                  withArray (orOne 0 fieldKinds) $ \fieldKindArray ->
                    withArray (orOne 0 fieldIntegers) $ \fieldIntegerArray ->
                      withArray (orOne 0 (map CDouble fieldDoubles)) $ \fieldDoubleArray ->
                        withArray (orOne nullPtr fieldStrings) $ \fieldStringArray ->
                          withArray (orOne 0 resultKinds) $ \resultKindArray ->
                            alloca $ \producedInteger ->
                              alloca $ \producedDouble ->
                                allocaArray (max 1 resultCount) $ \producedFieldIntegers ->
                                  allocaArray (max 1 resultCount) $ \producedFieldDoubles -> do
                                    code <-
                                      c_call symbol (fromIntegral (length arguments)) kindArray
                                        integerArray doubleArray stringArray startArray countArray
                                        fieldKindArray fieldIntegerArray fieldDoubleArray fieldStringArray
                                        nullPtr nullPtr nullPtr nullPtr nullPtr
                                        (kindCode result) (fromIntegral resultCount) resultKindArray
                                        producedInteger producedDouble producedFieldIntegers
                                        producedFieldDoubles
                                    if code /= 0
                                      then pure (Left (refusal code))
                                      else case result of
                                        RecordCrossing _ _ -> do
                                          producedIntegers <- peekArray resultCount producedFieldIntegers
                                          producedDoubles <- peekArray resultCount producedFieldDoubles
                                          rebuilt <- rebuildRecord result
                                            (zip producedIntegers (map unwrapDouble producedDoubles))
                                          pure (fmap fst rebuilt)
                                        _ -> do
                                          asInteger <- peek producedInteger
                                          CDouble asDouble <- peek producedDouble
                                          received result asInteger asDouble
 where
  {-| An empty array still needs an address to pass, so an unused one carries a
      single filler the other side never reads: every count that would reach it
      is zero. The filler is a real value rather than an undefined one, because
      `withArray` writes what it is given. -}
  orOne filler values = if null values then [filler] else values

  unwrapDouble (CDouble held) = held

  flattened = map (uncurry recordFields) arguments
  fields = concat flattened
  encodedText (_, value) = case value of
    CrossedText written -> TextEncoding.encodeUtf8 written
    _ -> ByteString.empty
  integerOf (_, value) = case value of
    CrossedInteger held -> held
    CrossedHandle _ held -> held
    _ -> 0
  doubleOf (_, value) = case value of
    CrossedDouble held -> held
    _ -> 0

received :: Crossing -> Int64 -> Double -> IO (Either ForeignCallFailure CrossedValue)
received crossing asInteger asDouble = case crossing of
  FloatingCrossing _ -> pure (Right (CrossedDouble asDouble))
  HandleCrossing name -> pure (Right (CrossedHandle name asInteger))
  TextCrossing -> receivedText asInteger
  _ -> pure (Right (CrossedInteger asInteger))

{-| Text a library handed back, copied out of its own storage.

    What crosses is an address, and the bytes behind it belong to whoever
    returned them: a static table, a buffer reused on the next call, or
    something the caller was meant to free. Copying at the boundary ends every
    one of those questions here — the text a program holds is its own from the
    moment it arrives, and nothing it does later depends on what the library
    meant to happen to the original.

    A nought address is not text. It is refused rather than read through, and
    rather than quietly becoming the empty string, which is a different answer
    from "there was none". -}
receivedText :: Int64 -> IO (Either ForeignCallFailure CrossedValue)
receivedText address
  | address == 0 = pure (Right CrossedNoText)
  | otherwise = do
      copied <- ByteString.packCString (intPtrToPtr (fromIntegral address))
      pure $ case TextEncoding.decodeUtf8' copied of
        Left _ -> Left InvalidReturnedText
        Right decoded -> Right (CrossedText decoded)

{-| A record's leaves, in the order the declarations wrote them.

    Only the widths and the values travel. Where each one sits inside the record
    is asked of the platform on the other side, because that is the platform's
    answer and a caller repeating the calculation is a caller writing into the
    wrong offsets on the machine whose rule it guessed wrong.

    A record inside a record contributes its own leaves in place of itself, so
    what travels is always scalars. That is the same description the platform
    derives for the nesting, so it lays the bytes out where the nesting would
    have put them without being told the shape. -}
recordFields :: Crossing -> CrossedValue -> [(Crossing, CrossedValue)]
recordFields crossing value = case (crossing, value) of
  (RecordCrossing _ declared, CrossedRecord _ held) ->
    concat
      [ case (fieldCrossing, fieldValue) of
          (RecordCrossing _ _, CrossedRecord _ _) -> recordFields fieldCrossing fieldValue
          _ -> [(fieldCrossing, fieldValue)]
      | ((_, fieldCrossing), (_, fieldValue)) <- zip declared held
      ]
  _ -> []

{-| The leaves a result is read back as, in the same order. -}
resultFieldKinds :: Crossing -> [Word8]
resultFieldKinds crossing = case crossing of
  RecordCrossing _ declared -> concatMap (leafKinds . snd) declared
  _ -> []

leafKinds :: Crossing -> [Word8]
leafKinds crossing = case crossing of
  RecordCrossing _ declared -> concatMap (leafKinds . snd) declared
  _ -> [kindCode crossing]

{-| Rebuild a record from the leaves the platform handed back.

    The leaves arrive flat and in order, so the declaration is what says where
    each nesting begins and ends; this walks the two together and answers with
    whatever is left over, which is empty when the shape and the leaves agree. -}
rebuildRecord
  :: Crossing
  -> [(Int64, Double)]
  -> IO (Either ForeignCallFailure (CrossedValue, [(Int64, Double)]))
rebuildRecord crossing leaves = case crossing of
  RecordCrossing name declared -> do
    folded <- foldFields declared leaves
    pure (fmap (\(fields, rest) -> (CrossedRecord name fields, rest)) folded)
  _ -> case leaves of
    (asInteger, asDouble) : rest -> do
      value <- received crossing asInteger asDouble
      pure (fmap (\one -> (one, rest)) value)
    [] -> pure (Left (CallAssemblyFailure "the result had fewer fields than its declaration"))
 where
  foldFields [] rest = pure (Right ([], rest))
  foldFields ((label, fieldCrossing) : more) rest = do
    first <- rebuildRecord fieldCrossing rest
    case first of
      Left problem -> pure (Left problem)
      Right (value, afterField) -> do
        others <- foldFields more afterField
        pure (fmap (\(rest', after) -> ((label, value) : rest', after)) others)

refusal :: CInt -> ForeignCallFailure
refusal code = CallAssemblyFailure $ case code of
  1 -> "the function was not found in the library"
  2 -> "too many arguments for a foreign call"
  3 -> "an argument's type cannot cross"
  4 -> "the result's type cannot cross"
  _ -> "the call's signature could not be assembled"
