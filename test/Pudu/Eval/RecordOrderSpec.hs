{-| @Test.Eval.RecordOrderSpec — record values hold their declared field order. -}
module Pudu.Eval.RecordOrderSpec (recordOrderProperties) where

import Control.Exception (finally)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (compileProgram, programDependencies, programIntegerKinds, rootCompileResult)
import Pudu.Diagnostic (diagnosticMessage)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

recordOrderProperties :: [(String, IO Property)]
recordOrderProperties =
  [ ("records keep their declared field order whatever a literal writes", testDeclaredOrder) ]

testDeclaredOrder :: IO Property
testDeclaredOrder = conjoin <$> sequence
  [ both "a literal, a record variant and an update" shapes
      (Just "\"Point{x: 1, y: 2} true Box{w: 4, h: 3} true Point{x: 1, y: 7}\"", [])
  , both "fields still run in written order" failing (Nothing, ["division by zero"])
  , both "a record pattern reads a reordered record" matched (Just "43", [])
  , both "a record built inside a loop" looped (Just "\"Point{x: 3, y: 2}\"", [])
  ]
 where
  shapes =
    [ "type Point = { x: Int, y: Int }"
    , "type Shape = Dot | Box { w: Int, h: Int }"
    , "fn main() -> Str {"
    , "  let a = Point{y: 2, x: 1}"
    , "  let b = Box{h: 3, w: 4}"
    , "  let c = Point{..a, y: 7}"
    , "  show(a) + \" \" + display(a == Point{x: 1, y: 2}) + \" \" + show(b) + \" \""
    , "    + display(b == Box{w: 4, h: 3}) + \" \" + show(c)"
    , "}" ]
  failing =
    [ "type Point = { x: Int, y: Int }"
    , "fn zero() -> Int { 0 }"
    , "fn main() -> Int {"
    , "  let a = Point{y: 1 / zero(), x: [1][5]}"
    , "  a.x"
    , "}" ]
  matched =
    [ "type Shape = Dot | Box { w: Int, h: Int }"
    , "fn main() -> Int {"
    , "  match (Box{h: 3, w: 4}) {"
    , "    case Box{w, h} => w * 10 + h"
    , "    case Dot => 0"
    , "  }"
    , "}" ]

  looped =
    [ "type Point = { x: Int, y: Int }"
    , "fn make(n: Int) -> Point = Point{y: n, x: n + 1}"
    , "fn main() -> Str {"
    , "  var i = 0"
    , "  var last = Point{x: 0, y: 0}"
    , "  while i < 3 {"
    , "    last = make(i)"
    , "    i = i + 1"
    , "  }"
    , "  show(last)"
    , "}" ]

{-| The same program through the tree walker and with compiled bodies. -}
both :: String -> [Text] -> (Maybe Text, [Text]) -> IO Property
both label body expected = do
  tree <- inMode "tree" (outcome body)
  compiled <- inMode "compiled" (outcome body)
  pure $ conjoin
    [ counterexample (label <> " (tree)") (tree === expected)
    , counterexample (label <> " (compiled)") (compiled === expected) ]

outcome :: [Text] -> IO (Maybe Text, [Text])
outcome body = withSystemTempDirectory "pudu-record-order" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path (Text.unlines ("module Main" : "" : body))
  program <- compileProgram path
  case rootCompileResult program >>= compileModule of
    Nothing -> pure (Nothing, ["did not compile"])
    Just parsed -> do
      result <- evaluateProgramEntry (programIntegerKinds program) (programDependencies program) "main" parsed
      pure (renderValue <$> outcomeValue result, map diagnosticMessage (outcomeDiagnostics result))

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
