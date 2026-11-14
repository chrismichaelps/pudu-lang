{-| @Test.Eval.IfUnitSpec — no-else if results across evaluator paths. -}
module Pudu.Eval.IfUnitSpec (ifUnitProperties) where

import Control.Exception (bracket, finally)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.IO.Handle (hDuplicate, hDuplicateTo)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, hasErrors)
import Pudu.Eval (EvalOutcome (..), runWithEffects)
import Pudu.Eval.Env (lookupName, withFrame)
import Pudu.Eval.Frozen (thaw)
import Pudu.Eval.Loop.Kernel (pureLoop)
import Pudu.Eval.Program (evaluateEntryPoint)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..), intOf)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
  ( Block (..), Declaration (..), Expression (..), Function (..)
  , FunctionBody (..), Module (..) )
import Pudu.Source (SourceName (SourceName), newSource)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO (IOMode (WriteMode), hClose, hFlush, stdout, withFile)
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

ifUnitProperties :: [(String, IO Property)]
ifUnitProperties =
  [ ("if without else yields unit in tree and compiled evaluation", inBothModes testValues)
  , ("unit if values compose through locals calls and loops", inBothModes testComposition)
  , ("unit if preserves transfers and arithmetic failures", inBothModes testTransfers)
  , ("if with else retains its selected value", inBothModes testWithElse)
  , ("boxed pure loops commit unit if values", testBoxedKernel)
  , ("constant if without else folds to unit", testConstants)
  , ("no-else unit is checked against dynamic expectations", testDynamic)
  ]

inBothModes :: IO Property -> IO Property
inBothModes action = conjoin <$> mapM (\mode -> withMode mode action) ["tree", "compiled"]

withMode :: String -> IO a -> IO a
withMode mode action = bracket (lookupEnv "PUDU_EVAL") restore $ \_ -> do
  setEnv "PUDU_EVAL" mode
  action
 where
  restore = maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL")

testValues :: IO Property
testValues = conjoin <$> mapM check cases
 where
  cases =
    [ ("taken integer", "if true { 7 }", "")
    , ("skipped integer", "if false { 7 }", "")
    , ("taken Boolean", "if true { true }", "")
    , ("skipped Boolean", "if false { true }", "")
    , ("taken text", "if true { \"payload\" }", "")
    , ("skipped text", "if false { \"payload\" }", "")
    , ("taken print Result", "if true { print(\"taken\") }", "taken\n")
    , ("skipped print Result", "if false { print(\"skipped\") }", "")
    ]
  check (label, expression, output) = expect label [] [] expression "()" output []

testComposition :: IO Property
testComposition = conjoin <$> sequence
  [ expect "binding" [] ["let token = if true { 7 }"] "token" "()" "" []
  , expect "assignment" []
      ["var token = ()", "token = if true { 7 }"] "token" "()" "" []
  , expect "explicit return" ["fn choose() -> () { return if true { 7 } }"]
      [] "choose()" "()" "" []
  , expect "unit argument" ["fn take(token: ()) -> () { return token }"]
      [] "take(if true { 7 })" "()" "" []
  , expect "nested block" [] [] "{ if true { { 7 } } }" "()" "" []
  , expect "break operand" [] [] "loop { break if true { 7 } }" "()" "" []
  , expect "aggregate members" [] [] "(if true { 7 }, [if false { true }])" "((), [()])" "" []
  , expect "nested conditional" [] [] "if true { if true { 7 } }" "()" "" []
  , expect "if-let normal unit" [] [] "if let Some(value) = Some(7) { value }" "()" "" []
  , expect "condition once" []
      ["var count = 0", "let token = if { count = count + 1\n true } { print(\"taken\") }"]
      "(count, token)" "(1, ())" "taken\n" []
  , expect "branch mutation and unit result" []
      [ "var count = 0"
      , "let token = if true { count = count + 1\n 7 }"
      ] "(count, token)" "(1, ())" "" []
  ]

testTransfers :: IO Property
testTransfers = conjoin <$> sequence
  [ expect "return escapes branch" [] ["if true { return 17 }"] "0" "17" "" []
  , expect "break escapes branch" [] [] "loop { if true { break 19 } }" "19" "" []
  , expect "continue skips remainder" []
      [ "var count = 0", "var total = 0"
      , "while count < 3 {"
      , "  count = count + 1"
      , "  if count < 3 { continue }"
      , "  total = total + count"
      , "}"
      ] "total" "3" "" []
  , expect "taken arithmetic failure" [] [] "if true { 10 / 0 }" "none" "" ["E7004"]
  , expect "skipped arithmetic failure" [] [] "if false { 10 / 0 }" "()" "" []
  , expect "condition failure" [] [] "if 10 / 0 == 1 { 7 }" "none" "" ["E7004"]
  , expect "condition break escapes" [] []
      "loop { let token = if { break 23 } { 7 } }" "23" "" []
  ]

testWithElse :: IO Property
testWithElse = conjoin <$> sequence
  [ expect "integer branch" [] [] "if true { 7 } else { 9 }" "7" "" []
  , expect "Boolean branch" [] [] "if false { true } else { false }" "false" "" []
  , expect "text branch" [] [] "if true { \"yes\" } else { \"no\" }" "\"yes\"" "" []
  ]

expect :: String -> [Text] -> [Text] -> Text -> Text -> Text -> [Text] -> IO Property
expect label declarations statements expression expectedValue expectedOutput expectedCodes = do
  source <- newSource (SourceName "if-unit.pudu") $ Text.unlines
    (["module IfUnit"] <> declarations <> ["fn __entry() {"] <> statements <> [expression, "}"])
  compiled <- runCompile source
  case (hasErrors (compileDiagnostics compiled), compileModule compiled) of
    (False, Just parsed) -> do
      (outcome, output) <- captureStdout $
        evaluateEntryPoint (compileIntegerKinds compiled) "__entry" parsed
      pure $ counterexample label $ conjoin
        [ maybe "none" renderValue (outcomeValue outcome) === expectedValue
        , output === expectedOutput
        , map (diagnosticCodeText . diagnosticCode) (outcomeDiagnostics outcome) === expectedCodes
        ]
    _ -> pure $ counterexample (label <> ": compile failed: " <> show (compileDiagnostics compiled))
      (False === True)

captureStdout :: IO a -> IO (a, Text)
captureStdout action = withSystemTempDirectory "pudu-if-unit" $ \root -> do
  let path = root </> "stdout"
  result <- withFile path WriteMode $ \handle -> bracket (hDuplicate stdout) hClose $ \saved -> do
    hFlush stdout
    hDuplicateTo handle stdout
    action `finally` (hFlush stdout >> hDuplicateTo saved stdout)
  output <- TextIO.readFile path
  pure (result, output)

testBoxedKernel :: IO Property
testBoxedKernel = conjoin <$> mapM probe ["true", "false"]
 where
  probe flag = do
    source <- newSource (SourceName "if-unit-kernel.pudu") $ Text.unlines
      [ "module IfUnitKernel", "fn main() {", "  var index = 0", "  var token = ()"
      , "  while index < 1 {"
      , "    token = if " <> flag <> " { 7 }"
      , "    index = index + 1", "  }", "}"
      ]
    compiled <- runCompile source
    case (hasErrors (compileDiagnostics compiled), compileModule compiled) of
      (False, Just parsed)
        | [entry] <- [function | Located _ (FunctionDeclaration function) <- moduleDeclarations parsed]
        , Just (Located _ (BlockBody (Located _ Block{blockResult = Just
            (Located loopSpan (WhileExpression _ condition body))}))) <- functionBody entry -> do
            outcome <- runWithEffects True $ withFrame [("index", intOf 0), ("token", UnitValue)] $ do
              planned <- pureLoop loopSpan condition body
              case planned of
                Nothing -> pure (BoolValue False)
                Just code -> do
                  result <- code
                  token <- lookupName "token"
                  index <- lookupName "index"
                  pure (BoolValue (result == UnitValue && token == Just UnitValue && index == Just (intOf 1)))
            pure $ counterexample ("boxed kernel " <> Text.unpack flag) $ conjoin
              [ outcomeValue outcome === Just (BoolValue True)
              , outcomeDiagnostics outcome === []
              ]
      _ -> pure $ counterexample ("kernel fixture failed: " <> show (compileDiagnostics compiled))
        (False === True)

testConstants :: IO Property
testConstants = conjoin <$> mapM check
  [ "if true { 7 }", "if false { 7 }", "if true { true }", "if true { \"text\" }"
  , "{ var token = ()\n token = if true { 7 }\n token }"
  ]
 where
  check expression = do
    source <- newSource (SourceName "if-unit-constant.pudu") $ Text.unlines
      ["module IfUnitConstant", "const TOKEN: () = " <> expression]
    compiled <- runCompile source
    pure $ counterexample (Text.unpack expression <> ": " <> show (compileDiagnostics compiled)) $ conjoin
      [ hasErrors (compileDiagnostics compiled) === False
      , fmap thaw (Map.lookup "TOKEN" (compileFolded compiled)) === Just UnitValue
      ]


testDynamic :: IO Property
testDynamic = do
  outcomes <- mapM check
    [ ("dynamic Shape", "()")
    , ("dynamic Shape", "if true { Circle{radius: 1} }")
    , ("dynamic Shape", "if false { Circle{radius: 1} }")
    , ("Array[dynamic Shape]", "[if true { Circle{radius: 1} }]")
    , ("Held", "Held{shape: if true { Circle{radius: 1} }}")
    ]
  selected <- inBothModes $ expect "with-else dynamic" declarations
    ["let shape = choose(true)"] "shape.size()" "1" "" []
  pure (conjoin (selected : outcomes))
 where
  declarations =
    [ "trait Shape { fn size(self: &Self) -> Int }"
    , "type Circle = { radius: Int }"
    , "type Square = { side: Int }"
    , "type Held = { shape: dynamic Shape }"
    , "impl Shape for Circle { fn size(self: &Self) -> Int = self.radius }"
    , "impl Shape for Square { fn size(self: &Self) -> Int = self.side }"
    , "fn choose(flag: Bool) -> dynamic Shape { if flag { Circle{radius: 1} } else { Square{side: 2} } }"
    ]
  check (expected, expression) = do
    source <- newSource (SourceName "if-unit-dynamic.pudu") $ Text.unlines
      (["module IfUnitDynamic"] <> declarations <>
        ["fn reject() -> " <> expected <> " { " <> expression <> " }"])
    compiled <- runCompile source
    pure $ counterexample (Text.unpack expression <> ": " <> show (compileDiagnostics compiled)) $ conjoin
      [ hasErrors (compileDiagnostics compiled) === True
      , map (diagnosticCodeText . diagnosticCode) (compileDiagnostics compiled) === ["E3001"]
      ]
