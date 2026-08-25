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
  [ ("a generic alias stands for what it names", testGenericAliases)
  , ("a trait bound is satisfied by any implementation in the program", testGlobalImpls)
  , ("maps and sets are typed by what they hold", testKeyedTypes)
  , ("a tuple is indexed by a literal position", testTupleIndex)
  , ("function literals are typed and inferred", testLambdaTypes)
  , ("a match reads through a borrow", testMatchThroughBorrow)
  , ("built-in text methods are typed exactly", testTextMethods)
  , ("a discarded collection result is reported", testDiscardedResult)
  , ("literals and operators take their declared types", testOperators)
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
  , ("compiler-controlled markers are decided structurally", testMarkers)
  , ("same-named trait methods are selected by a qualified call", testQualifiedMethods)
  , ("a generic trait's parameters are solved from its implementation", testGenericTraits)
  , ("a type declaration's parameters are instantiated at every use", testGenericTypes)
  , ("a for loop binds at the element type of what it iterates", testIterationTypes)
  , ("Decimal is an ordinary type with exact literals", testDecimalType)
  , ("unsafe regions grant named capabilities and contain their calls", testUnsafe)
  , ("compile-time functions keep their evaluator pure", testComptime)
  , ("a structured scope requires an async function", testScopes)
  , ("expression types are recorded for tooling", testRecordedTypes)
  ]

{-| A trait's own type parameters used to be formed as nominal types named
    after the parameter, so `trait Holds[T]` gave `get` a result of some type
    literally called `T`, and a trait-qualified call typed itself from the
    declaration rather than from the implementation it would actually run. -}
testGenericTraits :: IO Property
testGenericTraits = do
  methodCall <- codes (genericTrait <> ["fn run(b: Box) -> Int { b.get() }"])
  qualifiedCall <- codes (genericTrait <> ["fn run(b: Box) -> Int { Holds.get(&b) }"])
  wrongResult <- codes (genericTrait <> ["fn run(b: Box) -> Str { Holds.get(&b) }"])
  twoParameters <- codes
    [ "module M"
    , "type Pair = { a: Int }"
    , "trait Maps[K, V] { fn lookup(self: &Self, key: K) -> Option[V] }"
    , "impl Maps[Int, Str] for Pair {"
    , "  fn lookup(self: &Self, key: Int) -> Option[Str] { None }"
    , "}"
    , "fn run(p: Pair) -> Option[Str] { Maps.lookup(&p, 1) }"
    ]
  nonGenericStillWorks <- codes
    [ "module M"
    , "type Bot = { id: Int }"
    , "trait Speak { fn label(self: &Self) -> Int }"
    , "impl Speak for Bot { fn label(self: &Self) -> Int { 1 } }"
    , "fn run(b: Bot) -> Int { Speak.label(&b) }"
    ]
  pure $ conjoin
    [ counterexample "method syntax resolves the concrete method" (methodCall === [])
    , counterexample "so does the trait-qualified form" (qualifiedCall === [])
    , counterexample "and it is still checked against the implementation"
        (wrongResult === ["E3001"])
    , counterexample "a trait may carry more than one parameter" (twoParameters === [])
    , counterexample "a trait with no parameters is unaffected"
        (nonGenericStillWorks === [])
    ]
 where
  genericTrait =
    [ "module M"
    , "type Box = { v: Int }"
    , "trait Holds[T] { fn get(self: &Self) -> T }"
    , "impl Holds[Int] for Box { fn get(self: &Self) -> Int { self.v } }"
    ]

{-| A generic record used to type as its bare nominal with the declaration's
    own rigid parameters in its fields, so `Boxed{value: 7}` was a `Boxed` whose
    `value` was some type called `T` that nothing could satisfy. Sums were
    already instantiated; records simply never were. -}
testGenericTypes :: IO Property
testGenericTypes = do
  construction <- codes (boxed <> ["fn run() -> Boxed[Int] { Boxed{value: 7} }"])
  fieldRead <- codes (boxed <> ["fn run(b: &Boxed[Int]) -> Int { b.value }"])
  throughFunction <- codes
    (boxed <> ["fn unwrap[T](b: &Boxed[T]) -> T { b.value }", "fn run() -> Int { unwrap(&Boxed{value: 7}) }"])
  wrongField <- codes (boxed <> ["fn run(b: &Boxed[Int]) -> Str { b.value }"])
  inPattern <- codes
    ( boxed
        <> [ "fn run(b: Boxed[Int]) -> Int { match b { case Boxed{value} => value } }" ]
    )
  genericImpl <- codes
    [ "module M"
    , "trait Holds[T] { fn get(self: &Self) -> T }"
    , "type Boxed[T] = { value: T }"
    , "impl[T] Holds[T] for Boxed[T] { fn get(self: &Self) -> T { self.value } }"
    , "fn run() -> Int { Holds.get(&Boxed{value: 7}) }"
    ]
  boundedImpl <- codes
    [ "module M"
    , "trait Joins { fn join(self: &Self, other: &Self) -> Self }"
    , "trait Doubles { fn twice(self: &Self) -> Self }"
    , "type Wrap[N] = { held: N }"
    , "impl[N: Joins] Doubles for Wrap[N] {"
    , "  fn twice(self: &Self) -> Self { Wrap{held: self.held.join(&self.held)} }"
    , "}"
    ]
  unboundedImpl <- codes
    [ "module M"
    , "trait Joins { fn join(self: &Self, other: &Self) -> Self }"
    , "trait Doubles { fn twice(self: &Self) -> Self }"
    , "type Wrap[N] = { held: N }"
    , "impl[N] Doubles for Wrap[N] {"
    , "  fn twice(self: &Self) -> Self { Wrap{held: self.held.join(&self.held)} }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "construction carries its arguments" (construction === [])
    , counterexample "a field read substitutes them" (fieldRead === [])
    , counterexample "and so does a call through a generic function"
        (throughFunction === [])
    , counterexample "a field is still checked against its instantiated type"
        (wrongField === ["E3001"])
    , counterexample "a record pattern instantiates too" (inPattern === [])
    , counterexample "an implementation may carry its own parameters"
        (genericImpl === [])
    , counterexample "and the bounds on them are in force inside its methods"
        (boundedImpl === [])
    , counterexample "a parameter with no bound still promises nothing"
        (unboundedImpl === ["E3005"])
    ]
 where
  boxed = ["module M", "type Boxed[T] = { value: T }"]

{-| `for` used to bind an unconstrained fresh variable, so the loop — the one
    place a binder's type is decided entirely by the value beside it — decided
    nothing, and every use of the binding was let through. -}
testIterationTypes :: IO Property
testIterationTypes = do
  arrayElement <- codes
    ["module M", "fn run(xs: Array[Int]) -> Int { var n = 0", "  for x in xs { n = n + x }", "  n }"]
  wrongElement <- codes
    ["module M", "fn run(xs: Array[Int]) -> Int { var n = 0", "  for x in xs { n = n + x.length() }", "  n }"]
  textElement <- codes
    ["module M", "fn run(t: Str) -> Int { var n = 0", "  for c in t { n = n + c.code() }", "  n }"]
  optionElement <- codes
    ["module M", "fn run(o: Option[Int]) -> Int { var n = 0", "  for x in o { n = n + x }", "  n }"]
  notIterable <- codes
    [ "module M"
    , "type Thing = { v: Int }"
    , "fn run(t: Thing) -> Int { var n = 0"
    , "  for x in t { n = n + 1 }"
    , "  n }"
    ]
  ownSequence <- codes
    [ "module M"
    , "import Std.Iter {Sequence}"
    , "type Down = { from: Int }"
    , "impl Sequence[Int, Int] for Down {"
    , "  fn begin(self: &Self) -> Int { self.from }"
    , "  fn advance(self: &Self, state: Int) -> Option[(Int, Int)] {"
    , "    if state > 0 { Some((state - 1, state)) } else { None }"
    , "  }"
    , "}"
    , "fn run(d: Down) -> Int { var n = 0"
    , "  for x in d { n = n + x }"
    , "  n }"
    ]
  pure $ conjoin
    [ counterexample "an array yields its element type" (arrayElement === [])
    , counterexample "and a wrong use of it is now caught" (wrongElement === ["E3005"])
    , counterexample "a string yields Char" (textElement === [])
    , counterexample "a sum yields what its variants carry" (optionElement === [])
    , counterexample "a type that is not a sequence is reported at the for"
        (notIterable === ["E3030"])
    , counterexample "a type implementing Sequence is iterable"
        (ownSequence === [])
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

testScopes :: IO Property
testScopes = do
  inAsync <- codes
    [ "module M"
    , "async fn run() -> Result[Int, Str] { async with scope { Ok(1) } }"
    ]
  inSync <- codes ["module M", "fn run() -> Int { async with scope { 1 } }"]
  scopeType <- typeOfIn
    [ "async fn run() -> Result[Int, Str] { async with scope { Ok(1) } }" ]
    "async with scope { Ok(1) }"
  pure $ conjoin
    [ counterexample "an async function may open a scope" (inAsync === [])
    , counterexample "a synchronous one may not" (inSync === ["E3026"])
    , counterexample "a scope has its block's type"
        (Text.isPrefixOf "Result[Int" scopeType === True)
    ]

comptimeProgram :: [Text]
comptimeProgram =
  [ "module M"
  , "comptime fn double(n: Int) -> Int { n * 2 }"
  , "fn runtime(n: Int) -> Int { n + 1 }"
  ]

testComptime :: IO Property
testComptime = do
  declaring <- codes comptimeProgram
  chained <- codes (comptimeProgram <>
    ["comptime fn quadruple(n: Int) -> Int { double(double(n)) }"])
  reachesRuntime <- codes (comptimeProgram <>
    ["comptime fn impure(n: Int) -> Int { runtime(n) }"])
  asyncComptime <- codes (comptimeProgram <>
    ["comptime async fn spawned() -> Int { 1 }"])
  unsafeComptime <- codes (comptimeProgram <>
    ["comptime unsafe fn unchecked() -> Int { 1 }"])
  calledAtRuntime <- codes (comptimeProgram <> ["fn run() -> Int { double(5) }"])
  constantFolds <- codes (comptimeProgram <> ["const VALUE: Int = double(21)"])
  constantFails <- codes ["module M", "const VALUE: Int = 1 / 0"]
  constantBudget <- codes
    [ "module M"
    , "fn spin() -> Int {"
    , "  var total = 0"
    , "  loop { total = total + 1 }"
    , "  total"
    , "}"
    , "const VALUE: Int = spin()"
    ]
  builtinsAllowed <- codes (comptimeProgram <>
    ["comptime fn wrap(n: Int) -> Option[Int] { Some(n) }"])
  pure $ conjoin
    [ counterexample "declaring is clean" (declaring === [])
    , counterexample "compile-time code may call compile-time code" (chained === [])
    , counterexample "it may not call a runtime function" (reachesRuntime === ["E3025"])
    , counterexample "it may not be async" (asyncComptime === ["E3025"])
    , counterexample "it may not be unsafe" (unsafeComptime === ["E3025"])
    , counterexample "runtime code may still call it" (calledAtRuntime === [])
    , counterexample "a constant folds at compile time" (constantFolds === [])
    , counterexample "a failing constant fails the compile" (constantFails === ["E7004"])
    , counterexample "an unbounded constant exhausts the budget"
        (constantBudget === ["E7002"])
    , counterexample "wired-in constructors stay reachable" (builtinsAllowed === [])
    ]

unsafeProgram :: [Text]
unsafeProgram =
  [ "module M"
  , "unsafe fn blanket() -> Int { 42 }"
  , "unsafe(raw) fn rawOnly() -> Int { 7 }"
  ]

testUnsafe :: IO Property
testUnsafe = do
  declaring <- codes unsafeProgram
  fromSafe <- codes (unsafeProgram <> ["fn run() -> Int { blanket() }"])
  wrapped <- codes (unsafeProgram <> ["fn run() -> Int { unsafe { blanket() } }"])
  precise <- codes (unsafeProgram <> ["fn run() -> Int { unsafe(raw) { rawOnly() } }"])
  wrongCapability <- codes (unsafeProgram <> ["fn run() -> Int { unsafe(null) { rawOnly() } }"])
  blanketGrantsAll <- codes (unsafeProgram <> ["fn run() -> Int { unsafe { rawOnly() } }"])
  fromUnsafeFunction <- codes (unsafeProgram <> ["unsafe fn run() -> Int { blanket() }"])
  unusedRegion <- codes (unsafeProgram <> ["fn run() -> Int { unsafe { 1 } }"])
  unusedCapability <- codes (unsafeProgram <>
    ["fn run() -> Int { unsafe(raw, null) { rawOnly() } }"])
  regionType <- typeOfIn (drop 1 unsafeProgram <> ["fn run() -> Int { unsafe { blanket() } }"])
    "unsafe { blanket() }"
  nullOutside <- codes ["module M", "fn run() -> Int { null }"]
  nullInside <- codes ["module M", "fn run() -> Int { unsafe(null) { null } }"]
  unknownCapability <- codes (unsafeProgram <>
    ["fn run() -> Int { unsafe(bogus) { blanket() } }"])
  pure $ conjoin
    [ counterexample "declaring is clean" (declaring === [])
    , counterexample "a safe caller is rejected" (fromSafe === ["E3023"])
    , counterexample "a blanket region admits a blanket call" (wrapped === [])
    , counterexample "a named region admits the call it grants" (precise === [])
    , counterexample "a region without the capability is rejected"
        (wrongCapability === ["W3001", "E3023"])
    , counterexample "a blanket region grants every capability" (blanketGrantsAll === [])
    , counterexample "an unsafe function's body is a region" (fromUnsafeFunction === [])
    , counterexample "a region nothing used is reported" (unusedRegion === ["W3001"])
    , counterexample "an unused capability is reported" (unusedCapability === ["W3001"])
    , counterexample "a region has the type of its block" (regionType === "Int")
    , counterexample "null needs its capability" (nullOutside === ["E3024"])
    , counterexample "null still has no type inside" (nullInside === ["E3024"])
    , counterexample "the capability vocabulary is closed"
        (unknownCapability === ["E1044"])
    ]

testDecimalType :: IO Property
testDecimalType = do
  annotated <- codes ["module M", "const VALUE: Decimal = 1.0d"]
  parameter <- codes ["module M", "fn run(amount: Decimal) -> Int { 1 }"]
  result <- codes ["module M", "fn run() -> Decimal { 1.0d }"]
  field <- codes ["module M", "type Money = { amount: Decimal }"]
  bothPositions <- codes ["module M", "fn run(amount: Decimal) -> Decimal { amount }"]
  ownDeclaration <- codes
    [ "module M"
    , "type Decimal = { units: Int }"
    , "fn run(amount: Decimal) -> Int { amount.units }"
    ]
  literalType <- typeOf "1.50d"
  wholeLiteral <- typeOf "3d"
  exponentLiteral <- typeOf "1e6d"
  noImplicitFloat <- codesOfExpression "1.5d + 1.5"
  noImplicitInt <- codesOfExpression "1.5d + 1"
  supported <- codes ["module M", "fn run(amount: Float64) -> Float64 { amount }"]
  pure $ conjoin
    [ counterexample "an annotation is ordinary" (annotated === [])
    , counterexample "a parameter is ordinary" (parameter === [])
    , counterexample "a result is ordinary" (result === [])
    , counterexample "a field is ordinary" (field === [])
    , counterexample "both positions are ordinary" (bothPositions === [])
    , counterexample "a module may still declare its own" (ownDeclaration === [])
    , counterexample "a suffixed literal is a Decimal" (literalType === "Decimal")
    , counterexample "a whole literal may be a Decimal" (wholeLiteral === "Decimal")
    , counterexample "an exponent stays exact" (exponentLiteral === "Decimal")
    , counterexample "there is no implicit conversion from a float"
        (noImplicitFloat === ["E3001"])
    , counterexample "there is no implicit conversion from an integer"
        (noImplicitInt === ["E3001"])
    , counterexample "the other numeric types are unaffected" (supported === [])
    ]

sharedNameProgram :: [Text]
sharedNameProgram =
  [ "module M"
  , "type Bot = { id: Int }"
  , "trait Speak { fn label(self: &Self) -> Str }"
  , "trait Print { fn label(self: &Self) -> Str }"
  , "impl Speak for Bot { fn label(self: &Self) -> Str { \"speak\" } }"
  , "impl Print for Bot { fn label(self: &Self) -> Str { \"print\" } }"
  ]

testQualifiedMethods :: IO Property
testQualifiedMethods = do
  declaring <- codes sharedNameProgram
  traitQualified <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Speak.label(&bot) }"])
  otherTrait <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Print.label(&bot) }"])
  unqualified <- codes (sharedNameProgram <> ["fn run(bot: Bot) -> Str { bot.label() }"])
  typeQualified <- codes
    [ "module M"
    , "type Bot = { id: Int }"
    , "trait Speak { fn label(self: &Self) -> Str }"
    , "impl Speak for Bot { fn label(self: &Self) -> Str { \"speak\" } }"
    , "fn run(bot: Bot) -> Str { Bot.label(&bot) }"
    ]
  singleProviderStillPlain <- codes
    [ "module M"
    , "type Bot = { id: Int }"
    , "trait Speak { fn label(self: &Self) -> Str }"
    , "impl Speak for Bot { fn label(self: &Self) -> Str { \"speak\" } }"
    , "fn run(bot: Bot) -> Str { bot.label() }"
    ]
  wrongReceiver <- codes (sharedNameProgram <>
    ["fn run() -> Str { Speak.label(1) }"])
  valueReceiver <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Speak.label(bot) }"])
  typeQualifiedAmbiguous <- codes (sharedNameProgram <>
    ["fn run(bot: Bot) -> Str { Bot.label(&bot) }"])
  pure $ conjoin
    [ counterexample "two traits may declare the same member" (declaring === [])
    , counterexample "a trait-qualified call selects one" (traitQualified === [])
    , counterexample "the other trait is equally selectable" (otherTrait === [])
    , counterexample "an unqualified call must choose" (unqualified === ["E3013"])
    , counterexample "a type-qualified call selects the implementation"
        (typeQualified === [])
    , counterexample "one provider needs no qualification" (singleProviderStillPlain === [])
    , counterexample "a qualified call still checks its receiver"
        (wrongReceiver === ["E3001"])
    , counterexample "a qualified call does not borrow for you"
        (valueReceiver === ["E3001"])
    , counterexample "the type-qualified form cannot choose either"
        (typeQualifiedAmbiguous === ["E3013"])
    ]

markerProgram :: [Text]
markerProgram =
  [ "module M"
  , "type Point = { x: Int, y: Int }"
  , "type Handle = { label: Str }"
  , "type Choice = | Yes | No | Amount(Int)"
  , "fn copies[T: Copy](value: T) -> T { value }"
  , "fn sends[T: Send](value: T) -> T { value }"
  , "fn shares[T: Sync](value: T) -> T { value }"
  ]

testMarkers :: IO Property
testMarkers = do
  scalars <- codes (markerProgram <>
    [ "fn run() -> Int { copies(1) }"
    , "fn float() -> Float64 { copies(1.5) }"
    , "fn flag() -> Bool { copies(true) }"
    , "fn letter() -> Char { copies('a') }"
    ])
  aggregates <- codes (markerProgram <>
    [ "fn pair() -> (Int, Bool) { copies((1, true)) }"
    , "fn record() -> Point { copies(Point{x: 1, y: 2}) }"
    , "fn variant() -> Choice { copies(Amount(3)) }"
    ])
  sharedBorrow <- codes (markerProgram <> ["fn run(p: Point) -> &Point { copies(&p) }"])
  ownedText <- codes (markerProgram <> ["fn run() -> Str { copies(\"owned\") }"])
  owningRecord <- codes (markerProgram <> ["fn run(h: Handle) -> Handle { copies(h) }"])
  exclusiveBorrow <- codes (markerProgram <> ["fn run(p: Point) -> &mut Point { copies(&mut p) }"])
  collection <- codes (markerProgram <> ["fn run(xs: Array[Int]) -> Array[Int] { copies(xs) }"])
  sendableText <- codes (markerProgram <> ["fn run() -> Str { sends(\"text\") }"])
  sharedText <- codes (markerProgram <> ["fn run() -> Str { shares(\"text\") }"])
  sendableCollection <- codes (markerProgram <>
    ["fn run(xs: Array[Int]) -> Array[Int] { sends(xs) }"])
  userCopyImpl <- codes
    [ "module M"
    , "type Point = { x: Int }"
    , "trait Copy { fn dummy(self: &Self) -> Int }"
    , "impl Copy for Point {"
    , "  fn dummy(self: &Self) -> Int { self.x }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "every scalar copies" (scalars === [])
    , counterexample "an aggregate of copyable components copies" (aggregates === [])
    , counterexample "a shared borrow copies" (sharedBorrow === [])
    , counterexample "owned text does not copy" (ownedText === ["E3012"])
    , counterexample "a record holding text does not copy" (owningRecord === ["E3012"])
    , counterexample "an exclusive borrow never copies" (exclusiveBorrow === ["E3012"])
    , counterexample "a growable collection does not copy" (collection === ["E3012"])
    , counterexample "text crosses into a task" (sendableText === [])
    , counterexample "text is shareable" (sharedText === [])
    , counterexample "a collection of sendable elements is sendable"
        (sendableCollection === [])
    , counterexample "Copy cannot be implemented by hand" (userCopyImpl === ["E3021"])
    ]

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

{-| A built-in collection method answers with a new collection, so writing one
    as a statement does nothing at all — silently. The warning fires there and
    nowhere else: assigning the result back is correct, and discarding the
    answer to a question is merely pointless. -}
{-| Text carries a closed set of methods the compiler knows the semantics of,
    so each is typed exactly and an unknown one is reported rather than
    dispatched. -}
{-| A match reads its subject; it does not consume it. Looking through a borrow
    is what lets a function take `&Option[T]` and still match on it, which every
    generic helper in the standard library needs. -}
{-| A literal is checked exactly like a declaration's body, and answers with
    the function type a caller sees. Its parameter types are inferred from the
    place it is used, which is what makes `items.map(fn(x) => x + 1)` readable
    without annotations. -}
{-| A tuple's members have different types, so the position must be known when
    the type is decided. It was not: `(Int, Str)[1]` reported `Int` while the
    value was text, which is a type the checker guaranteed and the program did
    not have. -}
{-| A map and a set are wired-in types with closed method vocabularies, typed
    exactly the way arrays and text are. -}
{-| An implementation is a fact about a type and a trait, true everywhere in a
    program once it exists anywhere in it. Scoping obligations to directly
    imported modules made a bounded generic unusable across modules. -}
{-| An alias is a synonym, so writing it is writing what it stands for. A
    generic one was left nominal and unified with nothing, which made a type
    like `Parser[T] = fn(Input) -> Step[T]` impossible to use. -}
testGenericAliases :: IO Property
testGenericAliases = do
  plain <- codes
    [ "module M", "type Count = Int"
    , "fn take(n: Count) -> Int { n }", "fn run() -> Int { take(3) }"
    ]
  generic <- codes
    [ "module M", "type Boxed[T] = Option[T]"
    , "fn make() -> Boxed[Int] { Some(2) }"
    , "fn run() -> Bool { match make() { case Some(_) => true \n case None => false } }"
    ]
  functionAlias <- codes
    [ "module M", "type Step[T] = Result[T, Str]", "type Rule[T] = fn(Int) -> Step[T]"
    , "fn digits() -> Rule[Int] { fn(n: Int) -> Step[Int] => Ok(n) }"
    ]
  wrongArity <- codes
    [ "module M", "type Boxed[T] = Option[T]", "fn make() -> Boxed { Some(2) }" ]
  pure $ conjoin
    [ counterexample "a plain alias stands for its type" (plain === [])
    , counterexample "a generic alias substitutes its argument" (generic === [])
    , counterexample "an alias may name a function type" (functionAlias === [])
    , counterexample "an alias written with the wrong count stays nominal"
        (wrongArity === ["E3001"])
    ]

testGlobalImpls :: IO Property
testGlobalImpls = do
  converting <- typeOf "convertInteger[UInt8](300)"
  tooMany <- codesOfExpression "convertInteger[UInt8, Int, Str](300)"
  notAName <- codesOfExpression "5[UInt8](300)"
  indexing <- typeOf "[1, 2][1]"
  shifting <- codesOfExpression "1u8 << 3"
  sameType <- codesOfExpression "1u8 << 3u8"
  prefixProduct <- codes
    [ "module M"
    , "fn run(a: &Int, b: &Int) -> Int { (*a) * (*b) }"
    ]
  prefixBare <- codes
    [ "module M"
    , "fn run(a: &Int, b: &Int) -> Int { *a * *b }"
    ]
  pure $ conjoin
    [ counterexample "a shift count is a plain Int" (shifting === [])
    , counterexample "a count of another integer type is refused, as every other conversion is"
        (sameType === ["E3001"])
    , counterexample "a parenthesised product of dereferences checks"
        (prefixProduct === [])
    , counterexample "an unparenthesised one checks the same way"
        (prefixBare === [])
    , counterexample "a type argument pins what inference cannot settle"
        (converting === "Option[UInt8]")
    , counterexample "too many type arguments is E3028" (tooMany === ["E3028"])
    , counterexample "an expression cannot carry type arguments" (notAName === ["E3028"])
    , counterexample "indexing is still indexing" (indexing === "Int")
    ]

testKeyedTypes :: IO Property
testKeyedTypes = do
  mapType <- typeOf "mapOf([(\"a\", 1)])"
  setType <- typeOf "setOf([1, 2])"
  lookupType <- typeOf "mapOf([(\"a\", 1)]).get(\"a\")"
  keysType <- typeOf "mapOf([(\"a\", 1)]).keys()"
  entriesType <- typeOf "mapOf([(\"a\", 1)]).entries()"
  membersType <- typeOf "setOf([1]).toArray()"
  unknownMap <- codesOfExpression "mapOf([(\"a\", 1)]).shout()"
  unknownSet <- codesOfExpression "setOf([1]).shout()"
  badKey <- codesOfExpression "mapOf([(\"a\", 1)]).get(1)"
  pure $ conjoin
    [ counterexample "a map is typed by key and value" (mapType === "Map[Str, Int]")
    , counterexample "a set is typed by its member" (setType === "Set[Int]")
    , counterexample "a lookup answers with an option" (lookupType === "Option[Int]")
    , counterexample "keys answer as an array" (keysType === "Array[Str]")
    , counterexample "entries answer as an array of pairs" (entriesType === "Array[(Str, Int)]")
    , counterexample "members answer as an array" (membersType === "Array[Int]")
    , counterexample "an unknown map method is E3005" (unknownMap === ["E3005"])
    , counterexample "an unknown set method is E3005" (unknownSet === ["E3005"])
    , counterexample "a key of the wrong type is E3001" (badKey === ["E3001"])
    ]

testTupleIndex :: IO Property
testTupleIndex = do
  firstMember <- typeOf "(1, \"x\")[0]"
  secondMember <- typeOf "(1, \"x\")[1]"
  computed <- codes
    ["module M", "fn run() -> Int {", "  var index = 1", "  (1, \"x\")[index]", "}"]
  beyond <- codesOfExpression "(1, \"x\")[5]"
  negative <- codesOfExpression "(1, \"x\")[-1]"
  arrayIndex <- typeOf "[1, 2][1]"
  pure $ conjoin
    [ counterexample "the first member has the first type" (firstMember === "Int")
    , counterexample "the second member has the second type" (secondMember === "Str")
    , counterexample "a computed position is E3027" (computed === ["E3027"])
    , counterexample "a position beyond the tuple is E3027" (beyond === ["E3027"])
    , counterexample "a negative position is E3027" (negative === ["E3027"])
    , counterexample "an array is still indexed by any expression" (arrayIndex === "Int")
    ]

testLambdaTypes :: IO Property
testLambdaTypes = do
  annotated <- typeOf "fn(n: Int) -> Int => n * 2"
  inferredUse <- typeOf "[1, 2].map(fn(n) => n * 2)"
  higherOrder <- codes
    [ "module M"
    , "fn apply(f: fn(Int) -> Int, n: Int) -> Int { f(n) }"
    , "fn run() -> Int { apply(fn(x) => x * 3, 7) }"
    ]
  returned <- codes
    [ "module M"
    , "fn adder(step: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + step }"
    ]
  wrongBody <- codesOfExpression "fn(n: Int) -> Int => \"text\""
  wrongArgument <- codes
    [ "module M"
    , "fn apply(f: fn(Int) -> Int) -> Int { f(1) }"
    , "fn run() -> Int { apply(fn(x: Str) -> Int => 1) }"
    ]
  pure $ conjoin
    [ counterexample "an annotated literal has its written type"
        (annotated === "fn(Int) -> Int")
    , counterexample "an unannotated literal is inferred from its use"
        (inferredUse === "Array[Int]")
    , counterexample "a literal satisfies a function parameter" (higherOrder === [])
    , counterexample "a literal may be returned" (returned === [])
    , counterexample "a body is checked against the declared result"
        (wrongBody === ["E3001"])
    , counterexample "a literal's own parameter type is checked at the call"
        (wrongArgument === ["E3001"])
    ]

testMatchThroughBorrow :: IO Property
testMatchThroughBorrow = do
  borrowed <- codes
    [ "module M"
    , "fn ask(value: &Option[Int]) -> Bool {"
    , "  match value {"
    , "    case Some(_) => true"
    , "    case None => false"
    , "  }"
    , "}"
    ]
  owned <- codes
    [ "module M"
    , "fn ask(value: Option[Int]) -> Bool {"
    , "  match value {"
    , "    case Some(_) => true"
    , "    case None => false"
    , "  }"
    , "}"
    ]
  stillExhaustive <- codes
    [ "module M"
    , "fn ask(value: &Option[Int]) -> Bool {"
    , "  match value {"
    , "    case Some(_) => true"
    , "  }"
    , "}"
    ]
  charCode <- typeOf "'a'.code()"
  unknownChar <- codesOfExpression "'a'.isDigit()"
  pure $ conjoin
    [ counterexample "a borrowed subject matches" (borrowed === [])
    , counterexample "an owned subject still matches" (owned === [])
    , counterexample "exhaustiveness is still checked through the borrow"
        (stillExhaustive === ["E5001"])
    , counterexample "a character answers for its code" (charCode === "Int")
    , counterexample "a character has no other method" (unknownChar === ["E3005"])
    ]

testTextMethods :: IO Property
testTextMethods = do
  lengthType <- typeOf "\"abc\".length()"
  charType <- typeOf "\"abc\".charAt(0)"
  sliceType <- typeOf "\"abc\".slice(0, 2)"
  splitType <- typeOf "\"a,b\".split(\",\")"
  charsType <- typeOf "\"ab\".chars()"
  emptyType <- typeOf "\"\".isEmpty()"
  unknown <- codesOfExpression "\"abc\".shout()"
  badArgument <- codesOfExpression "\"abc\".charAt(\"x\")"
  pure $ conjoin
    [ counterexample "length answers an integer" (lengthType === "Int")
    , counterexample "charAt answers a character" (charType === "Char")
    , counterexample "slice answers text" (sliceType === "Str")
    , counterexample "split answers an array of text" (splitType === "Array[Str]")
    , counterexample "chars answers an array of characters" (charsType === "Array[Char]")
    , counterexample "isEmpty answers a boolean" (emptyType === "Bool")
    , counterexample "an unknown text method is E3005" (unknown === ["E3005"])
    , counterexample "an argument is checked" (badArgument === ["E3001"])
    ]

testDiscardedResult :: IO Property
testDiscardedResult = do
  discarded <- codes
    ["module M", "fn run() -> Int {", "  var out = [1]", "  out.push(2)", "  5", "}"]
  assigned <- codes
    ["module M", "fn run() -> Int {", "  var out = [1]", "  out = out.push(2)", "  5", "}"]
  asked <- codes
    ["module M", "fn run() -> Int {", "  let out = [1]", "  out.contains(2)", "  5", "}"]
  reversedResult <- codes
    ["module M", "fn run() -> Int {", "  let out = [1]", "  out.reverse()", "  5", "}"]
  userMethod <- codes
    [ "module M"
    , "type Bag = { size: Int }"
    , "trait Fill { fn push(self: &Self, value: Int) -> Int }"
    , "impl Fill for Bag { fn push(self: &Self, value: Int) -> Int { value } }"
    , "fn run(bag: Bag) -> Int {"
    , "  bag.push(2)"
    , "  5"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "a discarded push is W3002" (discarded === ["W3002"])
    , counterexample "assigning the result back is correct" (assigned === [])
    , counterexample "discarding an answer is not warned about" (asked === [])
    , counterexample "a discarded reverse is W3002" (reversedResult === ["W3002"])
    , counterexample "a user method of the same name is not warned about" (userMethod === [])
    ]

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
  runCompile snapshot
