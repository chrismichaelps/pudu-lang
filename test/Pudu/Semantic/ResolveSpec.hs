module Pudu.Semantic.ResolveSpec (resolveProperties) where

import Data.List (sort)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticRelated)
import Pudu.Semantic (Resolution (..), Symbol (..))
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

resolveProperties :: [(String, IO Property)]
resolveProperties =
  [ ("module declarations resolve regardless of order", testOrderIndependence)
  , ("wired-in types resolve without an import", testBuiltins)
  , ("the prelude is implicitly imported and explicitly replaceable", testPrelude)
  , ("locals bind after their initializer", testBindingOrder)
  , ("parameters and defaults resolve left to right", testParameters)
  , ("duplicate declarations report E2001 with the first span", testDuplicates)
  , ("unresolved names report E2010 and E2011", testUnresolved)
  , ("generic parameters and Self resolve inside their declaration", testGenerics)
  , ("patterns bind names for their arm only", testPatterns)
  , ("shadowing warns only for the documented origins", testShadowing)
  , ("imports bind external names in both namespaces", testImports)
  , ("exports list only public module declarations", testExports)
  , ("a parse error suppresses resolution entirely", testParseErrorGate)
  ]

testOrderIndependence :: IO Property
testOrderIndependence = do
  result <- resolve
    [ "module M"
    , "fn first() -> Int { second() }"
    , "fn second() -> Int { MAX }"
    , "const MAX: Int = 1"
    ]
  pure $ conjoin
    [ codes result === []
    , counterexample "every name resolved" (referenceCount result === 5)
    ]

testBuiltins :: IO Property
testBuiltins = do
  result <- resolve
    [ "module M"
    , "fn sizes(a: Int64, b: Str, c: Option[Bool]) -> Int64 { a }"
    ]
  unknown <- resolve
    [ "module M"
    , "fn missing(a: List) -> Int { a }"
    ]
  pure $ conjoin
    [ codes result === []
    , counterexample "library types are not builtin" (codes unknown === ["E2011"])
    ]

testPrelude :: IO Property
testPrelude = do
  implicit <- resolve
    [ "module M"
    , "fn stop[T: Send](value: T) -> Never { panic(value) }"
    ]
  shadowed <- resolve
    [ "module M"
    , "trait Send {"
    , "  fn send(self: &Self) -> Bool"
    , "}"
    , "fn use[T: Send](value: T) -> Bool { true }"
    ]
  suppressed <- resolve
    [ "module M"
    , "import Core.Prelude {Drop}"
    , "fn stop[T: Send](value: T) -> Bool { true }"
    ]
  explicit <- resolve
    [ "module M"
    , "import Core.Prelude {Send}"
    , "fn stop[T: Send](value: T) -> Bool { true }"
    ]
  pure $ conjoin
    [ counterexample "prelude names resolve implicitly" (codes implicit === [])
    , counterexample "a module may declare its own version silently"
        (codes shadowed === [])
    , counterexample "an explicit prelude import suppresses the implicit one"
        (codes suppressed === ["E2011"])
    , counterexample "an explicit prelude import supplies what it names"
        (codes explicit === [])
    ]

testBindingOrder :: IO Property
testBindingOrder = do
  selfReference <- resolve
    [ "module M"
    , "fn run() -> Int {"
    , "  let value = value"
    , "  value"
    , "}"
    ]
  sequential <- resolve
    [ "module M"
    , "fn run() -> Int {"
    , "  let first = 1"
    , "  let second = first"
    , "  second"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "an initializer cannot see its own binding"
        (codes selfReference === ["E2010"])
    , codes sequential === []
    ]

testParameters :: IO Property
testParameters = do
  forward <- resolve
    [ "module M"
    , "fn ok(a: Int, b: Int = a) -> Int { b }"
    ]
  backward <- resolve
    [ "module M"
    , "fn bad(a: Int = b, b: Int) -> Int { a }"
    ]
  pure $ conjoin
    [ counterexample "a default sees earlier parameters" (codes forward === [])
    , counterexample "a default cannot see later parameters" (codes backward === ["E2010"])
    ]

testDuplicates :: IO Property
testDuplicates = do
  moduleLevel <- resolve
    [ "module M"
    , "fn run() -> Int { 1 }"
    , "fn run() -> Int { 2 }"
    ]
  blockLevel <- resolve
    [ "module M"
    , "fn run() -> Int {"
    , "  let a = 1"
    , "  let a = 2"
    , "  a"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "module duplicate" (codes moduleLevel === ["E2001"])
    , counterexample "the first declaration is attached" (relatedCount moduleLevel === 1)
    , counterexample "block duplicate is a redeclaration in one frame"
        (codes blockLevel === ["E2001"])
    ]

testUnresolved :: IO Property
testUnresolved = do
  value <- resolve
    [ "module M"
    , "fn run() -> Int { missing }"
    ]
  typeName <- resolve
    [ "module M"
    , "fn run() -> Missing { 1 }"
    ]
  pure $ conjoin
    [ codes value === ["E2010"]
    , codes typeName === ["E2011"]
    ]

testGenerics :: IO Property
testGenerics = do
  generic <- resolve
    [ "module M"
    , "fn identity[T](value: T) -> T { value }"
    ]
  leaked <- resolve
    [ "module M"
    , "fn identity[T](value: T) -> T { value }"
    , "fn other(value: T) -> Int { 1 }"
    ]
  traitSelf <- resolve
    [ "module M"
    , "trait Show {"
    , "  fn show(self: &Self) -> Str"
    , "}"
    ]
  pure $ conjoin
    [ codes generic === []
    , counterexample "a generic parameter does not leak" (codes leaked === ["E2011"])
    , counterexample "Self is bound inside a trait" (codes traitSelf === [])
    ]

testPatterns :: IO Property
testPatterns = do
  armScoped <- resolve
    [ "module M"
    , "type Outcome = Ok(Int) | Err(Str)"
    , "fn run(value: Outcome) -> Int {"
    , "  match value {"
    , "    case Outcome.Ok(inner) => inner"
    , "    case Outcome.Err(_) => 0"
    , "  }"
    , "}"
    ]
  leaked <- resolve
    [ "module M"
    , "type Outcome = Ok(Int) | Err(Str)"
    , "fn run(value: Outcome) -> Int {"
    , "  match value {"
    , "    case Outcome.Ok(inner) => inner"
    , "    case Outcome.Err(_) => 0"
    , "  }"
    , "  inner"
    , "}"
    ]
  iteration <- resolve
    [ "module M"
    , "fn run(items: Option[Int]) -> Int {"
    , "  for item in items {"
    , "    let doubled = item"
    , "  }"
    , "  0"
    , "}"
    ]
  pure $ conjoin
    [ codes armScoped === []
    , counterexample "an arm binding does not escape" (codes leaked === ["E2010"])
    , codes iteration === []
    ]

testShadowing :: IO Property
testShadowing = do
  immutable <- resolve
    [ "module M"
    , "fn run() -> Int {"
    , "  let value = 1"
    , "  {"
    , "    let value = 2"
    , "    value"
    , "  }"
    , "}"
    ]
  parameter <- resolve
    [ "module M"
    , "fn run(value: Int) -> Int {"
    , "  {"
    , "    let value = 2"
    , "    value"
    , "  }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "immutable shadowing is silent" (codes immutable === [])
    , counterexample "shadowing a parameter warns" (codes parameter === ["W2001"])
    ]

testImports :: IO Property
testImports = do
  aliased <- resolve
    [ "module M"
    , "import Core.Io as Io"
    , "fn run() -> Int { Io.read() }"
    ]
  selected <- resolve
    [ "module M"
    , "import Core.Text {Builder, trim}"
    , "fn run(value: Builder) -> Int { trim(value) }"
    ]
  conflicting <- resolve
    [ "module M"
    , "import Core.Text {trim}"
    , "fn trim() -> Int { 1 }"
    ]
  pure $ conjoin
    [ codes aliased === []
    , counterexample "a selection binds both namespaces" (codes selected === [])
    , counterexample "an import collides with a declaration" (codes conflicting === ["E2001"])
    ]

testExports :: IO Property
testExports = do
  result <- resolve
    [ "module M"
    , "export const PUBLIC: Int = 1"
    , "const PRIVATE: Int = 2"
    , "export fn shown() -> Int { 1 }"
    , "fn hidden() -> Int { 2 }"
    , "export type Shape = { side: Int }"
    ]
  pure (exportNames result === sort ["PUBLIC", "shown", "Shape"])

testParseErrorGate :: IO Property
testParseErrorGate = do
  result <- compile ["module M", "fn broken( {"]
  pure $ conjoin
    [ counterexample "no resolution runs" (property (compileResolution result == Nothing))
    , counterexample "no semantic diagnostics"
        (property (all isParseCode (compileDiagnostics result)))
    ]

isParseCode :: Diagnostic -> Bool
isParseCode value = Text.isPrefixOf "E1" (diagnosticCodeText (diagnosticCode value))

resolve :: [Text] -> IO (Resolution, [Diagnostic])
resolve inputLines = do
  result <- compile inputLines
  pure (maybe emptyResolution id (compileResolution result), compileDiagnostics result)

emptyResolution :: Resolution
emptyResolution =
  Resolution{resolutionSymbols = [], resolutionReferences = [], resolutionExports = []}

compile :: [Text] -> IO CompileResult
compile inputLines = do
  source <- newSource (SourceName "resolve.pudu") (Text.unlines inputLines)
  runCompile source

codes :: (Resolution, [Diagnostic]) -> [Text]
codes (_, diagnostics) = map (diagnosticCodeText . diagnosticCode) diagnostics

relatedCount :: (Resolution, [Diagnostic]) -> Int
relatedCount (_, diagnostics) = sum (map (length . diagnosticRelated) diagnostics)

referenceCount :: (Resolution, [Diagnostic]) -> Int
referenceCount (resolution, _) = length (resolutionReferences resolution)

exportNames :: (Resolution, [Diagnostic]) -> [Text]
exportNames (resolution, _) = sort (map symbolName (resolutionExports resolution))
