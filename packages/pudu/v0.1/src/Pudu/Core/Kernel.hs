{-| @Core.Kernel — the runtime kernels a `CoreKernel` expression names. -}
module Pudu.Core.Kernel (CoreKernelName (..)) where

import Data.Text (Text)

{-| Each kernel reads held operands and answers one value. A test kernel
    answers whether the read beside it may run. -}
data CoreKernelName
  {-| Whether a box a kernel answered is there. -}
  = KernelPresent
  | KernelBufferAlloc
  {-| Whether `width` bytes at the offset lie inside; the width is the integer. -}
  | KernelBufferFits
  | KernelBufferReadU64
  | KernelBufferReadI64
  | KernelBufferReadF64
  | KernelBufferReadU32
  {-| The low `width` bytes of an integer written at the offset. -}
  | KernelBufferWriteWord
  | KernelBufferWriteF64
  | KernelBufferSpanFits
  | KernelBufferFill
  | KernelBufferPairFits
  | KernelBufferCompare
  | KernelBufferCopy
  {-| The word index of the needle, or -1. -}
  | KernelBufferScan
  | KernelColumnSumU64
  {-| Whether any row is valid and readable, for either element kind. -}
  | KernelColumnAny
  | KernelColumnMinU64
  | KernelColumnMaxU64
  | KernelColumnFilterU64
  | KernelColumnProject
  | KernelColumnSumF64
  | KernelColumnMinF64
  | KernelColumnMaxF64
  {-| The integer picks greater-than (1) or less-than (2). -}
  | KernelColumnFilterF64
  | KernelColumnAddF64
  {-| The integer picks and (0) or or (1). -}
  | KernelColumnBitmap
  | KernelColumnBitmapNot
  | KernelColumnBitmapCount
  {-| The integer picks unsigned (0) or float (1) rows. -}
  | KernelColumnSort
  {-| Whether a binary search finds the target, and the row it finds. -}
  | KernelColumnFoundU64
  | KernelColumnFoundF64
  | KernelColumnSearchU64
  | KernelColumnSearchF64
  | KernelColumnGather
  | KernelSha256
  | KernelSha512
  {-| The integer is the digest's size in bytes: 32 or 64. -}
  | KernelSha3
  | KernelBlake2b
  | KernelHmacSha256
  | KernelHmacSha512
  | KernelDeriveKey
  | KernelConstantTimeEqual
  | KernelChecksumKnown
  | KernelChecksum
  | KernelSealFits
  | KernelSeal
  | KernelOpenFits
  | KernelOpen
  | KernelVerifyRsa
  | KernelVerifyEcdsa
  | KernelAudioToneFits
  | KernelAudioTone
  | KernelAudioRampFits
  | KernelAudioRamp
  {-| The integers are the Json variants' indexes: Null, Boolean, Number,
      Fractional, Text, List, Object. -}
  | KernelJsonDecode
  | KernelJsonEncode
  {-| The integers are the Tag fields' positions (name, attributes,
      children), then the Node variants' indexes (Element, Content). -}
  | KernelXmlDecode
  | KernelCsvDelimiter
  | KernelCsvRecords
  | KernelSwissCapacity
  {-| The slot holding the key, or -1. -}
  | KernelSwissFind
  | KernelSwissInsert
  | KernelSwissDelete
  {-| A host kernel, named by the runtime part that defines it. -}
  | KernelHost !Text
  {-| What the last host kernel on this thread left: 0 done, 1 failed,
      2 nothing there, 3 ended. -}
  | KernelHostState
  {-| What the host said when it failed; read once. -}
  | KernelHostMessage
  deriving stock (Eq, Show)
