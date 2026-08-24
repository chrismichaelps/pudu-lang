module Pudu.Type.CheckSpec (typeProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic
  ( diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSpan
  )
import Pudu.Source (SourceName (SourceName), newSource, spanStart, unOffset)
import Pudu.Type (renderType, widestWithin)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

typeProperties :: [(String, IO Property)]
typeProperties =
  [ ("literals and operators take their declared types", testOperators)
  , ("integer literals select every width and enforce exact bounds", testIntegerLiterals)
  , ("floating suffixes select honest precision and reject overflow", testFloatLiterals)
  , ("annotations are checked against their value", testAnnotations)
  , ("calls check argument types and count", testCalls)
  , ("generic functions instantiate per use", testGenerics)
  , ("records check fields on construction and access", testRecords)
  , ("sum constructors and patterns type their payloads", testVariants)
  , ("control flow unifies its branches", testControlFlow)
  , ("exported signatures must be annotated", testExportedSignatures)
  , ("a type error reports once and does not cascade", testNoCascade)
  , ("an earlier phase's error suppresses type checking", testPhaseOrder)
  , ("wired-in Option and Result carry their constructors", testPreludeData)
  , ("? unwraps a Result inside a Result-returning function", testTry)
  , ("async calls normalize task channels and await them", testAsync)
  , ("trait methods dispatch on the receiver type", testTraits)
  , ("trait default bodies call other trait methods on Self", testTraitDefaultCalls)
  , ("matches are checked for coverage and reachability", testExhaustiveness)
  , ("trait bounds are proved at the call site", testBounds)
  , ("ambiguous trait method dispatch reports E3013", testAmbiguousMethod)
  , ("duplicate trait implementation heads are rejected", testCoherence)
  , ("Float aliases to Float64 at the type level", testFloatAlias)
  , ("references are dereferenced explicitly in both directions", testDereference)
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

testIntegerLiterals :: IO Property
testIntegerLiterals = do
  contextual <- traverse acceptsIntegerType integerTypes
  suffixTypes <- traverse typeOf integerSuffixes
  defaulted <- typeOf "1"
  selected <- typeOfIn ["fn run() -> Int8 { 1 }"] "1"
  based <- typeOf "0xffu8"
  signedHigh <- codes ["module M", "fn run() -> Int8 { 127i8 }"]
  signedLow <- codes ["module M", "fn run() -> Int8 { -128i8 }"]
  signedOverflow <- codes ["module M", "fn run() -> Int8 { 128i8 }"]
  signedUnderflow <- codes ["module M", "fn run() -> Int8 { -129i8 }"]
  unsignedHigh <- codes ["module M", "fn run() -> UInt8 { 255u8 }"]
  unsignedOverflow <- codes ["module M", "fn run() -> UInt8 { 256u8 }"]
  unsignedNegative <- codes ["module M", "fn run() -> UInt8 { -1u8 }"]
  contextualOverflow <- codes ["module M", "fn run() -> UInt8 { 256 }"]
  hugeBigInt <- codes
    [ "module M"
    , "fn run() -> BigInt { 1606938044258990275541962092341162602522202993782792835301376 }"
    ]
  hugeDefault <- codes
    [ "module M"
    , "fn run() { 1606938044258990275541962092341162602522202993782792835301376 }"
    ]
  nonInteger <- codes ["module M", "fn run() -> Bool { 1 }"]
  arithmetic <- codes ["module M", "fn run() -> Int8 { 1 + 2 }"]
  let overflowSource = Text.unlines
        [ "module M"
        , "fn run() -> Int8 { 128i8 }"
        ]
  overflowResult <- compile overflowSource
  pure $ conjoin
    [ counterexample "every compiler-wired integer type accepts a fitting literal"
        (contextual === replicate (length integerTypes) [])
    , counterexample "every fixed-width suffix selects its exact type"
        (suffixTypes === integerSuffixTypes)
    , counterexample "an unconstrained literal defaults to Int" (defaulted === "Int")
    , counterexample "context selects Int8 before defaulting" (selected === "Int8")
    , counterexample "a suffix survives a base-prefixed body" (based === "UInt8")
    , signedHigh === []
    , signedLow === []
    , counterexample "signed upper overflow is rejected" (signedOverflow === ["E3018"])
    , counterexample "signed lower overflow is rejected" (signedUnderflow === ["E3018"])
    , unsignedHigh === []
    , counterexample "unsigned upper overflow is rejected" (unsignedOverflow === ["E3018"])
    , counterexample "negative unsigned literals are rejected" (unsignedNegative === ["E3018"])
    , counterexample "contextual literals receive the same fit check"
        (contextualOverflow === ["E3018"])
    , counterexample "BigInt remains unbounded" (hugeBigInt === [])
    , counterexample "a context-free huge literal must still fit default Int"
        (hugeDefault === ["E3018"])
    , counterexample "integer syntax cannot satisfy a non-integer context"
        (nonInteger === ["E3001"])
    , counterexample "operator constraints reach both literals" (arithmetic === [])
    , diagnosticContract overflowSource "128i8" "E3018"
        "integer literal 128 does not fit Int8"
        (Just "choose a wider integer type or change the literal")
        overflowResult
    ]

acceptsIntegerType :: Text -> IO [Text]
acceptsIntegerType name = codes ["module M", "fn run() -> " <> name <> " { 1 }"]

integerTypes :: [Text]
integerTypes =
  [ "Int8", "Int16", "Int32", "Int64", "Int128", "Int"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128", "UInt", "BigInt"
  ]

integerSuffixes :: [Text]
integerSuffixes =
  [ "1i8", "1i16", "1i32", "1i64", "1i128"
  , "1u8", "1u16", "1u32", "1u64", "1u128"
  ]

integerSuffixTypes :: [Text]
integerSuffixTypes =
  [ "Int8", "Int16", "Int32", "Int64", "Int128"
  , "UInt8", "UInt16", "UInt32", "UInt64", "UInt128"
  ]

testFloatLiterals :: IO Property
testFloatLiterals = do
  defaulted <- typeOf "1.0"
  selected32 <- typeOf "1.0f32"
  selected64 <- typeOf "1.0f64"
  exponent32 <- typeOf "1e3f32"
  annotated32 <- codes ["module M", "fn run() -> Float32 { 1.0f32 }"]
  implicitNarrowing <- codes ["module M", "fn run() -> Float32 { 1.0 }"]
  arithmetic32 <- codes ["module M", "fn run() -> Float32 { 1.0f32 + 2.0f32 }"]
  mixedWidths <- codes ["module M", "fn run() -> Float64 { 1.0f32 + 2.0f64 }"]
  finiteMaximum <- codes ["module M", "fn run() -> Float32 { 3.4028235e38f32 }"]
  overflow32 <- codes ["module M", "fn run() -> Float32 { 3.4028236e38f32 }"]
  overflow64 <- codes ["module M", "fn run() -> Float64 { 1e309f64 }"]
  underflow <- codes ["module M", "fn run() -> Float32 { 1e-100f32 }"]
  patternOverflow <- codes
    [ "module M"
    , "fn run(value: Float32) -> Bool {"
    , "  match value {"
    , "    case 3.4028236e38f32 => true"
    , "    case _ => false"
    , "  }"
    , "}"
    ]
  let overflowSource = Text.unlines
        [ "module M"
        , "fn run() -> Float32 { 3.4028236e38f32 }"
        ]
  overflowResult <- compile overflowSource
  pure $ conjoin
    [ counterexample "an unsuffixed float stays Float64" (defaulted === "Float64")
    , counterexample "f32 selects Float32" (selected32 === "Float32")
    , counterexample "f64 selects Float64" (selected64 === "Float64")
    , counterexample "suffixes follow exponent text" (exponent32 === "Float32")
    , annotated32 === []
    , counterexample "context cannot narrow an unsuffixed float"
        (implicitNarrowing === ["E3001"])
    , counterexample "same-width Float32 arithmetic is admitted" (arithmetic32 === [])
    , counterexample "mixed float widths require explicit conversion" (mixedWidths === ["E3001"])
    , counterexample "the binary32 maximum is admitted" (finiteMaximum === [])
    , counterexample "binary32 overflow is rejected" (overflow32 === ["E3019"])
    , counterexample "binary64 overflow is rejected" (overflow64 === ["E3019"])
    , counterexample "underflow rounds rather than overflowing" (underflow === [])
    , counterexample "pattern literals receive the same overflow check"
        (patternOverflow === ["E3019"])
    , diagnosticContract overflowSource "3.4028236e38f32" "E3019"
        "floating literal 3.4028236e38f32 does not fit Float32"
        (Just "choose Float64 or reduce the literal magnitude")
        overflowResult
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
  contextualBranches <- codes
    ["module M", "fn run(flag: Bool) -> UInt8 { if flag { 1 } else { 2 } }"]
  contextualMatch <- codes
    [ "module M"
    , "fn run(flag: Bool) -> UInt8 {"
    , "  match flag {"
    , "    case true => 1"
    , "    case false => 2"
    , "  }"
    , "}"
    ]
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
    , counterexample "an outer result selects if literal widths" (contextualBranches === [])
    , counterexample "an outer result selects match literal widths" (contextualMatch === [])
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
  annotatedBinding <- codes ["module M", "export const ANSWER: Int = 42"]
  missingBinding <- codes ["module M", "export const ANSWER = 42"]
  privateInferred <- codes ["module M", "fn run(value) { value }"]
  pure $ conjoin
    [ annotated === []
    , missingReturn === ["E3010"]
    , missingParameter === ["E3010"]
    , annotatedBinding === []
    , counterexample "an exported binding has a body-free interface type" (missingBinding === ["E3010"])
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

testPreludeData :: IO Property
testPreludeData = do
  option <- typeOf "Some(1)"
  none <- codesOfExpression "None"
  result <- typeOf "Ok(1)"
  wrongPayload <- codes
    [ "module M"
    , "fn run() -> Option[Int] { Some(\"text\") }"
    ]
  generic <- codes
    [ "module M"
    , "type Wrapper[T] = | Wrap(T) | Empty"
    , "fn run() -> Int {"
    , "  match Wrap(1) {"
    , "    case Wrap(value) => value"
    , "    case Empty => 0"
    , "  }"
    , "}"
    ]
  shadowed <- codes
    [ "module M"
    , "type Mine = | Ok(Str) | Err(Str)"
    , "fn run() -> Mine { Ok(\"text\") }"
    ]
  pure $ conjoin
    [ counterexample "Some builds an Option" (option === "Option[Int]")
    , counterexample "None needs no declaration" (none === [])
    , counterexample "Ok builds a Result" (Text.isPrefixOf "Result[Int" result === True)
    , counterexample "a constructor checks its payload" (wrongPayload === ["E3001"])
    , counterexample "a generic sum instantiates per use" (generic === [])
    , counterexample "a module may declare its own Ok" (shadowed === [])
    ]

testTry :: IO Property
testTry = do
  admitted <- codes
    [ "module M"
    , "fn attempt() -> Result[Int, Str] { Ok(1) }"
    , "fn run() -> Result[Int, Str] {"
    , "  let value = attempt()?"
    , "  Ok(value + 1)"
    , "}"
    ]
  wrongCarrier <- codes
    [ "module M"
    , "fn attempt() -> Result[Int, Str] { Ok(1) }"
    , "fn run() -> Int { attempt()? }"
    ]
  wrongFailure <- codes
    [ "module M"
    , "fn attempt() -> Result[Int, Str] { Ok(1) }"
    , "fn run() -> Result[Int, Bool] {"
    , "  let value = attempt()?"
    , "  Ok(value)"
    , "}"
    ]
  pure $ conjoin
    [ admitted === []
    , counterexample "? needs a Result-returning function" (wrongCarrier === ["E3011"])
    , counterexample "the failure types must agree" (wrongFailure === ["E3001"])
    ]

testAsync :: IO Property
testAsync = do
  task <- typeOfIn
    [ "async fn fetch() -> Int { 42 }"
    , "fn run() { fetch() }"
    ] "fetch()"
  failingTask <- typeOfIn
    [ "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "fn run() { fetch() }"
    ] "fetch()"
  forwardTask <- typeOfIn
    [ "fn run() { (fetch()) }"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    ] "(fetch())"
  awaited <- typeOfIn
    [ "async fn fetch() -> Int { 42 }"
    , "async fn run() -> Int { fetch().await }"
    ] "fetch().await"
  propagated <- codes
    [ "module M"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "async fn run() -> Result[Int, Str] {"
    , "  let value = fetch().await"
    , "  Ok(value)"
    , "}"
    ]
  syncAwait <- codes
    [ "module M"
    , "async fn fetch() -> Int { 42 }"
    , "fn run() -> Int { fetch().await }"
    ]
  nonTask <- codes
    [ "module M"
    , "async fn run() -> Int { (1).await }"
    ]
  missingCarrier <- codes
    [ "module M"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "async fn run() -> Int { fetch().await }"
    ]
  wrongFailure <- codes
    [ "module M"
    , "async fn fetch() -> Result[Int, Str] { Ok(42) }"
    , "async fn run() -> Result[Int, Bool] {"
    , "  let value = fetch().await"
    , "  Ok(value)"
    , "}"
    ]
  let missingReturnSource = Text.unlines
        [ "module M"
        , "async fn fetch() { 42 }"
        ]
      missingParameterSource = Text.unlines
        [ "module M"
        , "async fn fetch(value) -> Int { value }"
        ]
      syncAwaitSource = Text.unlines
        [ "module M"
        , "async fn fetch() -> Int { 42 }"
        , "fn run() -> Int { fetch().await }"
        ]
      nonTaskSource = Text.unlines
        [ "module M"
        , "async fn run() -> Int { (1).await }"
        ]
  missingReturn <- compile missingReturnSource
  missingParameter <- compile missingParameterSource
  syncAwaitDiagnostic <- compile syncAwaitSource
  nonTaskDiagnostic <- compile nonTaskSource
  pure $ conjoin
    [ counterexample "a non-failing async call is a Task" (task === "Task[Int, Never]")
    , counterexample "Result supplies the task failure channel" (failingTask === "Task[Int, Str]")
    , counterexample "forward calls use the declared task channels" (forwardTask === "Task[Int, Str]")
    , counterexample "await yields the task success channel" (awaited === "Int")
    , counterexample "a compatible async Result propagates failure" (propagated === [])
    , counterexample "await is confined to async functions" (syncAwait === ["E3016"])
    , counterexample "await accepts only Task" (nonTask === ["E3017"])
    , counterexample "failing await needs a Result carrier" (missingCarrier === ["E3011"])
    , counterexample "await failure types must agree" (wrongFailure === ["E3001"])
    , diagnosticContract missingReturnSource "fetch" "E3010"
        "async function fetch needs a return type"
        (Just "annotate the return type so callers can form Task[S, E] without inspecting the body")
        missingReturn
    , diagnosticContract missingParameterSource "value)" "E3010"
        "async parameter value needs a type"
        (Just "annotate every parameter of an async function so calls do not determine its contract")
        missingParameter
    , diagnosticContract syncAwaitSource "fetch().await" "E3016"
        ".await is only legal inside async fn"
        (Just "move the await into an async function, or return the task")
        syncAwaitDiagnostic
    , diagnosticContract nonTaskSource "(1).await" "E3017"
        ".await needs a Task, found Int"
        (Just "await an async function call or another Task value")
        nonTaskDiagnostic
    ]

diagnosticContract :: Text -> Text -> Text -> Text -> Maybe Text -> CompileResult -> Property
diagnosticContract source needle expectedCode expectedMessage expectedHelp result =
  case (compileDiagnostics result, region source needle) of
    ([value], Just (expectedStart, _)) ->
      conjoin
        [ diagnosticCodeText (diagnosticCode value) === expectedCode
        , diagnosticMessage value === expectedMessage
        , diagnosticHelp value === expectedHelp
        , unOffset (spanStart (diagnosticSpan value)) === expectedStart
        ]
    (values, location) ->
      counterexample ("unexpected diagnostics or location: " <> show (length values, location)) False

traitProgram :: [Text]
traitProgram =
  [ "module M"
  , "type User = { name: Str }"
  , "trait Greet {"
  , "  fn name(self: &Self) -> Str"
  , "  fn greet(self: &Self) -> Str = \"hello\""
  , "}"
  , "impl Greet for User {"
  , "  fn name(self: &Self) -> Str { self.name }"
  , "}"
  ]

testTraits :: IO Property
testTraits = do
  implemented <- codes (traitProgram <> ["fn run(user: User) -> Str { user.name() }"])
  inherited <- codes (traitProgram <> ["fn run(user: User) -> Str { user.greet() }"])
  wrongResult <- codes (traitProgram <> ["fn run(user: User) -> Int { user.greet() }"])
  unknownMethod <- codes (traitProgram <> ["fn run(user: User) -> Str { user.missing() }"])
  selfFields <- codes traitProgram
  methodType <- typeOfIn (drop 1 traitProgram <> ["fn run(user: User) -> Str { user.greet() }"]) "user.greet"
  pure $ conjoin
    [ counterexample "an implemented method is callable" (implemented === [])
    , counterexample "a default is inherited" (inherited === [])
    , counterexample "a method result is still checked" (wrongResult === ["E3001"])
    , counterexample "an unknown method is reported" (unknownMethod === ["E3005"])
    , counterexample "Self reads the implementing type's fields" (selfFields === [])
    , counterexample "the receiver is already applied" (methodType === "fn() -> Str")
    ]

{-| A trait default body that calls another trait method on `self` must resolve
    through the rigid `Self` bound, finding the method in the trait's own
    member table. This covers the case where a default composes other trait
    methods that the implementation inherits. -}
defaultCallProgram :: [Text]
defaultCallProgram =
  [ "module M"
  , "type Bot = { id: Int }"
  , "trait Service {"
  , "  fn id(self: &Self) -> Int"
  , "  fn label(self: &Self) -> Str = \"bot\""
  , "  fn report(self: &Self) -> Str { self.label() }"
  , "}"
  , "impl Service for Bot {"
  , "  fn id(self: &Self) -> Int { self.id }"
  , "}"
  ]

testTraitDefaultCalls :: IO Property
testTraitDefaultCalls = do
  defaultBody <- codes (defaultCallProgram <> ["fn run(b: Bot) -> Str { b.report() }"])
  genericDispatch <- codes
    (defaultCallProgram <> ["fn run[T: Service](value: T) -> Str { value.report() }"])
  wrongResult <- codes (defaultCallProgram <> ["fn run(b: Bot) -> Int { b.report() }"])
  pure $ conjoin
    [ counterexample "a default body calls another trait method on Self"
        (defaultBody === [])
    , counterexample "generic dispatch through a default that calls a trait method"
        (genericDispatch === [])
    , counterexample "the default body's result is still checked"
        (wrongResult === ["E3001"])
    ]

colorProgram :: [Text]
colorProgram = ["module M", "type Color = | Red | Green | Blue"]

testExhaustiveness :: IO Property
testExhaustiveness = do
  complete <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Green => 2"
    , "    case Blue => 3"
    , "  }"
    , "}"
    ])
  missing <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Green => 2"
    , "  }"
    , "}"
    ])
  wildcard <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case _ => 0"
    , "  }"
    , "}"
    ])
  guarded <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case Red => 1"
    , "    case Green => 2"
    , "    case other if true => 3"
    , "  }"
    , "}"
    ])
  option <- codes ["module M", "fn run(value: Option[Int]) -> Int { match value { case Some(v) => v } }"]
  openDomain <- codes ["module M", "fn run(value: Int) -> Int { match value { case 1 => 1 } }"]
  unreachable <- codes (colorProgram <>
    [ "fn run(c: Color) -> Int {"
    , "  match c {"
    , "    case _ => 0"
    , "    case Red => 1"
    , "  }"
    , "}"
    ])
  payloadTested <- codes ["module M", "fn run(value: Option[Int]) -> Int { match value { case Some(1) => 1 case None => 0 } }"]
  pure $ conjoin
    [ counterexample "every constructor covered" (complete === [])
    , counterexample "a missing constructor is reported" (missing === ["E5001"])
    , counterexample "a wildcard covers the rest" (wildcard === [])
    , counterexample "a guarded arm does not cover" (guarded === ["E5001"])
    , counterexample "Option must cover None" (option === ["E5001"])
    , counterexample "an open domain needs a wildcard" (openDomain === ["E5001"])
    , counterexample "an arm after a wildcard is unreachable" (unreachable === ["W5001"])
    , counterexample "a tested payload does not cover its constructor"
        (payloadTested === ["E5001"])
    ]

boundProgram :: [Text]
boundProgram =
  [ "module M"
  , "type User = { name: Str }"
  , "trait Show {"
  , "  fn show(self: &Self) -> Str"
  , "}"
  , "impl Show for User {"
  , "  fn show(self: &Self) -> Str { self.name }"
  , "}"
  , "fn display[T: Show](value: T) -> Str { value.show() }"
  ]

testBounds :: IO Property
testBounds = do
  satisfied <- codes (boundProgram <> ["fn run() -> Str { display(User{name: \"a\"}) }"])
  unsatisfied <- codes (boundProgram <> ["fn run() -> Str { display(5) }"])
  forwarded <- codes (boundProgram <> ["fn again[T: Show](value: T) -> Str { display(value) }"])
  unbounded <- codes (boundProgram <> ["fn again[T](value: T) -> Str { display(value) }"])
  whereClause <- codes (boundProgram <>
    [ "fn again[T](value: T) -> Str where T: Show { display(value) }" ])
  missingMethod <- codes
    [ "module M"
    , "trait Show { fn show(self: &Self) -> Str }"
    , "fn display[T: Show](value: T) -> Str { value.missing() }"
    ]
  pure $ conjoin
    [ counterexample "an implementing type satisfies the bound" (satisfied === [])
    , counterexample "a type without the implementation is reported"
        (unsatisfied === ["E3012"])
    , counterexample "a bounded parameter forwards its bound" (forwarded === [])
    , counterexample "an unbounded parameter cannot" (unbounded === ["E3012"])
    , counterexample "a where clause carries the same bound" (whereClause === [])
    , counterexample "a bound supplies only its own methods"
        (missingMethod === ["E3005"])
    ]

ambiguousProgram :: [Text]
ambiguousProgram =
  [ "module M"
  , "trait A { fn name(self: &Self) -> Str }"
  , "trait B { fn name(self: &Self) -> Str }"
  , "fn run[T: A + B](value: T) -> Str { value.name() }"
  ]

testAmbiguousMethod :: IO Property
testAmbiguousMethod = do
  ambiguous <- codes ambiguousProgram
  pure $ conjoin
    [ counterexample "two trait bounds providing the same member is ambiguous"
        (ambiguous === ["E3013"])
    ]

testCoherence :: IO Property
testCoherence = do
  let duplicateProgram =
        [ "module M"
        , "type Local = { value: Int }"
        , "trait Mark { fn mark(self: &Self) -> Int = 1 }"
        , "impl Mark for Local {}"
        , "impl Mark for Local {}"
        ]
      duplicateSource = Text.unlines duplicateProgram
      orphanProgram =
        [ "module M"
        , "import Traits {Mark}"
        , "import Models {Remote}"
        , "impl Mark for Remote {}"
        ]
      orphanSource = Text.unlines orphanProgram
  duplicateResult <- compile duplicateSource
  orphanResult <- compile orphanSource
  qualifiedDistinct <- codes
    [ "module M"
    , "import A"
    , "import B"
    , "type Local = { value: Int }"
    , "impl A.Mark for Local {}"
    , "impl B.Mark for Local {}"
    ]
  qualifiedDuplicate <- codes
    [ "module M"
    , "import A"
    , "type Local = { value: Int }"
    , "impl A.Mark for Local {}"
    , "impl A.Mark for Local {}"
    ]
  alphaEquivalent <- codes
    [ "module M"
    , "type Box[T] = { value: T }"
    , "trait Mark {}"
    , "impl[T] Mark for Box[T] {}"
    , "impl[U] Mark for Box[U] {}"
    ]
  distinctArguments <- codes
    [ "module M"
    , "type Box[T] = { value: T }"
    , "trait Mark {}"
    , "impl Mark for Box[Int] {}"
    , "impl Mark for Box[Str] {}"
    ]
  structural <- codes
    [ "module M"
    , "trait Mark {}"
    , "impl Mark for &Int {}"
    , "impl Mark for &Int {}"
    ]
  repeated <- codes
    [ "module M"
    , "type Local = { value: Int }"
    , "trait Mark { fn mark(self: &Self) -> Int = 1 }"
    , "impl Mark for Local {}"
    , "impl Mark for Local {}"
    , "impl Mark for Local {}"
    ]
  foreignTraitLocalTarget <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "impl Mark for Local {}"
    ]
  foreignTraitLocalSum <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = | First | Second"
    , "impl Mark for Local {}"
    ]
  localTraitForeignTarget <- codes
    [ "module M"
    , "import Models {Remote}"
    , "trait Mark {}"
    , "impl Mark for Remote {}"
    ]
  foreignAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "import Models {Remote}"
    , "type Alias = Remote"
    , "impl Mark for Alias {}"
    ]
  localAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "type Alias = Local"
    , "impl Mark for Alias {}"
    ]
  genericAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "import Models {Remote}"
    , "type Identity[T] = T"
    , "impl Mark for Identity[Remote] {}"
    ]
  genericLocalAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "type Identity[T] = T"
    , "impl Mark for Identity[Local] {}"
    ]
  aliasChain <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "import Models {Remote}"
    , "type First[T] = Second[T]"
    , "type Second[U] = U"
    , "impl Mark for First[Remote] {}"
    ]
  traitAlias <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type MarkAlias = Mark"
    , "impl MarkAlias for Int {}"
    ]
  foreignNonNominal <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "impl Mark for &Int {}"
    ]
  foreignBuiltin <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "impl Mark for Int {}"
    ]
  foreignParameter <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "impl[T] Mark for T {}"
    ]
  aliasShadow <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type Local = { value: Int }"
    , "type T = Local"
    , "impl[T] Mark for T {}"
    ]
  nominalShadow <- codes
    [ "module M"
    , "import Traits {Mark}"
    , "type T = { value: Int }"
    , "impl[T] Mark for T {}"
    ]
  traitShadow <- codes
    [ "module M"
    , "import Models {Remote}"
    , "trait T {}"
    , "impl[T] T for Remote {}"
    ]
  pure $ conjoin
    [ counterexample "the duplicate diagnostic preserves code message help and target span"
        (duplicateDiagnostic duplicateSource duplicateResult)
    , counterexample "the orphan diagnostic preserves code message help and target span"
        (orphanDiagnostic orphanSource orphanResult)
    , counterexample "qualified traits with the same basename stay distinct"
        (qualifiedDistinct === [])
    , counterexample "the same qualified head is rejected"
        (qualifiedDuplicate === ["E3015"])
    , counterexample "generic binder renaming does not evade the check"
        (alphaEquivalent === ["E3015"])
    , counterexample "different concrete arguments are distinct exact heads"
        (distinctArguments === [])
    , counterexample "non-nominal syntax does not bypass duplicate detection"
        (structural === ["E3015"])
    , counterexample "each implementation after the first reports once"
        (repeated === ["E3015", "E3015"])
    , counterexample "a foreign trait is owned by a local nominal target"
        (foreignTraitLocalTarget === [])
    , counterexample "a local sum declaration supplies nominal ownership"
        (foreignTraitLocalSum === [])
    , counterexample "a local trait owns a foreign target"
        (localTraitForeignTarget === [])
    , counterexample "a local alias cannot launder a foreign target"
        (foreignAlias === ["E3014"])
    , counterexample "an alias of a local nominal target remains locally owned"
        (localAlias === [])
    , counterexample "generic alias substitution preserves foreign ownership"
        (genericAlias === ["E3014"])
    , counterexample "generic alias substitution reaches a local nominal owner"
        (genericLocalAlias === [])
    , counterexample "alias chains substitute arguments before ownership"
        (aliasChain === ["E3014"])
    , counterexample "a local alias cannot launder a foreign trait"
        (traitAlias === ["E3014"])
    , counterexample "a non-nominal target contributes no local owner"
        (foreignNonNominal === ["E3014"])
    , counterexample "a built-in target contributes no local owner"
        (foreignBuiltin === ["E3014"])
    , counterexample "an implementation parameter contributes no local owner"
        (foreignParameter === ["E3014"])
    , counterexample "a parameter shadows a same-named local alias for ownership"
        (aliasShadow === ["W2001", "E3014"])
    , counterexample "a parameter shadows a same-named local nominal for ownership"
        (nominalShadow === ["W2001", "E3014"])
    , counterexample "a parameter shadows a same-named local trait for ownership"
        (traitShadow === ["W2001", "E3014"])
    ]

orphanDiagnostic :: Text -> CompileResult -> Property
orphanDiagnostic source result =
  case (compileDiagnostics result, region source "Remote") of
    ([value], Just (expectedStart, _)) -> conjoin
      [ diagnosticCodeText (diagnosticCode value) === "E3014"
      , diagnosticMessage value === "orphan implementation: neither the trait nor target type is declared in this module"
      , diagnosticHelp value === Just "move this implementation to the module that declares the trait or target nominal type; aliases do not confer ownership"
      , unOffset (spanStart (diagnosticSpan value)) === expectedStart
      ]
    (values, location) ->
      counterexample ("unexpected diagnostics or location: " <> show (length values, location)) False

duplicateDiagnostic :: Text -> CompileResult -> Property
duplicateDiagnostic source result =
  case (compileDiagnostics result, region source "Local") of
    ([value], Just (expectedStart, _)) -> conjoin
      [ diagnosticCodeText (diagnosticCode value) === "E3015"
      , diagnosticMessage value === "duplicate implementation: Mark is already implemented for Local"
      , diagnosticHelp value === Just "remove one implementation; duplicate implementation heads are prohibited"
      , unOffset (spanStart (diagnosticSpan value)) === expectedStart
      ]
    (values, location) ->
      counterexample ("unexpected diagnostics or location: " <> show (length values, location)) False

testFloatAlias :: IO Property
testFloatAlias = do
  floatIsAlias <- typeOfIn ["fn run() -> Float { 3.14 }"] "3.14"
  float64Direct <- typeOfIn ["fn run() -> Float64 { 3.14 }"] "3.14"
  pure $ conjoin
    [ counterexample "Float renders as Float64" (floatIsAlias === "Float64")
    , counterexample "Float64 is itself" (float64Direct === "Float64")
    ]

testRecordedTypes :: IO Property
testRecordedTypes = do
  recorded <- typeOfIn ["fn run() -> Bool {", "  1 < 2", "}"] "1 < 2"
  pure (recorded === "Bool")

userProgram :: [Text]
userProgram = ["module M", "type User = { name: Str }"]

testDereference :: IO Property
testDereference = do
  readThrough <- codes (userProgram <>
    [ "fn run(user: User) -> User {"
    , "  let borrowed = &user"
    , "  *borrowed"
    , "}"
    ])
  fieldThroughBorrow <- codes (userProgram <>
    [ "fn run(user: User) -> Str {"
    , "  let borrowed = &user"
    , "  (*borrowed).name"
    , "}"
    ])
  selfDeref <- codes (userProgram <>
    [ "trait Clone {"
    , "  fn duplicate(self: &Self) -> Self"
    , "}"
    , "impl Clone for User {"
    , "  fn duplicate(self: &Self) -> Self { *self }"
    , "}"
    ])
  borrowWhereValue <- codes (userProgram <>
    [ "fn takes(user: User) -> User { user }"
    , "fn run(user: User) -> User { takes(&user) }"
    ])
  nonReference <- codes (userProgram <> ["fn run(user: User) -> User { *user }"])
  mutableBorrow <- codes (userProgram <>
    [ "fn run(user: User) -> User {"
    , "  let borrowed = &mut user"
    , "  *borrowed"
    , "}"
    ])
  derefType <- typeOfIn
    (drop 1 userProgram <>
      [ "fn run(user: User) -> User {"
      , "  let borrowed = &user"
      , "  *borrowed"
      , "}"
      ])
    "*borrowed"
  pure $ conjoin
    [ counterexample "a borrow is read with *" (readThrough === [])
    , counterexample "a field is reached through a dereference" (fieldThroughBorrow === [])
    , counterexample "&Self dereferences to Self" (selfDeref === [])
    , counterexample "no implicit conversion from a borrow" (borrowWhereValue === ["E3001"])
    , counterexample "a non-reference cannot be dereferenced" (nonReference === ["E3020"])
    , counterexample "an exclusive borrow dereferences too" (mutableBorrow === [])
    , counterexample "the dereference has the referent's type" (derefType === "User")
    ]

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
