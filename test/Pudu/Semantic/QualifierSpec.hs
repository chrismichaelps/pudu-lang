{-| @Test.Semantic.Qualifier — module namespaces never masquerade as runtime values -}
module Pudu.Semantic.QualifierSpec (qualifierProperties) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..), FrontendResult (..), runFrontend)
import Pudu.Compiler.Program (ProgramResult (..), compileProgram, programDependencies,
  programFolded, programIntegerKinds, rootCompileResult)
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticHelp,
  diagnosticMessage, diagnosticSpan)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntryFolded)
import Pudu.Eval.Render (renderValue)
import Pudu.Semantic (resolveModule)
import Pudu.Source (SourceName (..), newSource, spanEnd, spanStart, unOffset)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

qualifierProperties :: [(String, IO Property)]
qualifierProperties =
  [ ("module qualifier value positions preserve exact diagnostics", valuePositions)
  , ("module qualifier identity preserves shadows and reflection priority", identities)
  , ("module qualifier loaded exports preserve execution and recovery", loaded)
  ]

valuePositions :: IO Property
valuePositions = do
  found <- mapM checkCase
    [ ("", ""), ("let held = ", ""), ("return ", ""), ("", "()")
    , ("accept(", ")"), ("[", "]"), ("(", ", 1)"), ("#{", "}")
    , ("&", ""), ("", "[0]"), ("", "[Int]()"), ("Item { ", " }"), ("let held = fn() -> () { ", " }")
    ]
  bare <- lexical "module Probe\nimport Library\nfn run() -> () { Library }\n"
  pure $ conjoin (found <> [codes bare === ["E2010"]])
 where
  checkCase (before, after) = do
    let prefix = "module Probe\nimport Library as L\ntype Item = { value: Int }\nfn accept(x: Int) -> () {}\nfn run() -> () {\n  " <> before
        start = Text.length prefix
    findings <- lexical (prefix <> "L" <> after <> "\n}\n")
    pure $ counterexample (show (before, after, findings)) $
      map detail findings ===
        [("E2010", "L is a module namespace, not a value",
          Just "select an exported member with the qualifier, or import a named value", (start, start + 1))]

identities :: IO Property
identities = do
  found <- mapM (lexical . ("module Probe\n" <>))
    [ "import Library {inc}\nfn run(inc: Int) -> Int { inc }\n"
    , "import Library as L\nfn run[L]() -> () { L }\n"
    , "import Library as L\nimport Library as L\nfn run() -> () {}\n"
    , "import Library {inc}\nfn run() -> () { let held = inc }\n"
    , "import Std.Meta as L\nfn run() -> () { let held = L }\n"
    , "import Std.Meta as L\ntrait Tag { fn tag(self: &Self) -> Str }\nderive Tag for T: Record { fn tag(self: &T) -> Str { L } }\n"
    ]
  pure $ conjoin [codes actual === expected | (actual, expected) <- zip found
    [["W2001"], ["W2001", "E2010"], ["E2001", "E2001"], [], ["E2018"], ["E2010"]]]

loaded :: IO Property
loaded = withSystemTempDirectory "pudu-qualifier" $ \root -> do
  TextIO.writeFile (root </> "Library.pudu") $ Text.unlines
    [ "module Library", "export type Item = { value: Int }"
    , "export type Choice = Boxed(Int) | Empty", "export const TOKEN: Int = 41"
    , "export fn inc(value: Int) -> Int { value + 1 }", "fn hidden() -> Int { 0 }"
    , "export unsafe fn risky() -> Int { 0 }"
    ]
  found <- mapM (checkCase root)
    [ ("import Library as L", "let call = L.inc\n  call(L.TOKEN)", [], Just "42")
    , ("import Library", "Library.inc(Library.TOKEN)", [], Just "42")
    , ("import Library as L", "let item: L.Item = L.Item { value: 41 }\n  L.inc(item.value)", [], Just "42")
    , ("import Library {inc, TOKEN}", "let call = fn() -> Int { inc(TOKEN) }\n  call()", [], Just "42")
    , ("import Library {Choice, Boxed, Empty}", "let wrap = Boxed\n  match wrap(42) { case Choice.Boxed(value) => value case Choice.Empty => 0 }", [], Just "42")
    , ("import Library as L", "const L: Int = 42\n  L", ["W2001"], Just "42")
    , ("import Library as L", "{ const L: Int = 1 }\n  L.inc(41)", ["W2001"], Just "42")
    , ("import Library as L", "let held = L\n  0", ["E2010"], Nothing)
    , ("import Missing as L", "let held = L\n  0", ["E2014"], Nothing)
    , ("import Library {hidden}", "0", ["E2013"], Nothing)
    , ("import Library as L", "L.hidden()", ["E3033"], Nothing)
    , ("import Library as L\nimport Library as L", "0", ["E2001", "E2001"], Nothing)
    , ("import Library {risky}", "let call = risky\n  call()", ["E3023"], Nothing)
    ]
  pure (conjoin found)
 where
  checkCase root (imports, body, expected, value) = do
    let path = root </> "Probe.pudu"
    TextIO.writeFile path ("module Probe\n" <> imports <> "\nexport fn main() -> Int {\n  " <> body <> "\n}\n")
    program <- compileProgram path
    outcomes <- case (rootCompileResult program >>= compileModule, value) of
      (Just parsed, Just _) -> mapM (\folded -> do
        result <- evaluateProgramEntryFolded folded (programIntegerKinds program)
          (programDependencies program) "main" parsed
        pure (codes (outcomeDiagnostics result), renderValue <$> outcomeValue result))
        [Map.empty, programFolded program]
      _ -> pure []
    pure $ counterexample (show (imports, body, programDiagnostics program, outcomes)) $ conjoin
      [ codes (programDiagnostics program) === expected
      , outcomes === case value of Nothing -> []; Just result -> [([], Just result), ([], Just result)]
      ]

lexical :: Text -> IO [Diagnostic]
lexical text = do
  source <- newSource (SourceName "qualifier.pudu") text
  let frontend = runFrontend source
  pure $ case frontendModule frontend of
    Nothing -> frontendDiagnostics frontend
    Just parsed -> snd (resolveModule parsed)

codes :: [Diagnostic] -> [Text]
codes = map (diagnosticCodeText . diagnosticCode)

detail :: Diagnostic -> (Text, Text, Maybe Text, (Int, Int))
detail finding = (diagnosticCodeText (diagnosticCode finding), diagnosticMessage finding,
  diagnosticHelp finding, (unOffset (spanStart (diagnosticSpan finding)), unOffset (spanEnd (diagnosticSpan finding))))
