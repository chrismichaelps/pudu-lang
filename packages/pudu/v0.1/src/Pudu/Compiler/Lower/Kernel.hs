{-| @Compiler.Lower.Kernel — the monomorphic kernel builtins, as direct calls
    and as callable bodies: buffers, columns, digests, checksums, sealing,
    signature checks, audio bytes and the codecs. -}
module Pudu.Compiler.Lower.Kernel (lowerKernelPrimitive, kernelCallable, kernelPrimitive, Primitive) where

import Data.Text (Text)
import Pudu.Compiler.Lower.Array (stopped)
import Pudu.Compiler.Lower.Control (expressionIsPrintValued)
import Pudu.Compiler.Lower.Keyed (Blame (..))
import Pudu.Compiler.Lower.Kernel.Host (hostPrimitives)
import Pudu.Compiler.Lower.Kernel.Shape
import Pudu.Compiler.Lower.State (LowerContext (..), LowerState (..), bindLocal, halt, intType, refused)
import Pudu.Compiler.Lower.Types (LowerTypes, recordFields, sumVariants, typeForSpan)
import Pudu.Core
import Pudu.FloatLiteral (FloatWidth (..))
import Pudu.Frontend.Syntax (Expression, Located (..))
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| A direct call: Nothing for a name that is not a kernel builtin. -}
lowerKernelPrimitive :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerKernelPrimitive lower state at name arguments = do
  primitive@(Primitive parameters result _ _) <- kernelPrimitive (contextTypes (lowerContext state)) name
  pure $ if length arguments /= length parameters
    then halt at ("a call to " <> name <> " with this many arguments") state
    else go primitive result state [] (zip parameters arguments)
 where
  go primitive result current done []
    | typeForSpan (contextTypes (lowerContext current)) at == Just result = answered AtCall primitive current at (reverse done)
    | otherwise = halt at ("a call to " <> name <> " without its exact checked result") current
  go primitive result current done ((expected, argument) : rest) = case lower current argument of
    (after, Nothing) -> refused after
    (after, Just (core, CoreNeverType)) -> (after, Just (stopped at (reverse (core : done)), CoreNeverType))
    (after, Just (core, kind))
      | expressionIsPrintValued core -> halt (locatedSpan argument) "a Result[(), Str] call argument" after
      | kind == expected -> go primitive result after (core : done) rest
      | otherwise -> halt (locatedSpan argument) ("a " <> name <> " argument of type " <> coreTypeName kind) after

{-| The builtin as a value: its function type and its body over parameters. -}
kernelCallable :: LowerTypes -> Text -> Maybe (CoreType, LowerState -> Span -> [CoreExpression] -> Lowered)
kernelCallable types name = do
  primitive@(Primitive parameters result _ _) <- kernelPrimitive types name
  pure (CoreFunctionType parameters result, answered AtCaller primitive)

answered :: Blame -> Primitive -> LowerState -> Span -> [CoreExpression] -> Lowered
answered blame (Primitive parameters result guards answer) state at cores
  | map coreExpressionType cores /= parameters = halt at "a kernel builtin without its checked arguments" state
  | otherwise = case answer of
      Plain call -> finish held [] (kernel result call)
      ByteLength -> case given of
        [buffer] -> finish held [] (expression result (CoreBytesMethod BytesLengthOf buffer []))
        _ -> halt at "a byte length without its buffer" state
      Optional test read' -> optional $ \payload ->
        finish held [] (choice (kernel CoreBoolType test) (kernel payload read'))
      Searched call ->
        let (after, local) = bindLocal held "" intType
            found = expression intType (CoreReadLocal local)
            present = expression CoreBoolType (CoreBinary CoreGreaterOrEqual found (number 0))
         in optional (\_ -> finish after [CoreStatement at (CoreDeclare local (kernel intType call))] (choice present found))
      Outcome call -> case result of
        CoreSumType "Result" [payload, CoreTextType] -> attempted payload call (\found -> Just (ok found))
        _ -> halt at "a host result without a native form" state
      OutcomeOptional call -> case result of
        CoreSumType "Result" [inner@(CoreSumType "Option" [payload]), CoreTextType] ->
          attempted payload call (\found -> Just (ok (unlessAbsent inner 2 found)))
        _ -> halt at "a host result without a native form" state
      Absent call -> optional $ \payload -> attempted payload call (\found -> Just (unlessAbsent result 2 found))
      Effect call -> attempted CoreUnitType call Just
      Boxed call -> optional $ \payload ->
        let (after, local) = bindLocal held "" payload
            found = expression payload (CoreReadLocal local)
            present = expression CoreBoolType (CoreKernel KernelPresent [] [found])
         in finish after [CoreStatement at (CoreDeclare local (kernel payload call))] (choice present found)
 where
  (held, locals) = foldl' hold (state, []) cores
  hold (current, done) core = let (next, local) = bindLocal current "" (coreExpressionType core) in (next, done <> [local])
  declarations = [CoreStatement (coreExpressionSpan core) (CoreDeclare local core) | (local, core) <- zip locals cores]
  given = [expression (coreLocalType local) (CoreReadLocal local) | local <- locals]
  expression kind shape = CoreExpression at kind shape
  number value = expression intType (CoreIntegerLiteral PlatformSigned value)
  kernel kind (Call name constants positions) = expression kind (CoreKernel name constants [given !! position | position <- positions])
  choice valid value = expression result (CoreIfValue valid
    (CoreBlock [] (Just (expression result (CoreConstruct "Some" [("0", value)])))) (expression result (CoreConstruct "None" [])))
  -- A host kernel leaves its state behind: 0 done, 1 failed, 2 nothing there.
  hostState = kernel intType (Call KernelHostState [] [])
  stateIs level = expression CoreBoolType (CoreBinary CoreEqual hostState (number level))
  unit = expression CoreUnitType (CoreBlockValue (CoreBlock [] Nothing))
  ok found = expression result (CoreConstruct "Ok" [("0", found)])
  unlessAbsent kind level found = expression kind (CoreIfValue (stateIs level)
    (CoreBlock [] (Just (expression kind (CoreConstruct "None" [])))) (expression kind (CoreConstruct "Some" [("0", found)])))
  -- A unit payload is carried by a Bool the kernel answers and nothing reads.
  attempted payload call build =
    let carried = if payload == CoreUnitType then CoreBoolType else payload
        (after, local) = bindLocal held "" carried
        found = if payload == CoreUnitType then unit else expression payload (CoreReadLocal local)
        refusal = expression result (CoreConstruct "Err" [("0", kernel CoreTextType (Call KernelHostMessage [] []))])
        run = CoreStatement at (CoreDeclare local (kernel carried call))
     in case build found of
          Just value | CoreSumType "Result" _ <- result ->
            finish after [run] (expression result (CoreIfValue (stateIs 1) (CoreBlock [] (Just refusal)) value))
          Just value -> finish after [run] value
          Nothing -> halt at "a host result without a native form" state
  optional build = case result of
    CoreSumType "Option" [payload] -> build payload
    _ -> halt at "an Option result without a native form" state
  finish current extra value =
    (current, Just (expression result (CoreBlockValue (CoreBlock (declarations <> map guarded guards <> extra) (Just value))), result))
  guarded (Guard refusal code message) = CoreStatement at (CoreIf (condition refusal)
    (CoreBlock [CoreStatement at (CoreEvaluate (failure code message))] Nothing) Nothing)
  condition refusal = case refusal of
    Below position bound -> expression CoreBoolType (CoreBinary CoreLess (given !! position) (number bound))
    Above position bound -> expression CoreBoolType (CoreBinary CoreGreater (given !! position) (number bound))
    Unless call -> expression CoreBoolType (CoreNot (kernel CoreBoolType call))
  failure code message =
    let text = expression CoreTextType (CoreTextLiteral message)
     in expression CoreNeverType $ case blame of
          AtCall -> CoreFailText code Nothing text Nothing
          AtCaller -> CoreFailCaller code Nothing text

{-| The codec entries need the program's own Json and Xml layouts; every
    other entry is fixed. -}
kernelPrimitive :: LowerTypes -> Text -> Maybe Primitive
kernelPrimitive types name = case name of
  "jsonDecode" -> (\tags -> Primitive [CoreTextType] (option json) [] (Boxed (Call KernelJsonDecode tags [0]))) <$> jsonTags
  "jsonEncode" -> (\tags -> Primitive [json, CoreBoolType] CoreTextType [] (Plain (Call KernelJsonEncode tags [0, 1]))) <$> jsonTags
  "xmlDecode" -> (\places -> Primitive [CoreTextType] (option tag) [] (Boxed (Call KernelXmlDecode places [0]))) <$> xmlPlaces
  _ -> lookup name fixedPrimitives
 where
  json = CoreSumType "Std.Json.Json" []
  tag = CoreRecordType "Std.Xml.Tag" []
  node = CoreSumType "Std.Xml.Node" []
  pairs = CoreArrayType (CoreTupleType [CoreTextType, CoreTextType])
  jsonTags = sumVariants types json >>= indexes
    [ ("Null", []), ("Boolean", [CoreBoolType]), ("Number", [intType]), ("Fractional", [CoreTextType]), ("Text", [CoreTextType])
    , ("List", [CoreArrayType json]), ("Object", [CoreArrayType (CoreTupleType [CoreTextType, json])]) ]
  xmlPlaces = do
    fields <- recordFields types tag
    places <- traverse (\(field, kind) -> lookup (field, kind) (zip fields [0 ..]))
      [("name", CoreTextType), ("attributes", pairs), ("children", CoreArrayType node)]
    tags <- sumVariants types node >>= indexes [("Element", [tag]), ("Content", [CoreTextType])]
    if length fields == 3 then Just (places <> tags) else Nothing
  -- Every expected variant at its index, and no others.
  indexes expected variants
    | length variants /= length expected = Nothing
    | otherwise = traverse (\(label, payload) ->
        lookup (label, payload) [((coreVariantName variant, map snd (coreVariantFields variant)), index) | (index, variant) <- zip [0 ..] variants]) expected

option :: CoreType -> CoreType
option kind = CoreSumType "Option" [kind]

fixedPrimitives :: [(Text, Primitive)]
fixedPrimitives =
  [ ("bufferAlloc", Primitive [intType] bytes [Guard (Below 0 0) "E7004" "buffer allocation size cannot be negative"] (whole KernelBufferAlloc 1))
  , ("bufferSize", Primitive [bytes] intType [] ByteLength)
  , ("bufferReadU64", reading u64 KernelBufferReadU64 8)
  , ("bufferReadI64", reading (CoreIntegerType (SignedKind 64)) KernelBufferReadI64 8)
  , ("bufferReadF64", reading f64 KernelBufferReadF64 8)
  , ("bufferReadU32", reading u32 KernelBufferReadU32 4)
  , ("bufferWriteU64", writing u64 (Call KernelBufferWriteWord [8] [0, 1, 2]) 8)
  , ("bufferWriteI64", writing (CoreIntegerType (SignedKind 64)) (Call KernelBufferWriteWord [8] [0, 1, 2]) 8)
  , ("bufferWriteF64", writing f64 (Call KernelBufferWriteF64 [] [0, 1, 2]) 8)
  , ("bufferWriteU32", writing u32 (Call KernelBufferWriteWord [4] [0, 1, 2]) 4)
  , ("bufferFill", Primitive [bytes, intType, intType, CoreIntegerType (UnsignedKind 8)] (option bytes) []
      (Optional (Call KernelBufferSpanFits [] [0, 1, 2]) (Call KernelBufferFill [] [0, 1, 2, 3])))
  , ("bufferCompare", Primitive [bytes, intType, bytes, intType, intType] (option intType) []
      (Optional (Call KernelBufferPairFits [] [0 .. 4]) (Call KernelBufferCompare [] [0 .. 4])))
  , ("bufferCopy", Primitive [bytes, intType, bytes, intType, intType] (option bytes) []
      (Optional (Call KernelBufferPairFits [] [0 .. 4]) (Call KernelBufferCopy [] [0 .. 4])))
  , ("bufferScanU64", Primitive [bytes, intType, intType, u64] (option intType) [] (Searched (Call KernelBufferScan [] [0 .. 3])))
  , ("columnSumU64", plain column u64 KernelColumnSumU64)
  , ("columnMinU64", extreme u64 KernelColumnMinU64)
  , ("columnMaxU64", extreme u64 KernelColumnMaxU64)
  , ("columnFilterGtU64", plain (column <> [u64]) bytes KernelColumnFilterU64)
  , ("columnProjectU64", plain [bytes, bytes, bytes, intType] triple KernelColumnProject)
  , ("columnSumF64", plain column f64 KernelColumnSumF64)
  , ("columnMinF64", extreme f64 KernelColumnMinF64)
  , ("columnMaxF64", extreme f64 KernelColumnMaxF64)
  , ("columnFilterGtF64", moded (column <> [f64]) bytes KernelColumnFilterF64 1)
  , ("columnFilterLtF64", moded (column <> [f64]) bytes KernelColumnFilterF64 2)
  , ("columnProjectF64", plain [bytes, bytes, bytes, intType] triple KernelColumnProject)
  , ("columnAddF64", plain [bytes, bytes, bytes, bytes, intType] (CoreTupleType [bytes, bytes]) KernelColumnAddF64)
  , ("columnBitmapAnd", moded column bytes KernelColumnBitmap 0)
  , ("columnBitmapOr", moded column bytes KernelColumnBitmap 1)
  , ("columnBitmapNot", plain [bytes, intType] bytes KernelColumnBitmapNot)
  , ("columnBitmapCount", plain [bytes, intType] intType KernelColumnBitmapCount)
  , ("columnSortIndicesU64", moded column bytes KernelColumnSort 0)
  , ("columnSortIndicesF64", moded column bytes KernelColumnSort 1)
  , ("columnBinarySearchU64", Primitive (column <> [u64]) (option intType) []
      (Optional (Call KernelColumnFoundU64 [] [0 .. 3]) (Call KernelColumnSearchU64 [] [0 .. 3])))
  , ("columnBinarySearchF64", Primitive (column <> [f64]) (option intType) []
      (Optional (Call KernelColumnFoundF64 [] [0 .. 3]) (Call KernelColumnSearchF64 [] [0 .. 3])))
  , ("columnGatherU64", plain [bytes, bytes, bytes, intType] triple KernelColumnGather)
  , ("columnGatherF64", plain [bytes, bytes, bytes, intType] triple KernelColumnGather)
  , ("sha256Of", plain [bytes] bytes KernelSha256)
  , ("sha512Of", plain [bytes] bytes KernelSha512)
  , ("sha3_256Of", moded [bytes] bytes KernelSha3 32)
  , ("sha3_512Of", moded [bytes] bytes KernelSha3 64)
  , ("blake2b256Of", moded [bytes] bytes KernelBlake2b 32)
  , ("blake2b512Of", moded [bytes] bytes KernelBlake2b 64)
  , ("hmacSha256Of", plain [bytes, bytes] bytes KernelHmacSha256)
  , ("hmacSha512Of", plain [bytes, bytes] bytes KernelHmacSha512)
  , ("constantTimeEqual", plain [bytes, bytes] CoreBoolType KernelConstantTimeEqual)
  , ("checksumOf", Primitive [intType, u64, bytes] u64
      [Guard (Unless (Call KernelChecksumKnown [] [0])) "E7001" "checksumOf expects a known algorithm and an unsigned previous value"]
      (whole KernelChecksum 3))
  , ("deriveKey", Primitive [bytes, bytes, intType, intType] bytes
      [ Guard (Below 2 1) "E7004" "an iteration count below one derives nothing"
      , Guard (Above 2 10000000) "E7004" "an iteration count above 10000000 is refused"
      , Guard (Below 3 1) "E7004" "a derived key of no length is not a key"
      , Guard (Above 3 1048576) "E7004" "a derived key above 1048576 bytes is refused" ]
      (whole KernelDeriveKey 4))
  , ("verifyRsaSha256", plain [bytes, bytes, bytes, bytes] CoreBoolType KernelVerifyRsa)
  , ("verifyEcdsaSha256", plain [bytes, bytes, bytes, bytes] CoreBoolType KernelVerifyEcdsa)
  , ("sealBytes", Primitive [bytes, bytes, bytes, bytes] (option bytes) []
      (Optional (Call KernelSealFits [] [0, 1]) (Call KernelSeal [] [0 .. 3])))
  , ("openSealedBytes", Primitive [bytes, bytes, bytes, bytes] (option bytes) []
      (Optional (Call KernelOpenFits [] [0 .. 3]) (Call KernelOpen [] [0 .. 2])))
  , ("audioToneBytes", Primitive (replicate 6 intType) (option bytes) []
      (Optional (Call KernelAudioToneFits [] [0 .. 5]) (Call KernelAudioTone [] [0 .. 5])))
  , ("audioRampBytes", Primitive (bytes : replicate 6 intType) (option bytes) []
      (Optional (Call KernelAudioRampFits [] [0 .. 6]) (Call KernelAudioRamp [] [0 .. 6])))
  , ("csvRecords", Primitive [bytes, CoreTextType] (option (CoreTupleType [CoreArrayType (CoreArrayType CoreTextType), intType, intType]))
      [Guard (Unless (Call KernelCsvDelimiter [] [1])) "E7004" "csvRecords reads a one-byte delimiter other than a quote or a line ending"]
      (Boxed (Call KernelCsvRecords [] [0, 1])))
  ] <> hostPrimitives
 where
  bytes = CoreBytesType
  u64 = CoreIntegerType (UnsignedKind 64)
  u32 = CoreIntegerType (UnsignedKind 32)
  f64 = CoreFloatType Float64Width
  column = [bytes, bytes, intType]
  triple = CoreTupleType [bytes, bytes, intType]
  whole name count = Plain (Call name [] [0 .. count - 1])
  plain parameters result name = Primitive parameters result [] (whole name (length parameters))
  moded parameters result name mode = Primitive parameters result [] (Plain (Call name [mode] [0 .. length parameters - 1]))
  extreme kind name = Primitive column (option kind) [] (Optional (Call KernelColumnAny [] [0, 1, 2]) (Call name [] [0, 1, 2]))
  reading kind name width = Primitive [bytes, intType] (option kind) []
    (Optional (Call KernelBufferFits [width] [0, 1]) (Call name [] [0, 1]))
  writing kind call width = Primitive [bytes, intType, kind] (option bytes) []
    (Optional (Call KernelBufferFits [width] [0, 1]) call)
