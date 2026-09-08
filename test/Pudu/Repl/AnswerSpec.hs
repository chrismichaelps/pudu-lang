module Pudu.Repl.AnswerSpec (answerProperties) where

import Control.Exception (finally)
import Data.IORef (newIORef)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import Pudu.Eval.Value (Value (..))
import Pudu.IntegerLiteral (defaultIntegerKind)
import Pudu.Repl.Answer (browseModule, renderReplValue, showState, showType)
import Pudu.Repl.Options (defaultReplOptions, defaultReplSettings)
import Pudu.Repl.Session (EntryResult (..), emptySession, submitEntry)
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, hFlush, openTempFile, stdout)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

answerProperties :: [(String, IO Property)]
answerProperties =
  [ ("type answers preserve warnings and source locations", testTypeAnswers)
  , ("renderReplValue bounds large values when truncation is enabled", testRenderReplValue)
  , ("browseModule categorizes and documents external modules", testBrowseModule)
  , ("showState isolates bindings, declarations, and imports", testShowState)
  ]

{-| Warning diagnostics do not make a valid expression ill-typed, while an
    error must still point at the exact interactive source the reader entered. -}
testTypeAnswers :: IO Property
testTypeAnswers = do
  let warningExpression =
        "fn(value: Result[Int, Str]) -> Result[Int, Str] { "
          <> "match value { case Err(problem) => Err(problem) "
          <> "case Ok(found) => Ok(found + 1) } }"
  warningOutput <- captureStdout (showType defaultReplOptions emptySession warningExpression)
  invalidOutput <- captureStdout (showType defaultReplOptions emptySession "notInScope")
  pure $ conjoin
    [ counterexample "a warning is reported"
        (property (Text.isInfixOf "warning[W3003]" warningOutput))
    , counterexample ("a warning does not suppress the valid type:\n" <> Text.unpack warningOutput)
        (property (Text.isInfixOf " :: fn(" warningOutput))
    , counterexample "an invalid query retains the submitted location"
        (property (Text.isInfixOf "<interactive>:1:1" invalidOutput))
    , counterexample "an invalid query quotes the submitted source"
        (property (Text.isInfixOf "1 | notInScope" invalidOutput))
    ]

{-| Capture one command's user-facing answer without starting a terminal. The
    original stdout handle is restored even if the command fails, so this
    regression cannot corrupt the rest of the test run. -}
captureStdout :: IO () -> IO Text
captureStdout action = do
  directory <- getTemporaryDirectory
  (path, capture) <- openTempFile directory "pudu-repl-answer.txt"
  original <- hDuplicate stdout
  hFlush stdout
  hDuplicateTo capture stdout
  action `finally` do
    hFlush stdout
    hDuplicateTo original stdout
    hClose original
    hClose capture
  output <- TextIO.readFile path
  removeFile path
  pure output

testRenderReplValue :: IO Property
testRenderReplValue = do
  let largeArray = ArrayValue (Seq.fromList [IntValue defaultIntegerKind i | i <- [1 .. 60]])
      truncated = renderReplValue True largeArray
      full = renderReplValue False largeArray
      longString = StrValue (Text.replicate 600 "a")
      truncStr = renderReplValue True longString
      fullStr = renderReplValue False longString
  pure $ conjoin
    [ counterexample "array is truncated with (+10 more)"
        (property (Text.isInfixOf "(+10 more)" truncated))
    , counterexample "array is not truncated when disabled"
        (property (not (Text.isInfixOf "(+10 more)" full)))
    , counterexample "string is truncated"
        (property (Text.isInfixOf "truncated" truncStr))
    , counterexample "string is not truncated when disabled"
        (property (not (Text.isInfixOf "truncated" fullStr)))
    ]

testBrowseModule :: IO Property
testBrowseModule = do
  output <- captureStdout (browseModule defaultReplOptions emptySession (Just "Std.Math"))
  pure $ conjoin
    [ counterexample "module header is present"
        (property (Text.isInfixOf "-- Module Std.Math --" output))
    , counterexample "functions section is present"
        (property (Text.isInfixOf "-- Functions --" output))
    , counterexample "min function signature is present"
        (property (Text.isInfixOf "min :: T -> T -> T" output))
    , counterexample "doc comment is present"
        (property (Text.isInfixOf "The smaller of two values" output))
    ]

testShowState :: IO Property
testShowState = do
  settingsRef <- newIORef defaultReplSettings
  sessionWithBind <- submitEntry emptySession "let x = 100"
  sessionWithFn <- submitEntry (resultSession sessionWithBind) "fn addOne(n: Int) -> Int { n + 1 }"
  sessionWithImport <- submitEntry (resultSession sessionWithFn) "import Std.Math {min}"
  let currentSession = resultSession sessionWithImport
  bindings <- showState settingsRef currentSession "bindings"
  declarations <- showState settingsRef currentSession "declarations"
  imports <- showState settingsRef currentSession "imports"
  settings <- showState settingsRef currentSession "settings"
  pure $ conjoin
    [ counterexample "show bindings contains only statement bindings"
        (bindings === ["bind    let x = 100"])
    , counterexample "show declarations contains declared functions"
        (declarations === ["fn addOne"])
    , counterexample "show imports contains imports"
        (imports === ["Std.Math"])
    , counterexample "show settings lists current flags"
        (property (any (Text.isInfixOf "+trunc") settings))
    ]
