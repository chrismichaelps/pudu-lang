{-| @Test.Compiler.Program.StdlibSpec — standard library discovery and resolution tests -}
module Pudu.Compiler.Program.StdlibSpec
  ( stdlibProperties
  , testResolutionFreshness
  , testStandardLibrary
  ) where

import Control.Exception (bracket)
import Data.List (nub)
import Data.List.NonEmpty (NonEmpty (..))
import qualified Data.Text as Text
import Pudu.Compiler.Library
  ( ResolutionMetrics (..)
  , newResolutionContext
  , resolutionMetrics
  , resolutionSearchRoots
  )
import Pudu.Compiler.Program.Common (codes, helps, messages, moduleNames)
import Pudu.Frontend.Syntax.Name (ModuleName (..))
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

stdlibProperties :: [(String, IO Property)]
stdlibProperties =
  [ ("the standard library resolves from the distribution", testStandardLibrary)
  , ("standard-library roots refresh between invocations", testResolutionFreshness)
  ]

{-| Environment and filesystem roots are stable inside one context and fresh
    in the next. Candidate aliases are removed before they can duplicate search
    work or change first-root precedence. -}
testResolutionFreshness :: IO Property
testResolutionFreshness = withSystemTempDirectory "pudu-library-roots" $ \root ->
  withRestoredEnv "PUDU_LIB" $ do
    let sourceRoot = root </> "source"
        firstLibrary = root </> "library-a"
        secondLibrary = root </> "library-b"
        standardModule = ModuleName ("Std" :| ["Probe"])
    mapM_ (createDirectoryIfMissing True) [sourceRoot, firstLibrary, secondLibrary]
    setEnv "PUDU_LIB" firstLibrary
    first <- newResolutionContext sourceRoot
    setEnv "PUDU_LIB" secondLibrary
    second <- newResolutionContext sourceRoot
    let firstRoots = resolutionSearchRoots first standardModule
        secondRoots = resolutionSearchRoots second standardModule
        firstMetrics = resolutionMetrics first
    pure $ conjoin
      [ counterexample "the first invocation retains its configured library"
          (elem firstLibrary firstRoots === True)
      , counterexample "the next invocation sees the changed environment"
          (conjoin [elem secondLibrary secondRoots === True, elem firstLibrary secondRoots === False])
      , counterexample "ordered candidates appear only once"
          (conjoin [firstRoots === nub firstRoots, secondRoots === nub secondRoots])
      , counterexample "the executable ancestor walk occurs once during setup"
          (resolutionExecutableAncestors firstMetrics > 0)
      , counterexample "library roots are probed only during setup"
          (resolutionMetrics first === firstMetrics)
      ]

withRestoredEnv :: String -> IO a -> IO a
withRestoredEnv name action = bracket (lookupEnv name) restore (const action)
 where
  restore Nothing = unsetEnv name
  restore (Just value) = setEnv name value

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
  missingLocations <- helps "test-fixtures/stdlib/MissingStd.pudu"
  ordinary <- codes "test-fixtures/stdlib/MissingOwn.pudu"
  floatRangeDiagnostics <- codes "test-fixtures/stdlib/RejectsFloatRange.pudu"
  missingMember <- codes "test-fixtures/stdlib/RejectsMissingMember.pudu"
  missingConstructor <- codes "test-fixtures/stdlib/RejectsMissingConstructorPattern.pudu"
  qualifiedRecord <- codes "test-fixtures/stdlib/AcceptsQualifiedRecordPattern.pudu"
  missingMemberHelp <- helps "test-fixtures/stdlib/RejectsMissingMember.pudu"
  unqualifiedHelp <- helps "test-fixtures/stdlib/RejectsUnqualifiedMember.pudu"
  unknownHelp <- helps "test-fixtures/stdlib/RejectsUnknownMember.pudu"
  resolved <- moduleNames "test-fixtures/stdlib/UsesStd.pudu"
  numberMisuse <- codes "test-fixtures/stdlib/RejectsTextToNumberMisuse.pudu"
  textMisuse <- codes "test-fixtures/stdlib/RejectsToTextMisuse.pudu"
  pure $ conjoin
    [ counterexample "a standard import compiles with no program-local module" (uses === [])
    , counterexample "a program may shadow a standard module" (shadows === [])
    , counterexample "reading a number answers an option and takes nothing"
        (numberMisuse === ["E3001", "E3003"])
    , counterexample "toText answers text and takes nothing, and a literal's members are checked"
        (textMisuse === ["E3001", "E3003", "E3005", "E3001"])
    , counterexample "an unknown standard module is a missing module" (missing === ["E2014"])
    , counterexample "the diagnostic names the module that could not be read"
        (any (Text.isInfixOf "Std.NotAThing") missingHelp === True)
    , counterexample "the help names every library location it looked in, none of them empty"
        ( any
            (\help -> Text.isInfixOf "PUDU_LIB" help
              && Text.isInfixOf "looked in " help
              && Text.isInfixOf ", " help
              && not (Text.isInfixOf ", ," help)
              && not (Text.isSuffixOf "looked in " help))
            missingLocations
            === True
        )
    , counterexample "an unknown ordinary module is still a missing module" (ordinary === ["E2014"])
    , counterexample "a numeric range still requires a whole-number type"
        (floatRangeDiagnostics === ["E3012"])
    , counterexample "a member the module does not export is reported once"
        (missingMember === ["E3033"])
    , counterexample "a missing qualified pattern constructor is reported once"
        (missingConstructor === ["E3033"])
    , counterexample "a record type reached through its module is a pattern, not a missing constructor"
        (qualifiedRecord === [])
    , counterexample "a built-in method written as a module function says so"
        (any (Text.isInfixOf "built-in method") missingMemberHelp === True)
    , counterexample "a prelude binding reached through a module says so instead"
        (any (Text.isInfixOf "available unqualified") unqualifiedHelp === True)
    , counterexample "and a name that is neither only says to check the exports"
        (any (Text.isInfixOf "check the spelling against what") unknownHelp === True)
    , counterexample "the standard module joins the program graph"
        (elem "Std.Math" resolved === True)
    ]
