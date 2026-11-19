{-| @Pudu.Diagnostic.Native — every diagnostic the native compilation path can
    raise, in one module.

    The `E6xxx` family is owned here so the code registry sees each code once
    and so "what can native compilation tell me" is one reviewable page:
    `E6001` refuses a construct the native subset does not carry, and
    `E6002`–`E6006` translate the native toolchain's failure modes; `E6007`
    and `E6008` are a mobile target's missing SDK and refused construct;
    `E6009`, `E6010`, `W6011` and `W6012` are the platform ledger's findings
    about the installed toolchain; `E6013` refuses an asset an application
    cannot carry; `E6014`–`E6016` refuse an application's permissions and
    `W6017` reports one declared but never requested. Spans
    point at the program being built — the refused construct, or the root
    module's first token for environment failures — so the ordinary renderer
    shows a real file and line.
-}
module Pudu.Diagnostic.Native
  ( assetRefused
  , permissionReasonMissing
  , permissionUndeclared
  , permissionUnknown
  , permissionUnused
  , ledgerFindingLine
  , ledgerRefusal
  , ledgerWarning
  , nativeRefusal
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
import Data.Time.Calendar (showGregorian)
import Pudu.Backend.Ledger (Finding (..), Purpose (..), StoreRule (..), renderRelease)
import Pudu.Diagnostic (Diagnostic, Severity (Error), diagnostic, mkDiagnosticCode, withHelp)
import Pudu.Source (Span)

{-| A construct outside the native subset, refused at its own span. -}
nativeRefusal :: Span -> Text -> Diagnostic
nativeRefusal spanValue construct =
  buildDiagnostic "E6001" spanValue
    ("the native backend does not support " <> construct <> " yet")
    ( Just
        ( "run this program with the tree interpreter (`pudu run`), "
            <> "or rewrite the construct at this location in a form the native backend carries"
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

{-| An asset the application cannot carry: a name another platform may read
    differently, or a symbolic link. -}
assetRefused :: Span -> Text -> Diagnostic
assetRefused spanValue reason =
  buildDiagnostic "E6013" spanValue
    ("the application's assets cannot be packaged: " <> reason)
    (Just "asset names use ASCII letters, digits, dots, dashes and underscores; copy linked files into the assets directory")

{-| A permission the program can request that its manifest does not
    declare: the platform would refuse the request, or stop the application. -}
permissionUndeclared :: Span -> Text -> Diagnostic
permissionUndeclared spanValue key =
  buildDiagnostic "E6014" spanValue
    ("the program can request the " <> key <> " permission, which the manifest does not declare")
    (Just ("add `" <> key <> " = \"<the reason the person reads>\"` under [app.permissions] in pudu.toml"))

{-| A manifest permission key no kind has. -}
permissionUnknown :: Span -> Text -> Int -> Diagnostic
permissionUnknown spanValue key line =
  buildDiagnostic "E6015" spanValue
    ("pudu.toml line " <> Text.pack (show line) <> " declares an unknown permission, " <> key)
    (Just "permissions are camera, microphone, photos, photos-add, location, location-always, notifications, contacts, calendar, bluetooth and motion")

{-| A declared permission without the reason the person reads. -}
permissionReasonMissing :: Span -> Text -> Int -> Diagnostic
permissionReasonMissing spanValue key line =
  buildDiagnostic "E6016" spanValue
    ("pudu.toml line " <> Text.pack (show line) <> " declares the " <> key <> " permission without a reason")
    (Just "the platform shows the reason when it asks; say what the application does with the permission")

{-| A declared permission nothing in the program requests; review rejects an
    application that declares a capability it never uses. -}
permissionUnused :: Text -> Text
permissionUnused key = "warning[W6017]: the manifest declares the " <> key <> " permission, which the program never requests"

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

{-| A ledger finding that refuses the build, spanned at the program being
    built. -}
ledgerRefusal :: Span -> Text -> Finding -> Diagnostic
ledgerRefusal spanValue target finding =
  buildDiagnostic code spanValue ("the " <> target <> " target " <> message) (Just help)
 where
  (code, message, help) = ledgerWording finding

{-| A ledger finding that lets the build proceed, as one printed line. -}
ledgerWarning :: Finding -> Text
ledgerWarning finding = "warning[" <> code <> "]: " <> message
 where
  (code, message, _) = ledgerWording finding

{-| Any finding as its code, message and fix, for a toolchain report. -}
ledgerFindingLine :: Finding -> Text
ledgerFindingLine finding = code <> ": " <> message <> "; " <> help
 where
  (code, message, help) = ledgerWording finding

ledgerWording :: Finding -> (Text, Text, Text)
ledgerWording finding = case finding of
  XcodeBelowMinimum installed lowest ->
    ( "E6009"
    , "needs Xcode " <> renderRelease lowest <> " or later, and the selected Xcode is " <> renderRelease installed
    , "install Xcode " <> renderRelease lowest <> " or later, or set PUDU_XCRUN to its xcrun; pudu doctor --native shows the full report"
    )
  XcodeUntested installed tested ->
    ( "W6011"
    , "is building with Xcode " <> renderRelease installed <> ", newer than Xcode " <> renderRelease tested
        <> ", the newest release this compiler was tested with; the build proceeds"
    , "run the simulator suite with this Xcode before shipping"
    )
  StoreRuleMissed Distribution rule ->
    ("E6010", "cannot be submitted: " <> ruleText rule <> " since " <> ruleDay rule, ruleFix rule)
  StoreRuleMissed Development rule ->
    ( "W6012"
    , "builds for development only: " <> ruleText rule <> " since " <> ruleDay rule <> ", so device builds are refused"
    , ruleFix rule
    )
  StoreRuleDue days rule ->
    ( "W6012"
    , "will not meet a store rule in " <> Text.pack (show days) <> " days: " <> ruleText rule <> " from " <> ruleDay rule
    , ruleFix rule
    )
 where
  ruleText rule =
    ruleStore rule <> " uploads must be built with Xcode " <> renderRelease (ruleXcode rule)
      <> " and the SDK " <> renderRelease (ruleSdk rule)
  ruleDay = Text.pack . showGregorian . ruleFrom
  ruleFix rule = "install Xcode " <> renderRelease (ruleXcode rule) <> " or later (" <> ruleSource rule <> ")"

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
