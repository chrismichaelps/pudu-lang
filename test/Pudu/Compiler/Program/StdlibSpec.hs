{-| @Test.Compiler.Program.StdlibSpec — standard library discovery and resolution tests -}
module Pudu.Compiler.Program.StdlibSpec
  ( stdlibProperties
  , testStandardLibrary
  ) where

import qualified Data.Text as Text
import Pudu.Compiler.Program.Common (codes, helps, messages, moduleNames)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

stdlibProperties :: [(String, IO Property)]
stdlibProperties =
  [ ("the standard library resolves from the distribution", testStandardLibrary)
  ]

{-| The `Std` namespace resolves without the program declaring anything, and
    the program's own tree still wins when it declares a standard module
    itself — deliberately and visibly, since the file is in its own source
    root. -}
testStandardLibrary :: IO Property
testStandardLibrary = do
  uses <- codes "test-fixtures/stdlib/UsesStd.pudu"
  shadows <- codes "test-fixtures/stdshadow/ShadowsStd.pudu"
  missing <- codes "test-fixtures/stdlib/MissingStd.pudu"
  missingHelp <- messages "test-fixtures/stdlib/MissingStd.pudu"
  ordinary <- codes "test-fixtures/stdlib/MissingOwn.pudu"
  floatRangeDiagnostics <- codes "test-fixtures/stdlib/RejectsFloatRange.pudu"
  missingMember <- codes "test-fixtures/stdlib/RejectsMissingMember.pudu"
  missingMemberHelp <- helps "test-fixtures/stdlib/RejectsMissingMember.pudu"
  unqualifiedHelp <- helps "test-fixtures/stdlib/RejectsUnqualifiedMember.pudu"
  unknownHelp <- helps "test-fixtures/stdlib/RejectsUnknownMember.pudu"
  resolved <- moduleNames "test-fixtures/stdlib/UsesStd.pudu"
  pure $ conjoin
    [ counterexample "a standard import compiles with no program-local module" (uses === [])
    , counterexample "a program may shadow a standard module" (shadows === [])
    , counterexample "an unknown standard module is a missing module" (missing === ["E2014"])
    , counterexample "the diagnostic names the module that could not be read"
        (any (Text.isInfixOf "Std.NotAThing") missingHelp === True)
    , counterexample "an unknown ordinary module is still a missing module" (ordinary === ["E2014"])
    , counterexample "a numeric range still requires a whole-number type"
        (floatRangeDiagnostics === ["E3012"])
    , counterexample "a member the module does not export is reported once"
        (missingMember === ["E3033"])
    , counterexample "a built-in method written as a module function says so"
        (any (Text.isInfixOf "built-in method") missingMemberHelp === True)
    , counterexample "a prelude binding reached through a module says so instead"
        (any (Text.isInfixOf "available unqualified") unqualifiedHelp === True)
    , counterexample "and a name that is neither only says to check the exports"
        (any (Text.isInfixOf "check the spelling against what") unknownHelp === True)
    , counterexample "the standard module joins the program graph"
        (elem "Std.Math" resolved === True)
    ]
