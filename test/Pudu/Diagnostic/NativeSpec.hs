module Pudu.Diagnostic.NativeSpec (nativeDiagnosticProperties) where

import Pudu.Diagnostic (Severity (Error), diagnosticCode, diagnosticCodeText,
  diagnosticHelp, diagnosticMessage, diagnosticRelated, diagnosticSeverity, diagnosticSpan)
import Pudu.Diagnostic.Native (nativeRefusal, toolchainNotFound, toolchainInvocationFailed,
  toolchainTimedOut, toolchainRejected, toolchainPublishFailed)
import Pudu.Diagnostic.Render (RenderStyle (PlainStyle), defaultRenderConfig, renderDiagnosticsWith)
import Pudu.Source (SourceName (SourceName), mkSpan, newSource, offsetFromInt)
import qualified Data.Text as Text
import Test.QuickCheck (Property, conjoin, counterexample, (===))

nativeDiagnosticProperties :: [(String, IO Property)]
nativeDiagnosticProperties = [("native diagnostic contracts preserve codes spans and caller details", testContracts)]

testContracts :: IO Property
testContracts = do
  source <- newSource (SourceName "native-contract.pudu") "aéb\nc"
  let selected = do
        start <- offsetFromInt 1
        end <- offsetFromInt 3
        mkSpan source start end
  pure $ case selected of
    Nothing -> counterexample "invalid diagnostic contract fixture" False
    Just at -> conjoin
      [ counterexample (Text.unpack code) $ conjoin
          [ diagnosticCodeText (diagnosticCode value) === code
          , diagnosticSeverity value === Error, diagnosticSpan value === at
          , diagnosticMessage value === message, diagnosticHelp value === help
          , diagnosticRelated value === []
          , Text.isInfixOf ("error[" <> code <> "]") (rendered value) === True
          , Text.isInfixOf "native-contract.pudu:1:2" (rendered value) === True
          ]
      | (code, value, message, help) <-
          [ ("E6001", nativeRefusal at "async λ", "the native backend does not support async λ yet",
              Just "run this program with the tree interpreter, or keep to the supported subset: Int and Bool locals, while, if, print, and checked integer arithmetic")
          , ("E6002", toolchainNotFound at "PUDU_CC=/missing/cc", "no C compiler found: looked for PUDU_CC=/missing/cc",
              Just "install a C11 compiler, or set PUDU_CC to the compiler to use")
          , ("E6003", toolchainInvocationFailed at "permission denied", "the C compiler could not be started: permission denied", Nothing)
          , ("E6004", toolchainTimedOut at 3, "the C compiler did not finish within 3 seconds and was stopped",
              Just "set PUDU_CC_TIMEOUT to wait longer when a slow machine needs it")
          , ("E6005", toolchainRejected at "line one\néchec", "the C compiler rejected the generated C:\nline one\néchec",
              Just "this is a compiler defect: please report it with the program that triggered it")
          , ("E6006", toolchainPublishFailed at "read-only file system", "the compiled executable could not be written: read-only file system", Nothing)
          ]
      , let rendered value' = renderDiagnosticsWith (defaultRenderConfig PlainStyle) source [value']
      ]
