{-| @Test.Compiler.Program.Common — shared compilation and evaluation test runners -}
module Pudu.Compiler.Program.Common
  ( codes
  , helps
  , messages
  , moduleNames
  , runEntry
  , runtimeCodes
  , runtimeMessages
  ) where

import Data.Text (Text)
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..)
  , compileProgram
  , programDependencies
  , programIntegerKinds
  , rootCompileResult
  )
import Pudu.Diagnostic
  ( diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  )
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Frontend.Syntax.Name (moduleNameText)

{-| Compiles a Pudu root program and evaluates its "main" function, returning the rendered value. -}
runEntry :: FilePath -> IO (Maybe Text)
runEntry path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure Nothing
    Just parsed -> do
      outcome <- evaluateProgramEntry
          (programIntegerKinds program)
          (programDependencies program)
          "main"
          parsed
      pure (fmap renderValue (outcomeValue outcome))

{-| Compiles and evaluates a program, extracting runtime diagnostic codes if aborted or static codes if failed. -}
runtimeCodes :: FilePath -> IO [Text]
runtimeCodes path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (map (diagnosticCodeText . diagnosticCode) (programDiagnostics program))
    Just parsed -> do
      outcome <- evaluateProgramEntry
          (programIntegerKinds program)
          (programDependencies program)
          "main"
          parsed
      pure (map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome))

{-| Compiles and evaluates a program, extracting runtime error message texts. -}
runtimeMessages :: FilePath -> IO [Text]
runtimeMessages path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (map diagnosticMessage (programDiagnostics program))
    Just parsed -> do
      outcome <-
        evaluateProgramEntry
          (programIntegerKinds program)
          (programDependencies program)
          "main"
          parsed
      pure (map diagnosticMessage (outcomeDiagnostics outcome))

{-| Derives the topologically sorted module names in the program dependency graph. -}
moduleNames :: FilePath -> IO [Text]
moduleNames path = do
  result <- compileProgram path
  pure (map moduleNameText (programOrder result))

{-| Returns static compilation diagnostic messages for a program. -}
messages :: FilePath -> IO [Text]
messages path = do
  result <- compileProgram path
  pure (map diagnosticMessage (programDiagnostics result))

{-| Returns static compilation diagnostic help hints for a program. -}
helps :: FilePath -> IO [Text]
helps path = do
  result <- compileProgram path
  pure [help | Just help <- map diagnosticHelp (programDiagnostics result)]

{-| Returns static compilation diagnostic codes for a program. -}
codes :: FilePath -> IO [Text]
codes path = do
  result <- compileProgram path
  pure (map (diagnosticCodeText . diagnosticCode) (programDiagnostics result))
