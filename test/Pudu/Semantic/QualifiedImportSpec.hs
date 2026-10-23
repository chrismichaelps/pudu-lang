{-| @Test.Semantic.QualifiedImport — only a selected import binds bare names -}
module Pudu.Semantic.QualifiedImportSpec (qualifiedImportProperties) where

import Control.Exception (finally)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (ProgramResult (..), compileProgram, programDependencies,
  programFolded, programIntegerKinds, rootCompileResult)
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntryFolded)
import Pudu.Eval.Render (renderValue)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

qualifiedImportProperties :: [(String, IO Property)]
qualifiedImportProperties =
  [ ("qualified imports keep prelude names in both evaluators", loaded)
  , ("qualified imports refuse bare exports and keep restrictions", refusals)
  ]

{-| Exports sharing the prelude's `show` and `display`, the second unsafe, beside
    a name the prelude does not have. -}
pages :: Text
pages = Text.unlines
  [ "module Lib.Pages"
  , "export fn show(markup: Str, times: Int) -> Str = markup"
  , "export fn render(markup: Str) -> Str = markup"
  , "export unsafe fn display(value: Int) -> Str = \"unsafe\""
  ]

withPages :: (FilePath -> IO a) -> IO a
withPages action = withSystemTempDirectory "pudu-qualified-import" $ \root -> do
  createDirectoryIfMissing True (root </> "Lib")
  TextIO.writeFile (root </> "Lib" </> "Pages.pudu") pages
  action root

loaded :: IO Property
loaded = withPages $ \root -> conjoin <$> mapM (runCase root)
  [ ("import Lib.Pages as Pages", "\"count \" + show(3) + \" \" + Pages.show(\"x\", 2)", "count 3 x")
  , ("import Lib.Pages as Pages", "show(3) + display(4) + Pages.render(\"r\")", "34r")
  , ("import Lib.Pages", "show(3) + Pages.show(\"y\", 1)", "3y")
  , ("import Lib.Pages {show}", "show(\"z\", 1)", "z")
  ]
 where
  runCase root (imports, body, value) = do
    let path = root </> "Probe.pudu"
    TextIO.writeFile path (programText imports body)
    program <- compileProgram path
    results <- case rootCompileResult program >>= compileModule of
      Nothing -> pure []
      Just parsed -> sequence
        [ inMode mode $ do
            result <- evaluateProgramEntryFolded folded (programIntegerKinds program)
              (programDependencies program) "main" parsed
            pure (codes (outcomeDiagnostics result), renderValue <$> outcomeValue result)
        | mode <- ["tree", "compiled"], folded <- [Map.empty, programFolded program]
        ]
    pure $ counterexample (show (imports, body, programDiagnostics program, results)) $ conjoin
      [ codes (programDiagnostics program) === []
      , results === replicate 4 ([], Just (Text.pack (show (value :: String))))
      ]

refusals :: IO Property
refusals = withPages $ \root -> conjoin <$> mapM (refused root)
  [ ("import Lib.Pages {show}", "show(3)", ["E3003", "E3001"])
  , ("import Lib.Pages as Pages", "render(\"r\")", ["E2010"])
  , ("import Lib.Pages", "render(\"r\")", ["E2010"])
  , ("import Lib.Pages as Pages", "Pages.display(1)", ["E3023"])
  ]
 where
  refused root (imports, body, expected) = do
    let path = root </> "Probe.pudu"
    TextIO.writeFile path (programText imports body)
    program <- compileProgram path
    pure $ counterexample (show (imports, body, programDiagnostics program)) $
      codes (programDiagnostics program) === expected

programText :: Text -> Text -> Text
programText imports body = "module Probe\n" <> imports <> "\nexport fn main() -> Str {\n  " <> body <> "\n}\n"

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous

codes :: [Diagnostic] -> [Text]
codes = map (diagnosticCodeText . diagnosticCode)
