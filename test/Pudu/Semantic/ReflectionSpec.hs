{-| @Test.Semantic.Reflection — metadata restrictions follow resolved bindings -}
module Pudu.Semantic.ReflectionSpec (reflectionProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Source (SourceName (..), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

reflectionProperties :: [(String, IO Property)]
reflectionProperties =
  [ ("reflection selections and values cannot reach runtime", restrictedForms)
  , ("reflection restrictions follow the selected namespace", independentNamespaces)
  , ("reflection value shadowing remains lexical", valueShadowing)
  , ("derive loop bounds reuse rigid identities", repeatedBounds)
  ]

restrictedForms :: IO Property
restrictedForms = do
  selected <- codes
    [ "import Std.Meta {nameOf}"
    , "fn run() -> Str { nameOf[Int]() }"
    ]
  held <- codes
    [ "import Std.Meta {nameOf}"
    , "fn run() -> () { let read = nameOf }"
    ]
  moduleValue <- codes
    [ "import Std.Meta as M"
    , "fn run() -> () { let metadata = M }"
    ]
  selectedType <- codes
    [ "import Std.Meta {Field}"
    , "fn run(value: Field[Int, Int]) -> Int { 0 }"
    ]
  pure $ conjoin
    [ counterexample label (found === ["E2018"])
    | (label, found) <-
        [("selected call", selected), ("held function", held),
         ("held module", moduleValue), ("selected type", selectedType)]
    ]

independentNamespaces :: IO Property
independentNamespaces = do
  found <- codes
    [ "import Std.Meta as M"
    , "fn run[M]() -> Str { M.nameOf[Int]() }"
    ]
  pure $ counterexample "the value import survives type-parameter shadowing"
    (filter (Text.isPrefixOf "E") found === ["E2018"])

valueShadowing :: IO Property
valueShadowing = do
  found <- codes
    [ "import Std.Meta {nameOf}"
    , "fn run(nameOf: Int) -> Int { nameOf }"
    ]
  pure $ counterexample "ordinary lexical value remains usable"
    (filter (Text.isPrefixOf "E") found === [])

repeatedBounds :: IO Property
repeatedBounds = do
  found <- codes
    [ "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str {"
    , "    comptime for x: Option[F] in [] where F: Tag, F: Tag, T: Tag {}"
    , "    \"tag\""
    , "  }"
    , "}"
    ]
  pure $ counterexample "loop scope augments rather than redeclares binders"
    (found === [])

codes :: [Text] -> IO [Text]
codes lines' = do
  source <- newSource (SourceName "reflection.pudu") (Text.unlines ("module M" : lines'))
  result <- runCompile source
  pure (map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result))
