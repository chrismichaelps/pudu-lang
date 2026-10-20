{-| @Test.Eval.FloatOrderSpec — NaN keeps compareValues a total order. -}
module Pudu.Eval.FloatOrderSpec (floatOrderProperties) where

import Control.Exception (finally)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (compileProgram, programDependencies, programIntegerKinds, rootCompileResult)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Eval.Value (Value (..), compareValues, intOf)
import Pudu.FloatLiteral (FloatWidth (..))
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

floatOrderProperties :: [(String, IO Property)]
floatOrderProperties =
  [ ("NaN equals NaN and sorts after every number in the value order", testOrder) ]

testOrder :: IO Property
testOrder = do
  tree <- inMode "tree" program
  compiled <- inMode "compiled" program
  pure $ conjoin
    [ counterexample "NaN against NaN" (compareValues nan nan === EQ)
    , counterexample "NaN after a number" (compareValues nan one === GT)
    , counterexample "a number before NaN" (compareValues one nan === LT)
    , counterexample "an Int before NaN" (compareValues (intOf 5) nan === LT)
    , counterexample "signed zeros stay equal" (compareValues (float (-0.0)) (float 0.0) === EQ)
    , counterexample "tree walker" (tree === Just expected)
    , counterexample "compiled bodies" (compiled === Just expected)
    ]
 where
  float = FloatValue Float64Width
  nan = float (0 / 0)
  one = float 1
  expected = "\"false true false false true {(1.0, 1): \\\"b\\\", (NaN, 1): \\\"c\\\"} false false\""
  program = withSystemTempDirectory "pudu-float-order" $ \root -> do
    let path = root </> "Main.pudu"
    TextIO.writeFile path (Text.unlines source)
    compiled <- compileProgram path
    case rootCompileResult compiled >>= compileModule of
      Nothing -> pure Nothing
      Just parsed -> do
        result <- evaluateProgramEntry (programIntegerKinds compiled) (programDependencies compiled) "main" parsed
        pure (renderValue <$> outcomeValue result)
  source :: [Text]
  source =
    [ "module Main"
    , "fn main() -> Str {"
    , "  let n = 0.0 / 0.0"
    , "  let parts = [display((n, 1) < (1.0, 1)), display((1.0, 1) < (n, 1)), display((n, 1) < (n, 1))"
    , "    , display((n, 1) > (n, 1)), display((n, 1) >= (n, 1))"
    , "    , show(mapOf([((n, 1), \"a\"), ((1.0, 1), \"b\"), ((n, 1), \"c\")]))"
    , "    , display(n < 1.0), display(n == n)]"
    , "  parts.join(\" \")"
    , "}" ]

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
