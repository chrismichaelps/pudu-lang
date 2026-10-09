{-| @Test.Semantic.QualifiedShadow — lexical values precede namespace members -}
module Pudu.Semantic.QualifiedShadowSpec (qualifiedShadowProperties) where

import Control.Exception (finally)
import qualified Data.Map.Strict as Map
import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..), FrontendResult (..), runFrontend)
import Pudu.Compiler.Cache (collectedEntries, openCollectingCache)
import Pudu.Compiler.Program (ProgramResult (..), compileProgram, compileProgramCached, programDependencies,
  programFolded, programIntegerKinds, rootCompileResult)
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticHelp,
  diagnosticMessage, diagnosticSpan)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntryFolded)
import Pudu.Eval.Render (renderValue)
import Pudu.Semantic (resolveModule)
import Pudu.Source (SourceName (..), newSource, spanEnd, spanStart, unOffset)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

qualifiedShadowProperties :: [(String, IO Property)]
qualifiedShadowProperties =
  [ ("qualified shadows preserve loaded values modes and lexical restoration", loaded)
  , ("qualified shadows preserve exact refusals and isolated scope", refusals)
  ]

library :: Text
library = Text.unlines
  [ "module Library", "export type Row = { answer: Int }", "export type Nest = { row: Row }"
  , "export type Choice = Boxed(Int) | Empty", "export const TOKEN: Int = 999"
  , "export fn answer() -> Int = 999", "export fn length() -> Int = 999"
  , "export fn toTitle(value: Str) -> Str = value", "export fn choose[A](value: A) -> A = value"
  , "export trait Measure { fn length(self: &Self) -> Int }"
  , "impl Measure for Row { fn length(self: &Self) -> Int = self.answer }"
  , "export unsafe fn risky() -> Int = 999"
  ]

withLibrary :: (FilePath -> IO a) -> IO a
withLibrary action = withSystemTempDirectory "pudu-qualified-shadow" $ \root -> do
  TextIO.writeFile (root </> "Library.pudu") library
  action root

loaded :: IO Property
loaded = withLibrary $ \root -> do
  answers <- mapM (checkCase root)
    [ ("import Library as L", "", "const L: Array[Int] = [1, 2]\n  L.length()", ["W2001"], "2")
    , ("import Library as L", "", "const L: Array[Int] = [1, 2]\n  let call = L.length\n  call()", ["W2001"], "2")
    , ("import Library as L", "", "const L: Array[Int] = [1, 2]\n  let call = fn() -> Int { L.length() }\n  call()", ["W2001"], "2")
    , ("import Library as L", "", "let call = { const L: Array[Int] = [1, 2]\n  fn() -> Int { L.length() } }\n  call()", ["W2001"], "2")
    , ("import Library as L", "", "let first = { const L: Array[Int] = [1, 2]\n  L.length() }\n  first + L.length()", ["W2001"], "1001")
    , ("import Library as L", "", "let first = { const L: Array[Int] = [1, 2]\n  L.length() }\n  let second = { const L: Array[Int] = [1, 2, 3]\n  L.length() }\n  first + second", ["W2001", "W2001"], "5")
    , ("import Library as L", "", "const L: L.Row = L.Row { answer: 42 }\n  L.answer", ["W2001"], "42")
    , ("import Library as L", "", "const L: L.Row = L.Row { answer: 42 }\n  L.length()", ["W2001"], "42")
    , ("import Library as L", "", "const L: L.Nest = L.Nest { row: L.Row { answer: 42 } }\n  L.row.answer", ["W2001"], "42")
    , ("import Library as L", "", "const L: Int = 1\n  let row: L.Row = L.Row { answer: 42 }\n  row.answer", ["W2001"], "42")
    , ("import Library as L", "", "const L: Int = L.length()\n  L", ["W2001"], "999")
    , ("import Library as Boxed", "", "Boxed.length()", [], "999")
    , ("import Library as L", "", "let wrap = L.Boxed\n  match wrap(42) { case L.Choice.Boxed(value) => value case L.Choice.Empty => 0 }", [], "42")
    , ("import Library as L", "", "let call = L.choose\n  call(42)", [], "42")
    , ("import Library as L", "", "L.choose[Int](42)", [], "42")
    , ("import Library as L", "", "L.TOKEN", [], "999")
    , ("import Library as L", "comptime fn local() -> Int { const L: Array[Int] = [1, 2]\n  L.length() }\nconst ANSWER: Int = local()\n", "ANSWER", ["W2001"], "2")
    , ("", "trait T { fn length(self: &Self) -> Int }\nimpl T for Int { fn length(self: &Self) -> Int = 999 }\n", "const T: Array[Int] = [1, 2]\n  T.length()", [], "2")
    ]
  pure (conjoin answers)
 where
  checkCase root (imports, declarations, body, expected, value) = do
    let path = root </> "Probe.pudu"
    TextIO.writeFile path (programText imports declarations body)
    analysis <- compileProgram path
    cache <- openCollectingCache Map.empty
    cold <- compileProgramCached cache path
    entries <- collectedEntries cache
    warmed <- openCollectingCache entries
    warm <- compileProgramCached warmed path
    results <- case rootCompileResult warm >>= compileModule of
      Nothing -> pure []
      Just parsed -> sequence
        [ inMode mode $ do
            result <- evaluateProgramEntryFolded folded (programIntegerKinds warm)
              (programDependencies warm) "main" parsed
            pure (codes (outcomeDiagnostics result), renderValue <$> outcomeValue result)
        | mode <- ["tree", "compiled"], folded <- [Map.empty, programFolded warm]
        ]
    pure $ counterexample (show (body, programDiagnostics cold, programDiagnostics warm, results)) $ conjoin
      [ codes (programDiagnostics analysis) === expected
      , codes (programDiagnostics cold) === expected, codes (programDiagnostics warm) === expected
      , Map.null entries === False
      , results === replicate 4 ([], Just value)
      ]

refusals :: IO Property
refusals = withLibrary $ \root -> do
  let prefix = programText "import Library as L" "" "const L: Int = 1\n  "
      start = Text.length prefix - 3
  found <- mapM (\(body, expected) -> do
    let written = programText "import Library as L" "" ("const L: Int = 1\n  " <> body <> "\n  0")
        path = root </> "Probe.pudu"
    TextIO.writeFile path written
    program <- compileProgram path
    pure $ counterexample (show (body, programDiagnostics program)) $
      sort (codes (programDiagnostics program)) === sort ("W2001" : expected))
    [("L.toTitle(\"pudu\")", ["E3005"]), ("let call = L.toTitle", ["E3005"])
    , ("let held = L.TOKEN", ["E3005"]), ("let wrap = L.Boxed", ["E3005"])
    , ("L.risky()", ["E3005"])
    , ("L.choose[Int](42)", ["E3005", "E3028"])]
  controls <- mapM (\(declarations, body, expected) -> do
    let path = root </> "Probe.pudu"
    TextIO.writeFile path (programText "import Library as L" declarations body)
    program <- compileProgram path
    pure $ counterexample (show (declarations, body, programDiagnostics program)) $
      codes (programDiagnostics program) === expected)
    [ ("", "L.risky()", ["E3023"])
    , ("comptime fn blocked() -> Int = L.length()\n", "0", ["E3025"])
    , ("trait T { fn length(self: &Self) -> Int }\nimpl T for Int { fn length(self: &Self) -> Int = 999 }\n",
        "const T: Array[Int] = [1, 2]\n  T.length(1)", ["E3003"])
    ]
  let path = root </> "Probe.pudu"
      written = programText "import Library as L" "" "const L: Int = 1\n  L.toTitle(\"pudu\")\n  0"
  TextIO.writeFile path written
  program <- compileProgram path
  source <- newSource (SourceName "shadow.pudu") written
  let frontend = runFrontend source
      lexical = maybe (frontendDiagnostics frontend) (snd . resolveModule) (frontendModule frontend)
      errors = filter ((== "E3005") . diagnosticCodeText . diagnosticCode) (programDiagnostics program)
  pure $ conjoin (found <> controls <>
    [ codes lexical === ["W2001"]
    , map detail errors === [("Int has no field or method toTitle",
        Just "check the name against the type declaration and its implementations", (start, start + 9))]
    ])

programText :: Text -> Text -> Text -> Text
programText imports declarations body = "module Probe\n" <> imports <> "\n" <> declarations <>
  "export fn main() -> Int {\n  " <> body <> "\n}\n"

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous

codes :: [Diagnostic] -> [Text]
codes = map (diagnosticCodeText . diagnosticCode)

detail :: Diagnostic -> (Text, Maybe Text, (Int, Int))
detail finding = (diagnosticMessage finding, diagnosticHelp finding,
  (unOffset (spanStart (diagnosticSpan finding)), unOffset (spanEnd (diagnosticSpan finding))))
