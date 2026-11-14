{-| @Pudu.Diagnostic.Native — every diagnostic the native compilation path can
    raise, in one module.

    The `E6xxx` family is owned here so the code registry sees each code once
    and so "what can native compilation tell me" is one reviewable page:
    `E6001` refuses a construct the native subset does not carry, and
    `E6002`–`E6006` translate the native toolchain's failure modes; `E6007`
    and `E6008` are a mobile target's missing SDK and refused construct. Spans
    point at the program being built — the refused construct, or the root
    module's first token for environment failures — so the ordinary renderer
    shows a real file and line.
-}
module Pudu.Diagnostic.Native
  ( nativeRefusal
  , platformSdkMissing
  , targetRefusal
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

{-| A construct outside the native subset, refused at its own span. -}
nativeRefusal :: Span -> Text -> Diagnostic
nativeRefusal spanValue construct =
  buildDiagnostic "E6001" spanValue
    ("the native backend does not support " <> construct <> " yet")
    ( Just
        ( "run this program with the tree interpreter, or keep to the supported subset: "
            <> "Int and Bool locals, while, if, print, and checked integer arithmetic"
        )
    )

{-| The C compiler could not be found. -}
toolchainNotFound :: Span -> Text -> Diagnostic
toolchainNotFound spanValue searched =
  buildDiagnostic "E6002" spanValue
    ("no C compiler found: looked for " <> searched)
    (Just "install a C11 compiler, or set PUDU_CC to the compiler to use")

{-| The C compiler could not be started. -}
toolchainInvocationFailed :: Span -> Text -> Diagnostic
toolchainInvocationFailed spanValue reason =
  buildDiagnostic "E6003" spanValue
    ("the C compiler could not be started: " <> reason)
    Nothing

{-| The C compiler did not finish within the bounded wait. -}
toolchainTimedOut :: Span -> Int -> Diagnostic
toolchainTimedOut spanValue seconds =
  buildDiagnostic "E6004" spanValue
    ( "the C compiler did not finish within "
        <> textOfInt seconds
        <> " seconds and was stopped"
    )
    (Just "set PUDU_CC_TIMEOUT to wait longer when a slow machine needs it")

{-| The C compiler rejected the generated C; its output arrives bounded and
    marked when truncated. -}
toolchainRejected :: Span -> Text -> Diagnostic
toolchainRejected spanValue output =
  buildDiagnostic "E6005" spanValue
    ("the C compiler rejected the generated C:\n" <> output)
    (Just "this is a compiler defect: please report it with the program that triggered it")

{-| The compiled artifact could not be published. -}
toolchainPublishFailed :: Span -> Text -> Diagnostic
toolchainPublishFailed spanValue reason =
  buildDiagnostic "E6006" spanValue
    ("the compiled artifact could not be written: " <> reason)
    Nothing

{-| A mobile target whose platform SDK was not found, naming what was looked
    for. -}
platformSdkMissing :: Span -> Text -> Text -> Diagnostic
platformSdkMissing spanValue target detail =
  buildDiagnostic "E6007" spanValue
    ("the " <> target <> " target needs its platform SDK, which was not found: " <> detail)
    ( Just
        ( "install Xcode for an iOS target (or set PUDU_XCRUN to its xcrun), "
            <> "or the Android NDK for an Android target (set ANDROID_NDK_HOME)"
        )
    )

{-| A construct the target cannot carry, refused before any tool runs. -}
targetRefusal :: Span -> Text -> Text -> Text -> Diagnostic
targetRefusal spanValue target construct reason =
  buildDiagnostic "E6008" spanValue
    ("the " <> target <> " target cannot carry " <> construct <> ": " <> reason)
    (Just "build for the host without --target to keep it, or keep it out of the program built for this target")

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
