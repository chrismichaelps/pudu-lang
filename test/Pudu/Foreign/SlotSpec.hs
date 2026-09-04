{-| What the bridge does with an argument the library writes through.

    These reach `pudu_ffi_call` directly rather than through a Pudu program,
    because the language cannot yet write an output slot and the bridge that
    carries one has to be proven before anything is built on it. The symbols are
    the C++ conformance fixture linked into this binary. -}
module Pudu.Foreign.SlotSpec (slotProperties) where

import Data.Int (Int32, Int64)
import Data.Word (Word8)
import Foreign.C.String (peekCAString)
import Foreign.C.Types (CChar (..), CDouble (..), CInt (..))
import Foreign.Marshal.Array (allocaArray, peekArray, withArray)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (FunPtr, Ptr, castFunPtrToPtr, intPtrToPtr, nullPtr)
import Foreign.Storable (peek)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

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

foreign import ccall unsafe "&pudu_ffi_cpp_open_box" openBox :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_i32" writeI32 :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_zero" writeZero :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_f64" writeF64 :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_text" writeText :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_nothing" writeNothing :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_mixed" writeMixed :: FunPtr ()
foreign import ccall unsafe "&pudu_ffi_cpp_write_sum" writeSum :: FunPtr ()
foreign import ccall unsafe "pudu_ffi_cpp_box_delete" boxDelete :: Ptr () -> IO ()

{-| The codes the declaration side writes and the machine side reads. Shared
    with the bridge, and wrong the moment either list is reordered. -}
kindI32, kindF64, kindText, kindVoid, kindHandle, kindStruct :: Word8
kindI32 = 2
kindF64 = 9
kindText = 11
kindVoid = 12
kindHandle = 13
kindStruct = 14

kindU8, kindF32 :: Word8
kindU8 = 4
kindF32 = 8

{-| One argument as the bridge is told about it: what the caller sends, what the
    library writes back, and the value when it is sent rather than written. -}
data Argument = Argument
  { argumentKind :: !Word8
  , argumentSlot :: !Word8
  , argumentInteger :: !Int64
  , argumentFields :: ![Word8]
  }

sends :: Word8 -> Int64 -> Argument
sends kind value = Argument kind kindVoid value []

writesBack :: Word8 -> Argument
writesBack kind = Argument kindVoid kind 0 []

writesRecord :: [Word8] -> Argument
writesRecord leaves = Argument kindVoid kindStruct 0 leaves

{-| What one call answered with: the bridge's own code, the native result, and
    every slot. -}
data Answer = Answer
  { answerCode :: !Int
  , answerInteger :: !Int64
  , answerSlotIntegers :: ![Int64]
  , answerSlotDoubles :: ![Double]
  , answerSlotFields :: ![(Int64, Double)]
  }

{-| Make one call. `readback` says whether the slot arrays are supplied, which
    is the one thing a caller can get wrong that the bridge refuses rather than
    carries. -}
callWith :: FunPtr () -> [Argument] -> Word8 -> Bool -> IO Answer
callWith symbol arguments resultKind readback =
  withArray (map argumentKind arguments) $ \kinds ->
    withArray (map argumentInteger arguments) $ \integers ->
      withArray (map (const (CDouble 0)) arguments) $ \doubles ->
        withArray (map (const nullPtr) arguments) $ \pointers ->
          withArray starts $ \startArray ->
            withArray counts $ \countArray ->
              withArray (orOne 0 leaves) $ \fieldKinds ->
                withArray (orOne 0 (map (const 0) leaves)) $ \fieldIntegers ->
                  withArray (orOne (CDouble 0) (map (const (CDouble 0)) leaves)) $ \fieldDoubles ->
                    withArray (orOne nullPtr (map (const nullPtr) leaves)) $ \fieldPointers ->
                      withArray (map argumentSlot arguments) $ \slotKinds ->
                        allocaArray count $ \slotIntegers ->
                          allocaArray count $ \slotDoubles ->
                            allocaArray leafCount $ \slotFieldIntegers ->
                              allocaArray leafCount $ \slotFieldDoubles ->
                                alloca $ \resultInteger ->
                                  alloca $ \resultDouble ->
                                    allocaArray 1 $ \resultFieldIntegers ->
                                      allocaArray 1 $ \resultFieldDoubles -> do
                                        code <-
                                          c_call (castFunPtrToPtr symbol) (fromIntegral count)
                                            kinds integers doubles pointers
                                            startArray countArray fieldKinds fieldIntegers
                                            fieldDoubles fieldPointers
                                            slotKinds
                                            (if readback then slotIntegers else nullPtr)
                                            (if readback then slotDoubles else nullPtr)
                                            slotFieldIntegers slotFieldDoubles
                                            resultKind 0 nullPtr
                                            resultInteger resultDouble
                                            resultFieldIntegers resultFieldDoubles
                                        if code /= 0
                                          then pure (Answer (fromIntegral code) 0 [] [] [])
                                          else do
                                            produced <- peek resultInteger
                                            integersBack <- peekArray count slotIntegers
                                            doublesBack <- peekArray count slotDoubles
                                            fieldIntegersBack <-
                                              peekArray leafCount slotFieldIntegers
                                            fieldDoublesBack <-
                                              peekArray leafCount slotFieldDoubles
                                            pure
                                              Answer
                                                { answerCode = 0
                                                , answerInteger = produced
                                                , answerSlotIntegers = integersBack
                                                , answerSlotDoubles =
                                                    map unwrap doublesBack
                                                , answerSlotFields =
                                                    zip fieldIntegersBack
                                                      (map unwrap fieldDoublesBack)
                                                }
 where
  count = length arguments
  leaves = concatMap argumentFields arguments
  leafCount = max 1 (length leaves)
  starts = starting 0 arguments
  counts = map (fromIntegral . length . argumentFields) arguments
  starting _ [] = []
  starting at (argument : rest) =
    fromIntegral at : starting (at + length (argumentFields argument)) rest
  unwrap (CDouble held) = held
  {-| An empty array still needs an address to pass, and the filler is a real
      value because every count that would reach it is zero. -}
  orOne filler values = if null values then [filler] else values

slotProperties :: [(String, IO Property)]
slotProperties =
  [ ("a library writes its resource through a slot", testResourceSlot)
  , ("a failing status still yields the resource it made", testFailureWithResource)
  , ("a slot the library did not write reads back as nothing", testUnwrittenSlot)
  , ("a scalar slot crosses back, including a written zero", testScalarSlot)
  , ("a floating slot crosses back", testFloatingSlot)
  , ("a text slot carries text the library owns", testTextSlot)
  , ("a record slot is read at the platform's own offsets", testRecordSlot)
  , ("ordinary arguments and slots travel in one call", testMixedArguments)
  , ("a slot with nowhere to answer is refused before the call", testMissingReadback)
  ]

testResourceSlot :: IO Property
testResourceSlot = do
  answer <- callWith openBox [sends kindI32 0, writesBack kindHandle] kindI32 True
  released <- release (answerSlotIntegers answer)
  pure
    ( counterexample ("bridge code " <> show (answerCode answer))
        ( conjoin
            [ property (answerCode answer == 0)
            , answerInteger answer === 0
            , counterexample "the slot carried no address" (property released)
            ]
        )
    )

testFailureWithResource :: IO Property
testFailureWithResource = do
  answer <- callWith openBox [sends kindI32 1, writesBack kindHandle] kindI32 True
  released <- release (answerSlotIntegers answer)
  pure
    ( counterexample "a failure that still made a resource must hand it over"
        ( conjoin
            [ property (answerCode answer == 0)
            , answerInteger answer === 5
            , property released
            ]
        )
    )

testUnwrittenSlot :: IO Property
testUnwrittenSlot = do
  handle <- callWith openBox [sends kindI32 9, writesBack kindHandle] kindI32 True
  text <- callWith writeNothing [writesBack kindText] kindVoid True
  pure
    ( conjoin
        [ property (answerCode handle == 0)
        , answerInteger handle === 9
        , counterexample "an unwritten handle slot must be nothing"
            (drop 1 (answerSlotIntegers handle) === [0])
        , counterexample "an unwritten text slot must be nothing"
            (answerSlotIntegers text === [0])
        ]
    )

testScalarSlot :: IO Property
testScalarSlot = do
  written <- callWith writeI32 [writesBack kindI32] kindVoid True
  zero <- callWith writeZero [writesBack kindI32] kindVoid True
  pure
    ( conjoin
        [ answerSlotIntegers written === [42]
        , counterexample "a written zero is a value, not an absence"
            (answerSlotIntegers zero === [0])
        ]
    )

testFloatingSlot :: IO Property
testFloatingSlot = do
  answer <- callWith writeF64 [writesBack kindF64] kindVoid True
  pure (answerSlotDoubles answer === [2.5])

testTextSlot :: IO Property
testTextSlot = do
  answer <- callWith writeText [writesBack kindText] kindVoid True
  case answerSlotIntegers answer of
    [address] | address /= 0 -> do
      written <- peekCAString (intPtrToPtr (fromIntegral address))
      pure (property (written === "h\195\169ll\195\184 \240\159\144\167"))
    other -> pure (counterexample ("no address in " <> show other) (property False))

testRecordSlot :: IO Property
testRecordSlot = do
  answer <- callWith writeMixed [writesRecord [kindU8, kindF32, kindF32, kindF64]] kindVoid True
  let fields = answerSlotFields answer
  pure
    ( counterexample (show fields)
        ( conjoin
            [ map fst fields === [7, 0, 0, 0]
            , map snd fields === [0, 1.5, -2.25, 0.125]
            ]
        )
    )

testMixedArguments :: IO Property
testMixedArguments = do
  answer <-
    callWith writeSum [sends kindI32 10, sends kindI32 4, writesBack kindI32] kindI32 True
  pure
    ( conjoin
        [ answerInteger answer === 6
        , drop 2 (answerSlotIntegers answer) === [14]
        ]
    )

testMissingReadback :: IO Property
testMissingReadback = do
  answer <- callWith writeI32 [writesBack kindI32] kindVoid False
  pure (answerCode answer === 6)

{-| Give back what the fixture made, so a test that proves a resource arrived
    does not also leak it. -}
release :: [Int64] -> IO Bool
release addresses = case filter (/= 0) addresses of
  [] -> pure False
  found -> do
    mapM_ (boxDelete . intPtrToPtr . fromIntegral) found
    pure True
