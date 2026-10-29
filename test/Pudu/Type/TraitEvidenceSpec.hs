{-| @Test.Type.TraitEvidenceSpec — trait-resolved dispatch in both evaluators. -}
module Pudu.Type.TraitEvidenceSpec (traitEvidenceProperties) where

import Control.Exception (finally)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..), compileProgram, programDependencies, programIntegerKinds, rootCompileResult )
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticHelp, hasErrors)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

traitEvidenceProperties :: [(String, IO Property)]
traitEvidenceProperties =
  [ ("trait evidence admits two traits sharing a member for one type", admitted)
  , ("trait evidence runs a bound's own trait", boundDirected)
  , ("trait evidence runs a bound's trait whatever the declaration order", declarationOrder)
  , ("trait evidence runs a module-qualified trait", qualified)
  , ("trait evidence separates same-module traits and defaults", sameModule)
  , ("trait evidence reports an unqualified ambiguous call", ambiguous)
  , ("trait evidence binds generic implementations from the caller's witness", generic)
  , ("trait evidence types and runs static calls through parameters", static)
  , ("trait evidence follows derive closures through two encoders", derived)
  ]

admitted :: IO Property
admitted = run "imports alone" (encoders <> [main' encoderImports ["\"loaded\""]]) "\"loaded\""

boundDirected :: IO Property
boundDirected = run "bound-directed calls" (encoders <> [main' (encoderImports <>
  [ "fn firstOf[T: First.Encode](value: &T) -> Str { value.encode() }"
  , "fn secondOf[T: Second.Encode](value: &T) -> Int { value.encode() }"
  , "fn both[T: First.Encode + Second.Encode](value: &T) -> Str { firstOf(value) + show(secondOf(value)) }"
  ]) ["firstOf(&1) + \" \" + show(secondOf(&1)) + \" \" + both(&1)"]]) "\"first 2 first2\""

declarationOrder :: IO Property
declarationOrder = conjoin <$> sequence
  [ run ("local providers " <> show (owner, reversed)) [main'
      ( [ "type Box = { value: Int }"
        , "trait TextWire { fn encode(self: &Self) -> Str }"
        , "trait IntWire { fn encode(self: &Self) -> Int }"
        ]
        <> (if reversed then reverse implementations else implementations)
        <> ["fn generic[T: TextWire](value: &T) -> Str { value.encode() }"] )
      [ "let value: " <> owner <> " = " <> (if owner == "Int" then "1" else "Box{value: 1}")
      , "generic(&value) + show(IntWire.encode(&value))"
      ]] "\"text7\""
  | owner <- ["Int", "Box"], reversed <- [False, True]
  , let implementations =
          [ "impl TextWire for " <> owner <> " { fn encode(self: &Self) -> Str { \"text\" } }"
          , "impl IntWire for " <> owner <> " { fn encode(self: &Self) -> Int { 7 } }"
          ]
  ]

qualified :: IO Property
qualified = run "module-qualified calls" (encoders <> [main' (encoderImports <>
  [ "fn viaFirst[T: First.Encode](value: &T) -> Str { First.Encode.encode(value) }"
  , "fn viaSecond[T: Second.Encode](value: &T) -> Int { Second.Encode.encode(value) }"
  ]) ["First.Encode.encode(&1) + show(Second.Encode.encode(&1)) + viaFirst(&1) + show(viaSecond(&1))"]])
  "\"first2first2\""

sameModule :: IO Property
sameModule = run "same-module traits" [main'
  [ "trait Shown { fn render(self: &Self) -> Str }"
  , "trait Counted {"
  , "  fn render(self: &Self) -> Int"
  , "  fn twice(self: &Self) -> Int { self.render() * 2 }"
  , "}"
  , "impl Shown for Int { fn render(self: &Self) -> Str { \"shown\" } }"
  , "impl Counted for Int { fn render(self: &Self) -> Int { 7 } }"
  , "fn shown[T: Shown](value: &T) -> Str { value.render() }"
  , "fn counted[T: Counted](value: &T) -> Int { value.render() }"
  ] ["shown(&1) + show(counted(&1)) + Shown.render(&1) + show(Counted.render(&1)) + show(1.twice())"]]
  "\"shown7shown714\""

ambiguous :: IO Property
ambiguous = withProgram (encoders <> [main' encoderImports ["show(1.encode())"]]) $ \result -> do
  let errors = programDiagnostics result
  pure $ counterexample (show errors) $ conjoin
    [ map (diagnosticCodeText . diagnosticCode) errors === ["E3013"]
    , map diagnosticHelp errors
        === [Just "call it through its trait: First.Encode.encode(&value) or Second.Encode.encode(&value)"]
    ]

generic :: IO Property
generic = run "generic implementations" [main'
  [ "trait Named {"
  , "  fn label() -> Str"
  , "  fn describe(self: &Self) -> Str"
  , "}"
  , "impl Named for Int {"
  , "  fn label() -> Str { \"int\" }"
  , "  fn describe(self: &Self) -> Str { \"an int\" }"
  , "}"
  , "impl [A: Named] Named for Array[A] {"
  , "  fn label() -> Str { \"array of \" + A.label() }"
  , "  fn describe(self: &Self) -> Str { \"array of \" + A.label() }"
  , "}"
  , "trait Described { fn described(self: &Self) -> Str }"
  , "impl [A: Named] Described for Array[A] { fn described(self: &Self) -> Str { A.label() } }"
  , "fn go[T: Named](value: &T) -> Str { value.describe() }"
  , "fn outer[T: Named](value: &T) -> Str { go(value) }"
  , "fn unbounded[T: Described](value: &T) -> Str { value.described() }"
  ]
  [ "let empty: Array[Int] = []"
  , Text.intercalate " + \"|\" + "
      [ "go(&[1, 2])", "go(&empty)", "go(&[[1], [2, 3]])", "outer(&[[1]])", "unbounded(&[1])" ]
  ]]
  "\"array of int|array of int|array of array of int|array of array of int|int\""

static :: IO Property
static = do
  ran <- run "static calls" (makers <> [main' (makerImports <>
    [ "fn viaOne[T: One.Make]() -> T { T.make() }"
    , "fn viaTwo[T: Two.Make]() -> T { T.make() }"
    ]) ["show(viaOne[Int]() + viaTwo[Int]())"]]) "\"21\""
  refused <- withProgram
    (makers <> [main' (makerImports <> ["fn wrong[T: One.Make]() -> Str { T.make() }"]) ["wrong[Int]()"]])
    $ \result -> pure $ map (diagnosticCodeText . diagnosticCode) (programDiagnostics result) === ["E3001"]
  pure (conjoin [ran, counterexample "a static call is checked against its bound" refused])

derived :: IO Property
derived = run "derive closures" [wire, main'
  [ "import Std.Json as Json"
  , "import Wire"
  , "type Point = { x: Int, name: Str } derives Json.Encode, Wire.Encode"
  , "fn wired[T: Wire.Encode](value: &T) -> Int { value.encode() }"
  , "fn json[T: Json.Encode](value: &T) -> Str { Json.encode(&value.encode()) }"
  ] ["show(wired(&Point{x: 40, name: \"ab\"})) + json(&Point{x: 1, name: \"c\"}) + show(Wire.Encode.encode(&Point{x: 1, name: \"\"}))"]]
  "\"42{\\\"x\\\":1,\\\"name\\\":\\\"c\\\"}1\""

encoders :: [(Text, Text)]
encoders =
  [ ("First", "module First\nexport trait Encode {\n  fn encode(self: &Self) -> Str\n}\nimpl Encode for Int { fn encode(self: &Self) -> Str { \"first\" } }\n")
  , ("Second", "module Second\nexport trait Encode {\n  fn encode(self: &Self) -> Int\n}\nimpl Encode for Int { fn encode(self: &Self) -> Int { 2 } }\n")
  ]

encoderImports :: [Text]
encoderImports = ["import First", "import Second"]

makerImports :: [Text]
makerImports = ["import One", "import Two"]

makers :: [(Text, Text)]
makers =
  [ ("One", "module One\nexport trait Make {\n  fn make() -> Self\n}\nimpl Make for Int { fn make() -> Self { 1 } }\n")
  , ("Two", "module Two\nexport trait Make {\n  fn make() -> Self\n}\nimpl Make for Int { fn make() -> Self { 20 } }\n")
  ]

wire :: (Text, Text)
wire = ("Wire", Text.unlines
  [ "module Wire"
  , "import Std.Meta"
  , "export trait Encode {"
  , "  fn encode(self: &Self) -> Int"
  , "}"
  , "impl Encode for Int { fn encode(self: &Self) -> Int { *self } }"
  , "impl Encode for Str { fn encode(self: &Self) -> Int { self.length() } }"
  , "export derive Encode for T: Record {"
  , "  fn encode(self: &T) -> Int {"
  , "    var total = 0"
  , "    for part in Meta.collect[T](fn(member: Meta.Field[T, F]) -> Option[Int] where F: Encode {"
  , "        Some(member.get(self).encode())"
  , "      }) { total = total + part }"
  , "    total"
  , "  }"
  , "}"
  ])

{-| The root module: its imports and declarations, then `main`'s body. -}
main' :: [Text] -> [Text] -> (Text, Text)
main' declarations body = ("Main", Text.unlines
  (["module Main"] <> declarations <> ["fn main() -> Str {"] <> body <> ["}"]))

run :: String -> [(Text, Text)] -> Text -> IO Property
run label sources expected = withProgram sources $ \result -> do
  output <- outputs result
  pure $ counterexample (label <> ": " <> show (programDiagnostics result))
    (output === [Just expected, Just expected])

outputs :: ProgramResult -> IO [Maybe Text]
outputs result = case rootCompileResult result >>= compileModule of
  Just unit | not (hasErrors (programDiagnostics result)) -> mapM (\mode -> inMode mode $ do
    outcome <- evaluateProgramEntry (programIntegerKinds result) (programDependencies result) "main" unit
    pure (renderValue <$> outcomeValue outcome)) ["tree", "compiled"]
  _ -> pure [Nothing]

withProgram :: [(Text, Text)] -> (ProgramResult -> IO Property) -> IO Property
withProgram sources check = withSystemTempDirectory "pudu-trait-evidence" $ \root -> do
  mapM_ (\(name, body) -> TextIO.writeFile (root </> Text.unpack name <> ".pudu") body) sources
  compileProgram (root </> "Main.pudu") >>= check

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
