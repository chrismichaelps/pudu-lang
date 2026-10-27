{-| @Pudu.Diagnostic.Evaluation — the text of evaluation-phase refusals a
    running program can surface.

    One home for the call-depth refusal (`E7002`): the interpreter's
    `descend` and the native runtime's emitted call wrappers both print these
    exact words, so the two renderings cannot drift. The loop step-limit
    refusals share the code but are compile-time-phase diagnostics the native
    runtime never prints, so they stay with the evaluator.
-}
module Pudu.Diagnostic.Evaluation
  ( callDepthCode, callDepthHelp, callDepthMessage ) where

import Data.Text (Text)

callDepthCode :: Text
callDepthCode = "E7002"

callDepthMessage :: Text
callDepthMessage = "call depth exceeded the evaluation limit"

callDepthHelp :: Text
callDepthHelp = "the interactive evaluator bounds recursion"
