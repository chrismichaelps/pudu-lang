{-| @Test.Eval.Common — shared evaluation and compile-time test runners -}
module Pudu.Eval.Common
  ( codesOf
  , codesOfConstant
  , escapeForSource
  , evaluate
  , evaluateAsyncWith
  , evaluateStatements
  , evaluateWith
  , outcomeOf
  , outcomeOfWithEntry
  , renderCodes
  , runProgram
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateEntryPoint)
import Pudu.Eval.Render (renderValue)
import Pudu.Source (SourceName (SourceName), newSource)

evaluate :: Text -> IO Text
evaluate expression = evaluateWith [] expression

evaluateStatements :: [Text] -> IO Text
evaluateStatements statements = case reverse statements of
  final : leading -> runProgram [] (reverse leading) final
  [] -> pure "none"

evaluateWith :: [Text] -> Text -> IO Text
evaluateWith declarations expression = runProgram declarations [] expression

evaluateAsyncWith :: [Text] -> Text -> IO Text
evaluateAsyncWith declarations expression = do
  outcome <- outcomeOfWithEntry "async fn __entry() -> Result[Int, Str] {" declarations [] expression
  pure (maybe (renderCodes outcome) renderValue (outcomeValue outcome))

runProgram :: [Text] -> [Text] -> Text -> IO Text
runProgram declarations statements expression = do
  outcome <- outcomeOf declarations statements expression
  pure (maybe (renderCodes outcome) renderValue (outcomeValue outcome))

codesOf :: Text -> IO [Text]
codesOf expression = do
  outcome <- outcomeOf [] [] expression
  pure (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome))

outcomeOf :: [Text] -> [Text] -> Text -> IO EvalOutcome
outcomeOf declarations statements expression = do
  outcomeOfWithEntry "fn __entry() {" declarations statements expression

outcomeOfWithEntry :: Text -> [Text] -> [Text] -> Text -> IO EvalOutcome
outcomeOfWithEntry opening declarations statements expression = do
  let buffer =
        Text.unlines
          ( ["module Eval.Spec"]
              <> declarations
              <> [opening]
              <> statements
              <> [expression, "}"]
          )
  source <- newSource (SourceName "eval.pudu") buffer
  result <- runCompile source
  case compileModule result of
    Nothing ->
      pure
        EvalOutcome
          { outcomeValue = Nothing
          , outcomeDiagnostics = compileDiagnostics result
          }
    Just parsed -> evaluateEntryPoint (compileIntegerKinds result) "__entry" parsed

codesOfConstant :: Text -> IO [Text]
codesOfConstant expression = do
  source <-
    newSource (SourceName "constant.pudu")
      (Text.unlines ["module M", "const VALUE: Bool = " <> expression])
  result <- runCompile source
  pure (map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result))

escapeForSource :: FilePath -> String
escapeForSource = concatMap one
 where
  one character = case character of
    '\\' -> "\\\\"
    '"' -> "\\\""
    _ -> [character]

renderCodes :: EvalOutcome -> Text
renderCodes outcome =
  "failed: "
    <> Text.intercalate "," (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome))
