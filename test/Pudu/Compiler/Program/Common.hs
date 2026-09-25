{-| @Test.Compiler.Program.Common — shared compilation and evaluation test runners -}
module Pudu.Compiler.Program.Common
  ( codes
  , helps
  , messages
  , moduleNames
  , runEntry
  , runEntryValue
  , runtimeCodes
  , runtimeDetails
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
  ( Diagnostic
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSpan
  )
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value)
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Source (spanEnd, spanStart, unOffset)

{-| Compiles a Pudu root program and evaluates its "main" function, returning the rendered value. -}
runEntry :: FilePath -> IO (Maybe Text)
runEntry path = fmap (fmap renderValue) (runEntryValue path)

{-| Compiles and evaluates a program while preserving the raw entry value for
    structural runtime assertions that have no source-visible rendering. -}
runEntryValue :: FilePath -> IO (Maybe Value)
runEntryValue path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure Nothing
    Just parsed -> do
      outcome <- evaluateProgramEntry
          (programIntegerKinds program)
          (programDependencies program)
          "main"
          parsed
      pure (outcomeValue outcome)

{-| Compiles and evaluates a program, extracting runtime diagnostic codes if aborted or static codes if failed. -}
runtimeCodes :: FilePath -> IO [Text]
runtimeCodes path = map (diagnosticCodeText . diagnosticCode) <$> runtimeDiagnostics path

{-| Compiles and evaluates a program, extracting runtime error message texts. -}
runtimeMessages :: FilePath -> IO [Text]
runtimeMessages path = map diagnosticMessage <$> runtimeDiagnostics path

{-| Compiles and evaluates a program, preserving the complete stable contract
    of each diagnostic: identity, wording, help, and source offsets. -}
runtimeDetails :: FilePath -> IO [(Text, Text, Maybe Text, (Int, Int))]
runtimeDetails path = map detail <$> runtimeDiagnostics path
 where
  detail finding =
    ( diagnosticCodeText (diagnosticCode finding)
    , diagnosticMessage finding
    , diagnosticHelp finding
    , let spanValue = diagnosticSpan finding
       in (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))
    )

runtimeDiagnostics :: FilePath -> IO [Diagnostic]
runtimeDiagnostics path = do
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (programDiagnostics program)
    Just parsed -> do
      outcome <-
        evaluateProgramEntry
          (programIntegerKinds program)
          (programDependencies program)
          "main"
          parsed
      pure (outcomeDiagnostics outcome)

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
