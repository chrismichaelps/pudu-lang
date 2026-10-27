{-| @Pudu.Backend.Runtime.Integer — ordered exact-integer runtime parts and prerequisites. -}
module Pudu.Backend.Runtime.Integer (integerRuntimeParts, integerRuntimeDependencies) where

import Data.Text (Text)
import Pudu.Backend.Runtime.Integer.Value (valueRuntimeParts)
import Pudu.Backend.Runtime.Integer.Arithmetic (arithmeticRuntimeParts)
import Pudu.Backend.Runtime.Integer.Bits (bitRuntimeParts)
import Pudu.Backend.Runtime.Integer.Word128 (word128RuntimeParts, word128RuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Value (wideValueRuntimeParts, wideValueRuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Operations (wideOperationRuntimeParts, wideOperationRuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Display (wideDisplayRuntimeParts, wideDisplayRuntimeDependencies)

integerRuntimeParts :: [(Text, [Text])]
integerRuntimeParts = valueRuntimeParts <> arithmeticRuntimeParts <> bitRuntimeParts
  <> word128RuntimeParts <> wideValueRuntimeParts <> wideOperationRuntimeParts <> wideDisplayRuntimeParts

integerRuntimeDependencies :: Text -> [Text]
integerRuntimeDependencies part = maybe [] id (lookup part dependencies)
  <> word128RuntimeDependencies part <> wideValueRuntimeDependencies part
  <> wideOperationRuntimeDependencies part <> wideDisplayRuntimeDependencies part
 where
  dependencies =
    [ ("fail", ["site", "colored", "cleanup", "error_io", "process_io"])
    , ("memory_failure", ["cleanup", "error_io", "process_io"])
    , ("magnitude", [])
    , ("make", [])
    , ("add_math", ["magnitude", "make"])
    , ("multiply_math", ["magnitude", "make"])
    , ("print_int", ["magnitude"])
    , ("from_bits", ["mask"])
    , ("checked_result", ["magnitude", "from_bits", "site", "colored", "fail"])
    , ("saturate_result", ["magnitude", "make", "from_bits"])
    , ("add", ["add_math", "checked_result"])
    , ("sub", ["add_math", "checked_result"])
    , ("mul", ["multiply_math", "checked_result"])
    , ("div", ["magnitude", "make", "checked_result"])
    , ("rem", ["magnitude", "make", "normal", "site", "colored", "fail"])
    , ("neg", ["checked_result"])
    , ("sat_add", ["add_math", "saturate_result"])
    , ("sat_sub", ["add_math", "saturate_result"])
    , ("sat_mul", ["multiply_math", "saturate_result"])
    , ("bit_and", ["bits", "from_bits"])
    , ("bit_or", ["bits", "from_bits"])
    , ("bit_xor", ["bits", "from_bits"])
    , ("wrap_add", ["bits", "from_bits"])
    , ("wrap_sub", ["bits", "from_bits"])
    , ("wrap_mul", ["bits", "from_bits"])
    , ("bit_not", ["bits", "from_bits"])
    , ("shift_left", ["bits", "from_bits", "site", "colored", "fail"])
    , ("shift_right", ["bits", "from_bits", "site", "colored", "fail", "mask"])
    ]
