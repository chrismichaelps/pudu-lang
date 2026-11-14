{-| @Pudu.Diagnostic.Evaluation — shared interpreted/native refusal vocabulary. -}
module Pudu.Diagnostic.Evaluation
  ( callDepthCode, callDepthHelp, callDepthMessage
  , operatorCode, cannotApplyUnaryMessage, cannotApplyBinaryMessage, unsupportedOperatorMessage
  , panicCode, panicArgumentHelp
  , builtinArgumentCode, convertIntegerTargetMessage, convertIntegerTargetHelp ) where

import Data.Text (Text)

callDepthCode :: Text
callDepthCode = "E7002"

callDepthMessage :: Text
callDepthMessage = "call depth exceeded the evaluation limit"

callDepthHelp :: Text
callDepthHelp = "the interactive evaluator bounds recursion"

operatorCode :: Text
operatorCode = "E7001"

cannotApplyUnaryMessage :: Text -> Text -> Text
cannotApplyUnaryMessage operator kind = "cannot apply " <> operator <> " to a " <> kind

cannotApplyBinaryMessage :: Text -> Text -> Text -> Text
cannotApplyBinaryMessage operator left right =
  cannotApplyUnaryMessage operator left <> " and a " <> right

unsupportedOperatorMessage :: Text -> Text
unsupportedOperatorMessage operator = "unsupported operator " <> operator

{-| A violated invariant: `panic` stops with this code and its message. -}
panicCode :: Text
panicCode = "E7007"

panicArgumentHelp :: Text
panicArgumentHelp = "panic takes one string argument"

{-| A built-in given arguments it does not accept. -}
builtinArgumentCode :: Text
builtinArgumentCode = "E7012"

convertIntegerTargetMessage :: Text
convertIntegerTargetMessage = "convertInteger needs the type to convert to"

convertIntegerTargetHelp :: Text
convertIntegerTargetHelp = "write it as a type argument, as in convertInteger[UInt8](value)"
