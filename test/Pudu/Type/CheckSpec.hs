module Pudu.Type.CheckSpec (typeProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Source (SourceName (SourceName), newSource)
import Pudu.Type (renderType, widestWithin)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

typeProperties :: [(String, IO Property)]
typeProperties =
  [ ("literals and operators take their declared types", testOperators)
  , ("annotations are checked against their value", testAnnotations)
  , ("calls check argument types and count", testCalls)
  , ("generic functions instantiate per use", testGenerics)
  , ("records check fields on construction and access", testRecords)
  , ("sum constructors and patterns type their payloads", testVariants)
  , ("control flow unifies its branches", testControlFlow)
  , ("exported signatures must be annotated", testExportedSignatures)
  , ("a type error reports once and does not cascade", testNoCascade)
  , ("an earlier phase's error suppresses type checking", testPhaseOrder)
  , ("expression types are recorded for tooling", testRecordedTypes)
  ]

testOperators :: IO Property
testOperators = do
  arithmetic <- typeOf "1 + 2 * 3"
  comparison <- typeOf "1 < 2"
  logic <- typeOf "true && false"
  text <- typeOf "\"a\" + \"b\""
  float <- typeOf "1.5 * 2.0"
  mixed <- codesOfExpression "1 + true"
  logicMismatch <- codesOfExpression "1 && true"
  pure $ conjoin
    [ arithmetic === "Int"
    , comparison === "Bool"
    , logic === "Bool"
    , text === "Str"
    , float === "Float64"
    , counterexample "mixed operands are rejected" (mixed === ["E3001"])
    , counterexample "a boolean operator requires Bool" (logicMismatch === ["E3001"])
    ]

testAnnotations :: IO Property
testAnnotations = do
  matching <- codes ["module M", "const VALUE: Int = 1"]
  mismatched <- codes ["module M", "const VALUE: Str = 1"]
  inferred <- typeOfIn ["fn run() -> Int {", "  let value = 2", "  value", "}"] "value"
  pure $ conjoin
    [ matching === []
    , mismatched === ["E3001"]
    , counterexample "an unannotated local takes its initializer's type" (inferred === "Int")
    ]

testCalls :: IO Property
testCalls = do
  correct <- codes ["module M", "fn twice(n: Int) -> Int { n * 2 }", "fn run() -> Int { twice(3) }"]
  wrongType <- codes ["module M", "fn twice(n: Int) -> Int { n * 2 }", "fn run() -> Int { twice(\"x\") }"]
  tooMany <- codes ["module M", "fn twice(n: Int) -> Int { n * 2 }", "fn run() -> Int { twice(1, 2) }"]
  defaulted <- codes
    [ "module M"
    , "fn scale(n: Int, factor: Int = 2) -> Int { n * factor }"
    , "fn run() -> Int { scale(3) }"
    ]
  notCallable <- codes ["module M", "const VALUE: Int = 1", "fn run() -> Int { VALUE(1) }"]
  pure $ conjoin
    [ correct === []
    , wrongType === ["E3001"]
    , tooMany === ["E3003"]
    , counterexample "a default covers a missing argument" (defaulted === [])
    , counterexample "a non-function is not callable" (notCallable === ["E3004"])
    ]

testGenerics :: IO Property
testGenerics = do
  reused <- codes
    [ "module M"
    , "fn identity[T](value: T) -> T { value }"
    , "fn run() -> Int { identity(1) }"
    , "fn text() -> Str { identity(\"a\") }"
    ]
  mismatched <- codes
    [ "module M"
    , "fn identity[T](value: T) -> T { value }"
    , "fn run() -> Str { identity(1) }"
    ]
  pure $ conjoin
    [ counterexample "one generic serves several types" (reused === [])
    , counterexample "instantiation still checks the result" (mismatched === ["E3001"])
    ]

testRecords :: IO Property
testRecords = do
  built <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: 1, name: \"a\"} }"
    ]
  wrongField <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: \"a\", name: \"a\"} }"
    ]
  missingField <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: 1} }"
    ]
  unknownField <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run() -> User { User{id: 1, name: \"a\", extra: 2} }"
    ]
  access <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run(user: User) -> Str { user.name }"
    ]
  unknownAccess <- codes
    [ "module M"
    , "type User = { id: Int, name: Str }"
    , "fn run(user: User) -> Str { user.missing }"
    ]
  pure $ conjoin
    [ built === []
    , wrongField === ["E3001"]
    , missingField === ["E3008"]
    , unknownField === ["E3005"]
    , access === []
    , unknownAccess === ["E3005"]
    ]

testVariants :: IO Property
testVariants = do
  constructed <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run() -> Outcome { Ok(1) }"
    ]
  wrongPayload <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run() -> Outcome { Ok(\"a\") }"
    ]
  matched <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run(value: Outcome) -> Int {"
    , "  match value {"
    , "    case Ok(inner) => inner"
    , "    case Err(_) => 0"
    , "  }"
    , "}"
    ]
  wrongArm <- codes
    [ "module M"
    , "type Outcome = | Ok(Int) | Err(Str)"
    , "fn run(value: Outcome) -> Int {"
    , "  match value {"
    , "    case Ok(inner) => inner"
    , "    case Err(reason) => reason"
    , "  }"
    , "}"
    ]
  pure $ conjoin
    [ constructed === []
    , wrongPayload === ["E3001"]
    , matched === []
    , counterexample "arms unify to one type" (wrongArm === ["E3001"])
    ]

testControlFlow :: IO Property
testControlFlow = do
  branches <- codes ["module M", "fn run(flag: Bool) -> Int { if flag { 1 } else { 2 } }"]
  mixedBranches <- codes ["module M", "fn run(flag: Bool) -> Int { if flag { 1 } else { \"two\" } }"]
  condition <- codes ["module M", "fn run() -> Int { if 1 { 1 } else { 2 } }"]
  loops <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  var total = 0"
    , "  while total < 3 {"
    , "    total = total + 1"
    , "  }"
    , "  total"
    , "}"
    ]
  returned <- codes
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  if flag {"
    , "    return \"text\""
    , "  }"
    , "  1"
    , "}"
    ]
  pure $ conjoin
    [ branches === []
    , mixedBranches === ["E3001"]
    , counterexample "a condition must be Bool" (condition === ["E3001"])
    , loops === []
    , counterexample "return is checked against the declared result"
        (returned === ["E3001"])
    ]

testExportedSignatures :: IO Property
testExportedSignatures = do
  annotated <- codes ["module M", "export fn run(value: Int) -> Int { value }"]
  missingReturn <- codes ["module M", "export fn run(value: Int) { value }"]
  missingParameter <- codes ["module M", "export fn run(value) -> Int { value }"]
  privateInferred <- codes ["module M", "fn run(value) { value }"]
  pure $ conjoin
    [ annotated === []
    , missingReturn === ["E3010"]
    , missingParameter === ["E3010"]
    , counterexample "a private function may infer" (privateInferred === [])
    ]

testNoCascade :: IO Property
testNoCascade = do
  result <- codes
    [ "module M"
    , "fn run() -> Int {"
    , "  let wrong: Int = \"text\""
    , "  wrong + wrong + wrong"
    , "}"
    ]
  pure (counterexample "one mistake is reported once" (result === ["E3001"]))

testPhaseOrder :: IO Property
testPhaseOrder = do
  result <- codes ["module M", "fn run() -> Int { missing + 1 }"]
  pure
    ( counterexample "an unresolved name is not also a type error"
        (result === ["E2010"])
    )

testRecordedTypes :: IO Property
testRecordedTypes = do
  recorded <- typeOfIn ["fn run() -> Bool {", "  1 < 2", "}"] "1 < 2"
  pure (recorded === "Bool")

typeOf :: Text -> IO Text
typeOf expression = typeOfIn ["fn run() {", "  " <> expression, "}"] expression

{-| Compile a module and report the type of the widest expression inside the
    region the given text occupies. -}
typeOfIn :: [Text] -> Text -> IO Text
typeOfIn body needle = do
  let source = Text.unlines (["module M"] <> body)
  result <- compile source
  case compileTypes result of
    Nothing -> pure ("no types: " <> Text.intercalate "," (codesOf result))
    Just info -> case region source needle of
      Nothing -> pure "not found"
      Just (start, end) -> case widestWithin start end info of
        Nothing -> pure "no type"
        Just found -> pure (renderType found)

{-| Locate the last occurrence of the text, which is the one in expression
    position when a name is first declared and then used. -}
region :: Text -> Text -> Maybe (Int, Int)
region source needle = case Text.breakOnEnd needle source of
  (before, _)
    | Text.null before -> Nothing
    | otherwise -> Just (Text.length before - Text.length needle, Text.length before)

codes :: [Text] -> IO [Text]
codes inputLines = do
  result <- compile (Text.unlines inputLines)
  pure (codesOf result)

codesOfExpression :: Text -> IO [Text]
codesOfExpression expression =
  codes ["module M", "fn run() {", "  " <> expression, "}"]

codesOf :: CompileResult -> [Text]
codesOf result = map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result)

compile :: Text -> IO CompileResult
compile source = do
  snapshot <- newSource (SourceName "type.pudu") source
  pure (runCompile snapshot)
