{-| @Backend.Emit.Kernel — the runtime call behind each kernel: its function,
    the part that defines it, and how the operand cells are passed. -}
module Pudu.Backend.Emit.Kernel (frameKernel) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.Emit.Cell (aggregateHelper, aggregateNeed)
import Pudu.Core (CoreKernelName (..), CoreType (..))
import Pudu.Core.Frame (FrameFault (..), FrameSlot (..), FrameValue (..))
import Pudu.IntegerLiteral (IntegerKind (UnsignedKind))

{-| How one kernel is called: the function and its part, the operands passed
    as their unsigned word, and fixed arguments after the layout integers. -}
data Entry = Entry !Text ![Int] ![Text]

{-| The call text and the parts it needs. Operands are passed in order as
    the frame holds them, then the kernel's integers, then the fixed
    arguments. A flat-table kernel also takes the tree operations of the
    control store and the slot store. -}
frameKernel :: (FrameSlot -> Either FrameFault Text) -> FrameValue -> CoreKernelName -> [Int] -> [FrameSlot]
  -> Either FrameFault (Text, [Text])
frameKernel readSlot value name constants arguments = do
  cells <- traverse readSlot arguments
  case name of
    KernelPresent -> case cells of
      [box] -> Right ("(" <> box <> " != NULL)", [])
      _ -> refused "a presence test without one box"
    _ | name `elem` [KernelSwissFind, KernelSwissInsert, KernelSwissDelete] -> case map frameSlotType arguments of
          CoreRecordType _ [held] : _ ->
            let word = CoreIntegerType (UnsignedKind 64)
                stores = [CoreStoreType word, CoreStoreType (CoreTupleType [word, held])]
             in Right ( call (cells <> [aggregateHelper "ops" store <> "()" | store <- stores])
                      , part : [aggregateNeed "ops" store | store <- stores] )
          _ -> refused "a flat-table kernel without its table"
    _ -> Right (call (passed cells <> map (Text.pack . show) constants <> fixed), [part])
 where
  Entry function worded fixed = kernelEntry name
  part = Text.drop 5 function
  call operands = function <> "(" <> Text.intercalate ", " operands <> ")"
  passed cells = [if position `elem` worded then cell <> ".bits" else cell | (position, cell) <- zip [0 ..] cells]
  refused reason = Left (FrameFault (Just (frameValueSpan value)) reason)

kernelEntry :: CoreKernelName -> Entry
kernelEntry name = case name of
  KernelPresent -> plain "pudu_kernel_present"
  KernelBufferAlloc -> plain "pudu_buffer_alloc"
  KernelBufferFits -> plain "pudu_buffer_fits"
  KernelBufferReadU64 -> plain "pudu_buffer_read_u64"
  KernelBufferReadI64 -> plain "pudu_buffer_read_i64"
  KernelBufferReadF64 -> plain "pudu_buffer_read_f64"
  KernelBufferReadU32 -> plain "pudu_buffer_read_u32"
  KernelBufferWriteWord -> plain "pudu_buffer_write_word"
  KernelBufferWriteF64 -> plain "pudu_buffer_write_f64"
  KernelBufferSpanFits -> plain "pudu_buffer_span_fits"
  KernelBufferFill -> plain "pudu_buffer_fill"
  KernelBufferPairFits -> plain "pudu_buffer_pair_fits"
  KernelBufferCompare -> plain "pudu_buffer_compare"
  KernelBufferCopy -> plain "pudu_buffer_copy"
  KernelBufferScan -> plain "pudu_buffer_scan"
  KernelColumnSumU64 -> plain "pudu_column_sum_u64"
  KernelColumnAny -> plain "pudu_column_any"
  KernelColumnMinU64 -> Entry "pudu_column_extreme_u64" [] ["0"]
  KernelColumnMaxU64 -> Entry "pudu_column_extreme_u64" [] ["1"]
  KernelColumnFilterU64 -> Entry "pudu_column_filter" [3] ["0"]
  KernelColumnProject -> plain "pudu_column_project"
  KernelColumnSumF64 -> plain "pudu_column_sum_f64"
  KernelColumnMinF64 -> Entry "pudu_column_extreme_f64" [] ["0"]
  KernelColumnMaxF64 -> Entry "pudu_column_extreme_f64" [] ["1"]
  KernelColumnFilterF64 -> plain "pudu_column_filter"
  KernelColumnAddF64 -> plain "pudu_column_add_f64"
  KernelColumnBitmap -> plain "pudu_column_bitmap"
  KernelColumnBitmapNot -> plain "pudu_column_bitmap_not"
  KernelColumnBitmapCount -> plain "pudu_column_bitmap_count"
  KernelColumnSort -> plain "pudu_column_sort"
  KernelColumnFoundU64 -> Entry "pudu_column_found" [3] ["0"]
  KernelColumnFoundF64 -> Entry "pudu_column_found" [] ["1"]
  KernelColumnSearchU64 -> Entry "pudu_column_row" [3] ["0"]
  KernelColumnSearchF64 -> Entry "pudu_column_row" [] ["1"]
  KernelColumnGather -> plain "pudu_column_gather"
  KernelSha256 -> plain "pudu_sha256_of"
  KernelSha512 -> plain "pudu_sha512_of"
  KernelSha3 -> plain "pudu_sha3_of"
  KernelBlake2b -> plain "pudu_blake2b_of"
  KernelHmacSha256 -> plain "pudu_hmac_sha256_of"
  KernelHmacSha512 -> plain "pudu_hmac_sha512_of"
  KernelDeriveKey -> plain "pudu_derive_key"
  KernelConstantTimeEqual -> plain "pudu_constant_time_equal"
  KernelChecksumKnown -> plain "pudu_checksum_known"
  KernelChecksum -> plain "pudu_checksum"
  KernelSealFits -> plain "pudu_seal_fits"
  KernelSeal -> plain "pudu_seal"
  KernelOpenFits -> plain "pudu_open_fits"
  KernelOpen -> plain "pudu_open_sealed"
  KernelVerifyRsa -> plain "pudu_verify_rsa"
  KernelVerifyEcdsa -> plain "pudu_verify_ecdsa"
  KernelAudioToneFits -> plain "pudu_audio_tone_fits"
  KernelAudioTone -> plain "pudu_audio_tone"
  KernelAudioRampFits -> plain "pudu_audio_ramp_fits"
  KernelAudioRamp -> plain "pudu_audio_ramp"
  KernelJsonDecode -> plain "pudu_json_decode"
  KernelJsonEncode -> plain "pudu_json_encode"
  KernelXmlDecode -> plain "pudu_xml_decode"
  KernelCsvDelimiter -> plain "pudu_csv_delimiter"
  KernelCsvRecords -> plain "pudu_csv_records"
  KernelSwissCapacity -> plain "pudu_swiss_capacity"
  KernelSwissFind -> plain "pudu_swiss_find"
  KernelSwissInsert -> plain "pudu_swiss_insert"
  KernelSwissDelete -> plain "pudu_swiss_delete"
 where
  plain function = Entry function [] []
