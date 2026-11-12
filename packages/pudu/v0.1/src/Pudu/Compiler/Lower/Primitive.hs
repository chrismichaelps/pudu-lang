{-| @Compiler.Lower.Primitive — the direct call of a prelude primitive, tried
    by family in one fixed order. -}
module Pudu.Compiler.Lower.Primitive (lowerPrimitiveCall) where

import Data.Foldable (asum)
import Data.Text (Text)
import Pudu.Compiler.Lower.Concurrent (lowerConcurrentPrimitive)
import Pudu.Compiler.Lower.Decimal (lowerDecimalPrimitive)
import Pudu.Compiler.Lower.Foreign (lowerForeignCall)
import Pudu.Compiler.Lower.Kernel (lowerKernelPrimitive)
import Pudu.Compiler.Lower.State (LowerState)
import Pudu.Compiler.Lower.Store (lowerStorePrimitive)
import Pudu.Compiler.Lower.Swiss (lowerSwissPrimitive)
import Pudu.Compiler.Lower.Text (lowerTextPrimitive)
import Pudu.Compiler.Lower.WordMap (lowerWordMapPrimitive)
import Pudu.Core (CoreExpression, CoreType)
import Pudu.Frontend.Syntax (Expression, Located)
import Pudu.Source (Span)

type Lowered = (LowerState, Maybe (CoreExpression, CoreType))

{-| Nothing for a name no family claims. -}
lowerPrimitiveCall :: (LowerState -> Located Expression -> Lowered)
  -> LowerState -> Span -> Text -> [Located Expression] -> Maybe Lowered
lowerPrimitiveCall lower state at name arguments = asum
  [ family lower state at name arguments
  | family <- [lowerTextPrimitive, lowerDecimalPrimitive, lowerWordMapPrimitive, lowerStorePrimitive, lowerKernelPrimitive, lowerSwissPrimitive, lowerConcurrentPrimitive, lowerForeignCall] ]
