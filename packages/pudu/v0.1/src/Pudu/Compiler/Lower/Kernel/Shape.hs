{-| @Compiler.Lower.Kernel.Shape — how a kernel builtin is described: its
    operands, its guards and how its answer is formed. -}
module Pudu.Compiler.Lower.Kernel.Shape
  ( Call (..), Answer (..), Refusal (..), Guard (..), Primitive (..) ) where

import Data.Text (Text)
import Pudu.Core (CoreKernelName, CoreType)

{-| A kernel, its layout integers, and which held operands it reads. -}
data Call = Call !CoreKernelName ![Int] ![Int]

{-| What a builtin answers from its held operands. -}
data Answer
  = Plain !Call
  {-| Some of the read when the test holds, else None. -}
  | Optional !Call !Call
  {-| Some of the index when it is not negative, else None. -}
  | Searched !Call
  {-| Some of the box when the kernel answered one, else None. -}
  | Boxed !Call
  | ByteLength
  {-| A host call: Ok of the answer, or Err of what the host said. -}
  | Outcome !Call
  {-| A host call that may find nothing: Ok of Some, Ok of None, or Err. -}
  | OutcomeOptional !Call
  {-| A host call that cannot fail: Some of the answer, or None. -}
  | Absent !Call
  {-| A host call run for what it does; the answer is unit. -}
  | Effect !Call

{-| What stops a call before its answer: an operand below or above a bound,
    or a test kernel that fails. -}
data Refusal = Below !Int !Integer | Above !Int !Integer | Unless !Call

data Guard = Guard !Refusal !Text !Text

data Primitive = Primitive ![CoreType] !CoreType ![Guard] !Answer
