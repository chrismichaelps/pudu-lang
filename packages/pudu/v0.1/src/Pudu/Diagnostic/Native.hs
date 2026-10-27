{-| Native compilation failures keep source spans; callers own process and capture limits. -}
module Pudu.Diagnostic.Native
  ( nativeRefusal
  , toolchainInvocationFailed
  , toolchainNotFound
  , toolchainPublishFailed
  , toolchainRejected
  , toolchainTimedOut
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, Severity (Error), diagnostic, mkDiagnosticCode, withHelp)
import Pudu.Source (Span)

nativeRefusal :: Span -> Text -> Diagnostic
nativeRefusal spanValue construct =
  buildDiagnostic "E6001" spanValue
    ("the native backend does not support " <> construct <> " yet")
    ( Just
        ( "run this program with the tree interpreter, or keep to the supported subset: "
            <> "Int and Bool locals, while, if, print, and checked integer arithmetic"
        )
    )

toolchainNotFound :: Span -> Text -> Diagnostic
toolchainNotFound spanValue searched =
  buildDiagnostic "E6002" spanValue
    ("no C compiler found: looked for " <> searched)
    (Just "install a C11 compiler, or set PUDU_CC to the compiler to use")

toolchainInvocationFailed :: Span -> Text -> Diagnostic
toolchainInvocationFailed spanValue reason =
  buildDiagnostic "E6003" spanValue
    ("the C compiler could not be started: " <> reason)
    Nothing

toolchainTimedOut :: Span -> Int -> Diagnostic
toolchainTimedOut spanValue seconds =
  buildDiagnostic "E6004" spanValue
    ( "the C compiler did not finish within "
        <> textOfInt seconds
        <> " seconds and was stopped"
    )
    (Just "set PUDU_CC_TIMEOUT to wait longer when a slow machine needs it")

toolchainRejected :: Span -> Text -> Diagnostic
toolchainRejected spanValue output =
  buildDiagnostic "E6005" spanValue
    ("the C compiler rejected the generated C:\n" <> output)
    (Just "this is a compiler defect: please report it with the program that triggered it")

toolchainPublishFailed :: Span -> Text -> Diagnostic
toolchainPublishFailed spanValue reason =
  buildDiagnostic "E6006" spanValue
    ("the compiled executable could not be written: " <> reason)
    Nothing

-- These code literals are checked by the diagnostic registry gate.
buildDiagnostic :: Text -> Span -> Text -> Maybe Text -> Diagnostic
buildDiagnostic code spanValue message help =
  case build of
    Just value -> value
    Nothing -> error ("Pudu.Diagnostic.Native: " <> show code <> " is not a well-formed diagnostic")
 where
  build = do
    validCode <- mkDiagnosticCode code
    value <- diagnostic validCode Error spanValue message
    pure (maybe value (`withHelp` value) help)

textOfInt :: Int -> Text
textOfInt = Text.pack . show
