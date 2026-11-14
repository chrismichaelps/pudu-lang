{-| @Test.Eval.EntryAritySpec — an entry that takes parameters is a diagnostic, not a crash. -}
module Pudu.Eval.EntryAritySpec (entryArityProperties) where

import Control.Exception (ErrorCall, evaluate, try)
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (compileProgram, programDependencies, programIntegerKinds, rootCompileResult)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticMessage, diagnosticSpan)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Source (spanStart, unOffset)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, counterexample, (===))

entryArityProperties :: [(String, IO Property)]
entryArityProperties =
  [ ("an entry that takes parameters refuses at its name", testEntryArity) ]

testEntryArity :: IO Property
testEntryArity = withSystemTempDirectory "pudu-entry-arity" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path "module Main\n\nfn main(value: Int) -> Int {\n  value\n}\n"
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (counterexample "the program did not compile" False)
    Just parsed -> do
      outcome <- try (run program parsed)
      pure $ case outcome of
        Left failure -> counterexample ("evaluation threw: " <> show (failure :: ErrorCall)) False
        -- `main` starts at offset 16, line 3 column 4.
        Right diagnostics -> diagnostics === [("E7003", "missing argument for parameter value", 16)]
 where
  run program parsed = do
    result <- evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" parsed
    _ <- evaluate (length (show (outcomeDiagnostics result)))
    pure [ ( diagnosticCodeText (diagnosticCode found), diagnosticMessage found
           , unOffset (spanStart (diagnosticSpan found)) )
         | found <- outcomeDiagnostics result ]
