module Pudu.Frontend.ExpandSpec (expandProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Eval (EvalOutcome (..), evaluateEntryPoint)
import Pudu.Eval.Value (renderValue)
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

expandProperties :: [(String, IO Property)]
expandProperties =
  [ ("macros expand before the phases that follow", testExpansion)
  , ("arguments are parsed, so precedence cannot surprise", testPrecedence)
  , ("parameter kinds are checked against the call", testKinds)
  , ("introduced bindings cannot capture or leak", testHygiene)
  , ("a call that cannot expand reports once", testFailures)
  ]

testExpansion :: IO Property
testExpansion = do
  expression <- evaluateWith
    [ "macro twice(value: expr) = value + value" ]
    "twice!(20)"
  identifier <- evaluateWith
    [ "macro pick(name: ident) = name"
    , "fn chosen() -> Int { 5 }"
    ]
    "pick!(chosen)()"
  block <- evaluateWith
    [ "macro run(body: block) = body" ]
    "run!({ let inner = 3\n inner * 2 })"
  nested <- evaluateWith
    [ "macro twice(value: expr) = value + value"
    , "macro quadruple(value: expr) = twice!(twice!(value))"
    ]
    "quadruple!(5)"
  pure $ conjoin
    [ counterexample "an expression argument expands" (expression === "40")
    , counterexample "an identifier argument expands" (identifier === "5")
    , counterexample "a block argument expands" (block === "6")
    , counterexample "a macro may call another" (nested === "20")
    ]

testPrecedence :: IO Property
testPrecedence = do
  outer <- evaluateWith ["macro twice(value: expr) = value + value"] "2 * twice!(3)"
  inner <- evaluateWith ["macro twice(value: expr) = value + value"] "twice!(1 + 2)"
  pure $ conjoin
    [ counterexample "the expansion is grouped where it was called" (outer === "12")
    , counterexample "an argument keeps its own grouping" (inner === "6")
    ]

testKinds :: IO Property
testKinds = do
  identifierGiven <- codes
    [ "module M"
    , "macro pick(name: ident) = name"
    , "fn run() -> Int { pick!(1 + 1) }"
    ]
  blockGiven <- codes
    [ "module M"
    , "macro run(body: block) = body"
    , "fn go() -> Int { run!(7) }"
    ]
  expressionAccepts <- codes
    [ "module M"
    , "macro any(value: expr) = value"
    , "fn go() -> Int { any!(1 + 1) }"
    ]
  unknownKind <- codes
    [ "module M"
    , "macro bad(value: thing) = value"
    ]
  pure $ conjoin
    [ counterexample "an expression is not an identifier" (identifierGiven === ["E1054"])
    , counterexample "an expression is not a block" (blockGiven === ["E1054"])
    , counterexample "an expression parameter takes anything" (expressionAccepts === [])
    , counterexample "the kind vocabulary is closed" (unknownKind === ["E1045"])
    ]

testHygiene :: IO Property
testHygiene = do
  captured <- evaluateStatements
    [ "macro shadowing(value: expr) = { let hidden = value\n hidden * 10 }"
    , "let hidden = 1"
    , "shadowing!(hidden)"
    ]
  leaked <- evaluateStatements
    [ "macro shadowing(value: expr) = { let hidden = value\n hidden * 10 }"
    , "let hidden = 1"
    , "shadowing!(hidden)"
    , "hidden"
    ]
  pure $ conjoin
    [ counterexample "the argument is not captured by the body's binding"
        (captured === "10")
    , counterexample "the body's binding does not leak to the caller" (leaked === "1")
    ]

testFailures :: IO Property
testFailures = do
  unknown <- codes ["module M", "fn run() -> Int { missing!(1) }"]
  arity <- codes
    [ "module M"
    , "macro twice(value: expr) = value + value"
    , "fn run() -> Int { twice!(1, 2) }"
    ]
  recursive <- codes
    [ "module M"
    , "macro loopy(value: expr) = loopy!(value)"
    , "fn run() -> Int { loopy!(1) }"
    ]
  pure $ conjoin
    [ counterexample "an unknown macro is reported" (unknown === ["E1047"])
    , counterexample "arity is exact" (arity === ["E1048"])
    , counterexample "expansion is bounded" (recursive === ["E1046"])
    ]

evaluateWith :: [Text] -> Text -> IO Text
evaluateWith declarations expression = runProgram declarations [] expression

evaluateStatements :: [Text] -> IO Text
evaluateStatements entries = case reverse entries of
  final : leading -> case span isDeclaration (reverse leading) of
    (declarations, statements) -> runProgram declarations statements final
  [] -> pure "none"
 where
  isDeclaration line = Text.isPrefixOf "macro " line

runProgram :: [Text] -> [Text] -> Text -> IO Text
runProgram declarations statements expression = do
  let buffer =
        Text.unlines
          ( ["module Expand.Spec"]
              <> declarations
              <> ["fn __entry() {"]
              <> statements
              <> [expression, "}"]
          )
  source <- newSource (SourceName "expand.pudu") buffer
  result <- runCompile source
  case compileModule result of
    Nothing -> pure ("failed: " <> Text.intercalate "," (codesOf result))
    Just parsed -> do
      outcome <- evaluateEntryPoint "__entry" parsed
      case outcomeValue outcome of
        Nothing -> pure "no value"
        Just value -> pure (renderValue value)

codes :: [Text] -> IO [Text]
codes inputLines = do
  source <- newSource (SourceName "expand.pudu") (Text.unlines inputLines)
  codesOf <$> runCompile source

codesOf :: CompileResult -> [Text]
codesOf result = map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result)
