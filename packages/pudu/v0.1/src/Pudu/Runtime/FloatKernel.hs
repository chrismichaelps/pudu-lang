{-| @Runtime.FloatKernel — binary64 operations the hardware and platform math library provide

    Exact kernels (square root, rounding, fused multiply-add, bit casts) are
    correctly rounded on every IEEE 754 platform. The remaining kernels follow
    the platform math library's accuracy and may differ in the last bit between
    C libraries. Domain refusals stay in the library that calls them. -}
module Pudu.Runtime.FloatKernel
  ( applyFloatBinary
  , applyFloatTernary
  , applyFloatUnary
  ) where

import Pudu.FloatKernel (FloatKernel (..))

{-| A one-argument kernel; a kernel of another shape answers NaN, which the
    evaluator never reaches because it dispatches on the shape first. -}
applyFloatUnary :: FloatKernel -> Double -> Double
applyFloatUnary kernel x = case kernel of
  KernelSqrt -> sqrt x
  KernelCbrt -> c_cbrt x
  KernelFloor -> c_floor x
  KernelCeil -> c_ceil x
  KernelTrunc -> c_trunc x
  KernelRound -> c_round x
  KernelSin -> c_sin x
  KernelCos -> c_cos x
  KernelTan -> c_tan x
  KernelAsin -> c_asin x
  KernelAcos -> c_acos x
  KernelAtan -> c_atan x
  KernelExp -> c_exp x
  KernelLn -> c_log x
  KernelLog2 -> c_log2 x
  KernelLog10 -> c_log10 x
  KernelSinh -> c_sinh x
  KernelCosh -> c_cosh x
  KernelTanh -> c_tanh x
  _ -> 0 / 0
{-# INLINE applyFloatUnary #-}

applyFloatBinary :: FloatKernel -> Double -> Double -> Double
applyFloatBinary kernel x y = case kernel of
  KernelAtan2 -> c_atan2 x y
  KernelPow -> c_pow x y
  KernelHypot -> c_hypot x y
  _ -> 0 / 0
{-# INLINE applyFloatBinary #-}

applyFloatTernary :: FloatKernel -> Double -> Double -> Double -> Double
applyFloatTernary kernel x y z = case kernel of
  KernelFma -> c_fma x y z
  _ -> 0 / 0
{-# INLINE applyFloatTernary #-}

foreign import ccall unsafe "math.h cbrt" c_cbrt :: Double -> Double
foreign import ccall unsafe "math.h floor" c_floor :: Double -> Double
foreign import ccall unsafe "math.h ceil" c_ceil :: Double -> Double
foreign import ccall unsafe "math.h trunc" c_trunc :: Double -> Double
foreign import ccall unsafe "math.h round" c_round :: Double -> Double
foreign import ccall unsafe "math.h sin" c_sin :: Double -> Double
foreign import ccall unsafe "math.h cos" c_cos :: Double -> Double
foreign import ccall unsafe "math.h tan" c_tan :: Double -> Double
foreign import ccall unsafe "math.h asin" c_asin :: Double -> Double
foreign import ccall unsafe "math.h acos" c_acos :: Double -> Double
foreign import ccall unsafe "math.h atan" c_atan :: Double -> Double
foreign import ccall unsafe "math.h atan2" c_atan2 :: Double -> Double -> Double
foreign import ccall unsafe "math.h exp" c_exp :: Double -> Double
foreign import ccall unsafe "math.h log" c_log :: Double -> Double
foreign import ccall unsafe "math.h log2" c_log2 :: Double -> Double
foreign import ccall unsafe "math.h log10" c_log10 :: Double -> Double
foreign import ccall unsafe "math.h pow" c_pow :: Double -> Double -> Double
foreign import ccall unsafe "math.h hypot" c_hypot :: Double -> Double -> Double
foreign import ccall unsafe "math.h sinh" c_sinh :: Double -> Double
foreign import ccall unsafe "math.h cosh" c_cosh :: Double -> Double
foreign import ccall unsafe "math.h tanh" c_tanh :: Double -> Double
foreign import ccall unsafe "math.h fma" c_fma :: Double -> Double -> Double -> Double
