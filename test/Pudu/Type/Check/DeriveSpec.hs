{-| @Test.Type.Check.DeriveSpec — derive definitions check once, generically -}
module Pudu.Type.Check.DeriveSpec
  ( testDeriveChecked
  , testDeriveContracts
  , testDeriveLoopSources
  , testDeriveLoopBounds
  , testDeriveImportedContract
  , testDeriveSubstitution
  , testDeriveFixtures
  , testDeriveLoopChecked
  , testDeriveLoopMistakeOnce
  , testDeriveMistakeOnce
  , testDeriveRequestUnchecked
  ) where

import Pudu.Type.Check.Common (codes)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import Pudu.Compiler (FrontendResult (..), runFrontend)
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText)
import Pudu.Frontend.Syntax.Located (locatedValue)
import Pudu.Frontend.Syntax.Tree (Module (..), Capability (RawCapability))
import Pudu.Source (SourceName (..), newSource)
import Pudu.Type.Check (checkModuleWith)
import Pudu.Type.Interface (interfaceSkeleton)
import Pudu.Type.Interface.Graph (importsFor, prepareInterfaces)
import Pudu.Type.Substitute (substituteRigid)
import Pudu.Type.Value (Type (..), Required (..), capabilitiesOf, integerType, requiredCount)
import qualified Pudu.Compiler.Program.Common as Program
import Test.QuickCheck (Property, conjoin, counterexample, (===))

testDeriveContracts :: IO Property
testDeriveContracts = do
  checked <- traverse (\(label, input, expected) -> do
    found <- codes ("module M" : input)
    pure (counterexample label (found === expected))) cases
  pure (conjoin checked)
 where
  tag = "trait Tag { fn tag(self: &Self) -> Str }"
  cases =
    [ ("wrong receiver", [tag, "derive Tag for T: Record { fn tag(self: Bool) -> Str { \"tag\" } }"], ["E3091"])
    , ("wrong result", [tag, "derive Tag for T: Record { fn tag(self: &T) -> Int { 1 } }"], ["E3091"])
    , ("missing member", [tag, "derive Tag for T: Record {}"], ["E3091"])
    , ("extra member", [tag, "derive Tag for T: Record { fn tag(self: &T) -> Str { \"tag\" } fn extra() -> Int { 1 } }"], ["E3091"])
    , ("duplicate member", [tag, "derive Tag for T: Record { fn tag(self: &T) -> Str { \"a\" } fn tag(self: &T) -> Str { \"b\" } }"], ["E3091"])
    , ("default omitted", ["trait Tag { fn tag(self: &Self) -> Str = \"tag\" }", "derive Tag for T: Record {}"], [])
    , ("non-trait head", ["type Tag = Int", "derive Tag for T: Record {}"], ["E3091"])
    , ("bad trait arity", ["trait Tag[A] {}", "derive Tag for T: Record {}"], ["E3091"])
    , ("generic trait", ["trait Holds[A] { fn get(self: &Self) -> A }", "derive Holds[Int] for T: Record { fn get(self: &T) -> Int { 0 } }"], [])
    , ("alpha-renamed method", ["trait Echo { fn echo[A](self: &Self, x: A) -> A }", "derive Echo for T: Record { fn echo[B](self: &T, x: B) -> B { x } }"], [])
    , ("stronger method bound", ["trait Extra {}", "trait Echo { fn echo[A](self: &Self, x: A) -> A }", "derive Echo for T: Record { fn echo[B: Extra](self: &T, x: B) -> B { x } }"], ["E3091"])
    , ("duplicate shape", [tag, "derive Tag for T: Record { fn tag(self: &T) -> Str { \"a\" } }", "derive Tag for V: Record { fn tag(self: &V) -> Str { \"b\" } }"], ["E3091"])
    , ("shape overload", [tag, "derive Tag for T: Record { fn tag(self: &T) -> Str { \"a\" } }", "derive Tag for V: Sum { fn tag(self: &V) -> Str { \"b\" } }"], [])
    , ("wrong borrow mutability", [tag, "derive Tag for T: Record { fn tag(self: &mut T) -> Str { \"tag\" } }"], ["E3091"])
    , ("wrong asyncness", ["trait Tag { async fn tag(self: &Self) -> Str }", "derive Tag for T: Record { fn tag(self: &T) -> Str { \"tag\" } }"], ["E3091"])
    , ("wrong method kind", ["trait Echo { fn echo[F[_]](self: &Self, x: F[Int]) -> F[Int] }", "derive Echo for T: Record { fn echo[B](self: &T, x: B) -> B { x } }"], ["E3091"])
    , ("nested function contract", ["trait Echo { fn echo[A](self: &Self, each: fn(A) -> A) -> fn(A) -> A }", "derive Echo for T: Record { fn echo[B](self: &T, each: fn(B) -> B) -> fn(B) -> B { each } }"], [])
    ]

testDeriveLoopSources :: IO Property
testDeriveLoopSources = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record { fn tag(self: &T) -> Str {"
    , "  comptime for x: Int in [true] { let held: Int = x }"
    , "  \"tag\""
    , "} }"
    ]
  pure $ counterexample "source mismatch once, without binder cascades" (found === ["E3001"])

testDeriveLoopBounds :: IO Property
testDeriveLoopBounds = do
  nested <- codes (header <>
    [ "derive Tag for T: Record { fn tag(self: &T) -> Str {"
    , "  comptime for x: F in [] where F: Tag {"
    , "    comptime for y: G in [] where G: Tag { let held = need(&x) }"
    , "    let held = need(&x)"
    , "  }"
    , "  \"tag\""
    , "} }"
    ])
  earlier <- codes (header <>
    [ "derive Tag for T: Record { fn tag(self: &T) -> Str {"
    , "  let held = need(self)"
    , "  comptime for x: Int in [] where T: Tag {}"
    , "  \"tag\""
    , "} }"
    ])
  pure $ conjoin [nested === [], counterexample "later assumptions cannot prove earlier calls" (earlier === ["E3012"])]
 where
  header = ["module M", "trait Tag { fn tag(self: &Self) -> Str }", "fn need[A: Tag](x: &A) -> Str { x.tag() }"]

testDeriveImportedContract :: IO Property
testDeriveImportedContract = do
  library <- parsed "module Library\nexport trait Holds[A] { fn get(self: &Self) -> A }\nexport trait Default { fn value(self: &Self) -> Int = 1 }\n"
  consumer <- parsed "module Consumer\nimport Library as L\nderive L.Holds[Int] for T: Record { fn get(self: &T) -> Int { 1 } }\nderive L.Default for T: Record {}\n"
  bad <- parsed "module Consumer\nimport Library as L\nderive L.Holds[Int] for T: Record { fn get(self: &T) -> Str { \"bad\" } }\n"
  pure $ case (library, consumer, bad) of
    (Just interface, Just good, Just wrong) ->
      let graph = prepareInterfaces (Map.singleton (locatedValue (moduleName interface)) (interfaceSkeleton interface))
          check value = map (diagnosticCodeText . diagnosticCode)
            (snd (checkModuleWith (importsFor graph value) Set.empty value))
       in conjoin [check good === [], check wrong === ["E3091"]]
    _ -> counterexample "imported contract fixture parses" False
 where
  parsed :: Text -> IO (Maybe Module)
  parsed input = frontendModule . runFrontend <$> newSource (SourceName "contract.pudu") input

testDeriveSubstitution :: IO Property
testDeriveSubstitution = pure $ case substituteRigid [("T", integerType), ("F", NominalType "Option" [])]
  (RestrictedType (capabilitiesOf [RawCapability])
    (FunctionTypeRequiring False [RigidType "T", RigidType "T"] (Required 1)
      (AppliedType (RigidType "F") [RigidType "T"]))) of
    RestrictedType capabilities (FunctionTypeRequiring False inputs required result) -> conjoin
      [ capabilities === capabilitiesOf [RawCapability]
      , inputs === [integerType, integerType]
      , requiredCount required === 1
      , result === NominalType "Option" [integerType]
      ]
    other -> counterexample (show other) False

testDeriveChecked :: IO Property
testDeriveChecked = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str { \"tag\" }"
    , "}"
    ]
  pure $ counterexample "a sound derive checks clean" (found === [])

testDeriveMistakeOnce :: IO Property
testDeriveMistakeOnce = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str { 1 }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "one diagnostic" (length found === 1)
    , counterexample "a mismatch, not a cascade" (found === ["E3001"])
    ]

testDeriveLoopChecked :: IO Property
testDeriveLoopChecked = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str {"
    , "    var out = \"\""
    , "    comptime for x: Int in [1, 2] {"
    , "      out = out"
    , "    }"
    , "    out"
    , "  }"
    , "}"
    ]
  pure $ counterexample "a sound loop checks clean" (found === [])

testDeriveLoopMistakeOnce :: IO Property
testDeriveLoopMistakeOnce = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record {"
    , "  fn tag(self: &T) -> Str {"
    , "    var out = \"\""
    , "    comptime for x: Int in [1, 2] {"
    , "      out = 1"
    , "    }"
    , "    out"
    , "  }"
    , "}"
    ]
  pure $ conjoin
    [ counterexample "one diagnostic" (length found === 1)
    , counterexample "reported at the loop body" (found === ["E3001"])
    ]

testDeriveRequestUnchecked :: IO Property
testDeriveRequestUnchecked = do
  found <- codes
    [ "module M"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive impl Tag for Line"
    , "type Line = { sku: Str }"
    ]
  pure $ counterexample "a request needs no checking" (found === [])

testDeriveFixtures :: IO Property
testDeriveFixtures = do
  main <- Program.codes "test-fixtures/derive/Main.pudu"
  mainResult <- Program.runEntry "test-fixtures/derive/Main.pudu"
  mistake <- Program.codes "test-fixtures/derive/Mistake.pudu"
  loopMistake <- Program.codes "test-fixtures/derive/LoopMistake.pudu"
  ordinary <- Program.codes "test-fixtures/derive/OrdinaryLoop.pudu"
  badClauses <- Program.codes "test-fixtures/derive/BadClauses.pudu"
  unknown <- Program.codes "test-fixtures/derive/UnknownNames.pudu"
  sums <- Program.codes "test-fixtures/derive/SumShapes.pudu"
  sumsResult <- Program.runEntry "test-fixtures/derive/SumShapes.pudu"
  scalar <- Program.codes "test-fixtures/derive/ScalarAlias.pudu"
  pure $ conjoin
    [ counterexample "valid program checks clean" (main === [])
    , counterexample "valid program runs" (mainResult === Just "\"tagrrtagrrsum\"")
    , counterexample "body mistake once" (mistake === ["E3001"])
    , counterexample "loop mistake once" (loopMistake === ["E3001"])
    , counterexample "ordinary loop refused" (ordinary === ["E3090"])
    , counterexample "each clause mistake once" (badClauses === ["E1064", "E1066", "E1065", "E1067", "E1068"])
    , counterexample "unknown names resolve nowhere" (unknown === ["E2011", "E2011", "E2011"])
    , counterexample "sums check clean" (sums === [])
    , counterexample "scalar alias refused" (scalar === ["E3091"])
    , counterexample "sums run" (sumsResult === Just "\"Shape:sumOther:sum\"")
    ]
