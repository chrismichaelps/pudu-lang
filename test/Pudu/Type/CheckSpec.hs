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
  , ("trait methods dispatch on the receiver type", testTraits)
  , ("trait default bodies call other trait methods on Self", testTraitDefaultCalls)
  , ("matches are checked for coverage and reachability", testExhaustiveness)
  , ("trait bounds are proved at the call site", testBounds)
  , ("ambiguous trait method dispatch reports E3013", testAmbiguousMethod)
  , ("duplicate trait implementation heads are rejected", testCoherence)
  , ("Float aliases to Float64 at the type level", testFloatAlias)
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
