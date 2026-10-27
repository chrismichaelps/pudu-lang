{-| @Program.FloatKernel — names and shapes of the runtime's binary64 kernels

    The one list the evaluator, checker and name resolution read, so they cannot
    disagree about which kernels exist or what they take. Implementations live
    in the runtime layer; this module states identity only. -}
module Pudu.FloatKernel
  ( FloatKernel (..)
  , KernelShape (..)
  , floatKernelName
  , floatKernelShape
  , floatKernels
  ) where

import Data.Text (Text)

data FloatKernel
  = KernelSqrt
  | KernelCbrt
  | KernelFloor
  | KernelCeil
  | KernelTrunc
  | KernelRound
  | KernelSin
  | KernelCos
  | KernelTan
  | KernelAsin
  | KernelAcos
  | KernelAtan
  | KernelAtan2
  | KernelExp
  | KernelLn
  | KernelLog2
  | KernelLog10
  | KernelPow
  | KernelHypot
  | KernelSinh
  | KernelCosh
  | KernelTanh
  | KernelFma
  | KernelToBits
  | KernelFromBits
  deriving stock (Eq, Ord, Show, Enum, Bounded)

{-| Float arguments taken, or a bit cast between Float64 and UInt64. -}
data KernelShape = FloatArguments !Int | FloatToWord | WordToFloat
  deriving stock (Eq, Show)

floatKernels :: [FloatKernel]
floatKernels = [minBound .. maxBound]

{-| The prelude name a kernel is bound under. -}
floatKernelName :: FloatKernel -> Text
floatKernelName kernel = case kernel of
  KernelSqrt -> "floatSqrt"
  KernelCbrt -> "floatCbrt"
  KernelFloor -> "floatFloor"
  KernelCeil -> "floatCeil"
  KernelTrunc -> "floatTrunc"
  KernelRound -> "floatRound"
  KernelSin -> "floatSin"
  KernelCos -> "floatCos"
  KernelTan -> "floatTan"
  KernelAsin -> "floatAsin"
  KernelAcos -> "floatAcos"
  KernelAtan -> "floatAtan"
  KernelAtan2 -> "floatAtan2"
  KernelExp -> "floatExp"
  KernelLn -> "floatLn"
  KernelLog2 -> "floatLog2"
  KernelLog10 -> "floatLog10"
  KernelPow -> "floatPow"
  KernelHypot -> "floatHypot"
  KernelSinh -> "floatSinh"
  KernelCosh -> "floatCosh"
  KernelTanh -> "floatTanh"
  KernelFma -> "floatFma"
  KernelToBits -> "floatToBits"
  KernelFromBits -> "floatFromBits"

floatKernelShape :: FloatKernel -> KernelShape
floatKernelShape kernel = case kernel of
  KernelAtan2 -> FloatArguments 2
  KernelPow -> FloatArguments 2
  KernelHypot -> FloatArguments 2
  KernelFma -> FloatArguments 3
  KernelToBits -> FloatToWord
  KernelFromBits -> WordToFloat
  _ -> FloatArguments 1
