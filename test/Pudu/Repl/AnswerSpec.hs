module Pudu.Repl.AnswerSpec (answerProperties) where

import Control.Exception (finally)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import Pudu.Repl.Answer (showType)
import Pudu.Repl.Options (defaultReplOptions)
import Pudu.Repl.Session (emptySession)
import System.Directory (getTemporaryDirectory, removeFile)
import System.IO (hClose, hFlush, openTempFile, stdout)
import Test.QuickCheck (Property, conjoin, counterexample, property)

answerProperties :: [(String, IO Property)]
answerProperties =
  [("type answers preserve warnings and source locations", testTypeAnswers)]

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
