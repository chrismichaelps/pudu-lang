{-| @Test.Type.ImplementationSpec — concrete conditional capability regressions. -}
module Pudu.Type.ImplementationSpec (implementationProperties) where

import Control.Monad (forM)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Program (ProgramResult (..), compileProgramSourceOver)
import Pudu.Doc (DocEntry (..), entriesFor)
import Pudu.Doc.Json (encodeIndex)
import Pudu.Doc.Signature (alphaNormalise, renderSignature)
import Pudu.Comptime.Limits (callDepthLimit, iterationLimit)
import Pudu.Diagnostic (diagnosticCode, diagnosticMessage, diagnosticSpan, diagnosticCodeText)
import Pudu.Source (SourceName (..), newSource, sourceText, spanStart, spanEnd, unOffset)
import Pudu.Type.Env
  ( DeclaredTypes (..), emptyDeclared, evalChecker, withDeclared, freshVariable, resolveVariable )
import Pudu.Type.Implementation (ImplementationRule (..))
import Pudu.Type.Proof (TraitProof (..), proveBound, inferBound)
import Pudu.Type.Value (Type (..), boolType, integerType)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

implementationProperties :: [(String, IO Property)]
implementationProperties =
  [ ("trait proof retains concrete conditional and specialized heads", testHeads)
  , ("trait proof gates dynamic widening by concrete conditions", testDynamic)
  , ("trait proof preserves imported canonical conditions", testImports)
  , ("trait proof distinguishes complete applications cycles markers and budgets", testProof)
  , ("trait proof retains scoped applications and method results", testApplications)
  , ("trait proof infers private evidence and backtracks without caller mutation", testEvidence)
  , ("trait proof infers only unique call arguments and preserves target owners", testInference)
  , ("trait proof keeps generic applications in documentation shapes", testBoundDocumentation)
  , ("trait proof preserves constructor capability bounds", testConstructors)
  ]

testHeads :: IO Property
testHeads = conjoin <$> mapM check
  [ ("parameter bound succeeds", box "[A: Ready]" "Box[A]" "Box{held: 1}", [])
  , ("parameter bound refuses", box "[A: Ready]" "Box[A]" "Box{held: true}", ["E3012"])
  , ("where bound succeeds", box "[A]" "Box[A] where A: Ready" "Box{held: 1}", [])
  , ("where bound refuses", box "[A]" "Box[A] where A: Ready" "Box{held: true}", ["E3012"])
  , ("specialized head succeeds", box "" "Box[Int]" "Box{held: 1}", [])
  , ("specialized head refuses", box "" "Box[Int]" "Box{held: true}", ["E3012"])
  , ("constructor-wide contract", box "" "Box" "Box{held: true}", [])
  , ("nested condition succeeds", nested "1", [])
  , ("nested condition refuses", nested "true", ["E3012"])
  , ("repeated parameter succeeds", pair "1", [])
  , ("repeated parameter refuses", pair "true", ["E3012"])
  , ("abstract bound is retained", abstract "A: Ready", [])
  , ("abstract bound is required", abstract "A", ["E3012"])
  , ("unselected rule parameter cannot capture caller", Text.unlines (prefix <>
        [ "impl[A: Ready] Container for Box {}"
        , "fn relay[A: Ready](held: A) -> Int = accept(Box{held: true})"
        , "fn main() -> Int = relay(1)"
        ]), ["E3012"])
  ]
 where
  check (label, input, expected) = do
    source <- newSource (SourceName "Probe.pudu") input
    result <- runCompile source
    let diagnostics = compileDiagnostics result
        codes = map (diagnosticCodeText . diagnosticCode) diagnostics
        selected at = Text.take (unOffset (spanEnd at) - unOffset (spanStart at))
          (Text.drop (unOffset (spanStart at)) (sourceText source))
    pure $ counterexample (label <> ": " <> show diagnostics) $ conjoin
      [ codes === expected
      , property (all (Text.isInfixOf "does not implement Container" . diagnosticMessage) diagnostics)
      , property (all ((== "accept") . selected . diagnosticSpan) diagnostics)
      ]
  prefix =
    [ "module Probe", "trait Ready {}", "trait Container {}"
    , "impl Ready for Int {}", "type Box[A] = {held: A}"
    , "fn accept[A: Container](held: A) -> Int = 1"
    ]
  box parameters target value = Text.unlines (prefix <>
    ["impl" <> parameters <> " Container for " <> target <> " {}"
    , "fn main() -> Int = accept(" <> value <> ")"])
  nested value = Text.unlines (prefix <>
    [ "impl[A: Ready] Ready for Box[A] {}"
    , "impl[A: Ready] Container for Box[A] {}"
    , "fn main() -> Int = accept(Box{held: Box{held: " <> value <> "}})"
    ])
  pair value = Text.unlines (prefix <>
    [ "type Pair[A, B] = {left: A, right: B}"
    , "impl[A] Container for Pair[A, A] {}"
    , "fn main() -> Int = accept(Pair{left: 1, right: " <> value <> "})"
    ])
  abstract parameter = Text.unlines (prefix <>
    [ "impl[A: Ready] Container for Box[A] {}"
    , "fn relay[" <> parameter <> "](held: A) -> Int = accept(Box{held: held})"
    , "fn main() -> Int = relay(1)"
    ])

testDynamic :: IO Property
testDynamic = conjoin <$> forM [False, True] (\valid -> do
  source <- newSource (SourceName "Probe.pudu") (Text.unlines
    [ "module Probe", "trait Ready {}", "trait Container {}"
    , "impl Ready for Int {}", "type Box[A] = {held: A}"
    , "impl[A: Ready] Container for Box[A] {}"
    , "fn main() -> dynamic Container = Box{held: " <> (if valid then "1" else "true") <> "}"
    ])
  result <- runCompile source
  pure $ counterexample (show (compileDiagnostics result)) $
    map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result)
      === if valid then [] else ["E3032"])

testImports :: IO Property
testImports = conjoin <$> forM [False, True] (\valid -> do
  let root = "/tmp/pudu-trait-proof-overlay"
      overlay = Map.fromList
        [ (root <> "/Contracts.pudu", Text.unlines
            ["module Contracts", "export trait Ready {}", "export trait Container {}", "impl Ready for Int {}"])
        , (root <> "/Holder.pudu", Text.unlines
            ["module Holder", "import Contracts as C", "export type Box[A] = {held: A}"
            , "impl[A: C.Ready] C.Container for Box[A] {}"])
        ]
  source <- newSource (SourceName "Main.pudu") (Text.unlines
    [ "module Main", "import Contracts {Container}", "import Holder {Box}"
    , "fn accept[A: Container](held: A) -> Int = 1"
    , "fn main() -> Int = accept(Box{held: " <> (if valid then "1" else "true") <> "})"
    ])
  result <- compileProgramSourceOver overlay root source
  pure $ counterexample (show (programDiagnostics result)) $
    map (diagnosticCodeText . diagnosticCode) (programDiagnostics result)
      === if valid then [] else ["E3012"])

testProof :: IO Property
testProof = do
  let boxed value = NominalType "Box" [value]
      ready = NominalType "Ready" []
      held = RigidType "A"
      rule requirements = ImplementationRule [("A", 0)] (boxed held) ready requirements
      decide rules target bound = evalChecker $ do
        withDeclared emptyDeclared{declaredImpls = Map.singleton ("Box", "Ready") rules}
        proveBound target bound
      circular = rule [(boxed held, ready)]
      generic = ImplementationRule [("A", 0)] (boxed held)
        (NominalType "Ready" [held]) []
      copyBound = rule [(held, NominalType "Copy" [])]
      mismatch = ImplementationRule [] (boxed boolType) ready []
      deep = foldr (const boxed) integerType [1 .. callDepthLimit]
      nested = foldr (const boxed) integerType [1 .. 1000 :: Int]
      decreasing = rule [(held, ready)]
      scalar = ImplementationRule [] integerType ready []
      nestedProof = evalChecker $ do
        withDeclared emptyDeclared{declaredImpls = Map.fromList
          [ (("Box", "Ready"), [decreasing]), (("Int", "Ready"), [scalar]) ]}
        proveBound nested ready
      sameSize =
        [ ImplementationRule [] (boxed integerType) ready [(boxed boolType, ready)]
        , ImplementationRule [] (boxed boolType) ready []
        ]
  pure $ conjoin
    [ decide [generic] (boxed integerType) (NominalType "Ready" [integerType]) === Proven
    , decide [generic] (boxed integerType) (NominalType "Ready" [boolType]) === Unproved
    , decide [circular] (boxed integerType) ready === Unproved
    , decide [circular, rule []] (boxed integerType) ready === Proven
    , decide [copyBound] (boxed integerType) ready === Proven
    , decide [copyBound] (boxed (NominalType "Str" [])) ready === Unproved
    , decide [rule []] deep ready === ProofLimit
    , decide (replicate iterationLimit mismatch) (boxed integerType) ready === ProofLimit
    , nestedProof === Proven
    , decide sameSize (boxed integerType) ready === Proven
    , decide [] ErrorType (NominalType "Copy" []) === Unproved
    ]


testApplications :: IO Property
testApplications = conjoin <$> mapM check cases
 where
  prefix = ["module Probe", "trait Holds[A] { fn get(self: &Self) -> A }"
    , "type Box = {held: Int}", "impl Holds[Int] for Box { fn get(self: &Self) -> Int = self.held }"
    , "fn need[Q: Holds[Int]](held: Q) -> Int = held.get()"]
  cases =
    [ ("concrete argument", prefix <> ["fn main() -> Int = need(Box{held: 1})"], [])
    , ("concrete wrong argument", prefix <>
        ["fn wrong[Q: Holds[Bool]](held: Q) -> Bool = held.get()"
        , "fn main() -> Bool = wrong(Box{held: 1})"], ["E3012"])
    , ("rigid argument retained", prefix <>
        ["fn relay[Q: Holds[Int]](held: Q) -> Int = need(held)"], [])
    , ("rigid wrong argument", prefix <>
        ["fn relay[Q: Holds[Bool]](held: Q) -> Int = need(held)"], ["E3012"])
    , ("qualified result", prefix <>
        ["fn relay[Q: Holds[Int]](held: Q) -> Int = Holds.get(&held)"], [])
    , ("wrong qualified result", prefix <>
        ["fn relay[Q: Holds[Int]](held: Q) -> Bool = Holds.get(&held)"], ["E3001"])
    , ("wrong method result", prefix <>
        ["fn relay[Q: Holds[Int]](held: Q) -> Bool = held.get()"], ["E3001"])
    , ("captured result", prefix <>
        ["fn relay[Q: Holds[Int]](held: Q) -> Int { let get = held.get\n get() }"], [])
    , ("wrong captured result", prefix <>
        ["fn relay[Q: Holds[Int]](held: Q) -> Bool { let get = held.get\n get() }"], ["E3001"])
    , ("enclosing trait application", ["module Probe"
        , "trait Holds[A] { fn get(self: &Self) -> A\n fn again(self: &Self) -> A = self.get() }"], [])
    , ("derive contract application", ["module Probe", "trait Wants[A] {}"
        , "trait Contract { fn value[Q: Wants[Int]](self: &Self, held: Q) -> Int }"
        , "derive Contract for T: Record { fn value[Q: Wants[Bool]](self: &T, held: Q) -> Int = 1 }"], ["E3091"])
    ]
  check (label, input, expected) = do
    source <- newSource (SourceName "Probe.pudu") (Text.unlines input)
    result <- runCompile source
    pure $ counterexample (label <> ": " <> show (compileDiagnostics result)) $
      map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result) === expected

testEvidence :: IO Property
testEvidence = do
  let boxed value = NominalType "Box" [value]
      witness = NominalType "Witness" []
      ready = NominalType "Ready" []
      carries value = NominalType "Carries" [value]
      state = RigidType "S"
      held = RigidType "Q"
      outer requirements = ImplementationRule [("S", 0), ("Q", 0)] (boxed held) ready requirements
      carried value = ImplementationRule [] witness (carries value) []
      nested = (held, carries state)
      copied = (state, NominalType "Copy" [])
      decide requirements inner = evalChecker $ do
        withDeclared emptyDeclared{declaredImpls = Map.fromList
          [ (("Box", "Ready"), [outer requirements]), (("Witness", "Carries"), inner) ]}
        proveBound (boxed witness) ready
      caller = evalChecker $ do
        withDeclared emptyDeclared{declaredImpls = Map.singleton ("Box", "Ready")
          [ImplementationRule [("A", 0)] (boxed (RigidType "A"))
            (NominalType "Ready" [RigidType "A"]) []]}
        unknown <- freshVariable
        proof <- proveBound (boxed integerType) (NominalType "Ready" [unknown])
        untouched <- case unknown of
          VariableType variable -> resolveVariable variable
          _ -> pure (Just unknown)
        pure (proof, untouched)
  pure $ conjoin
    [ decide [nested] [carried integerType] === Proven
    , decide [nested, copied] [carried (NominalType "Str" []), carried integerType] === Proven
    , decide [copied, nested] [carried integerType] === Proven
    , decide [nested, copied] [carried (NominalType "Str" [])] === Unproved
    , decide [nested] [] === Unproved
    , caller === (Unproved, Nothing)
    ]


testInference :: IO Property
testInference = do
  let prefix = ["module Probe", "trait Carries[A] {}", "trait Also[A] {}", "type Box = {}"
        , "impl Carries[Int] for Box {}"
        , "fn need[A, Q: Carries[A]](held: Q) -> Int = 1"]
      cases =
        [ ("unique bound-only argument", prefix <> ["fn main() -> Int = need(Box{})"], [])
        , ("ambiguous application", prefix <> ["impl Carries[Bool] for Box {}"
            , "fn main() -> Int = need(Box{})"], ["E3012"])
        , ("explicit application", prefix <> ["impl Carries[Bool] for Box {}"
            , "fn main() -> Int = need[Int](Box{})"], [])
        , ("shared application is consistent", prefix <> ["impl Also[Int] for Box {}"
            , "fn both[A, Q: Carries[A] + Also[A]](held: Q) -> Int = 1"
            , "fn main() -> Int = both(Box{})"], [])
        , ("shared application mismatch", prefix <> ["impl Also[Bool] for Box {}"
            , "fn both[A, Q: Carries[A] + Also[A]](held: Q) -> Int = 1"
            , "fn main() -> Int = both(Box{})"], ["E3012"])
        ]
  sourceChecks <- forM cases $ \(label, input, expected) -> do
    source <- newSource (SourceName "Probe.pudu") (Text.unlines input)
    result <- runCompile source
    pure $ counterexample (label <> ": " <> show (compileDiagnostics result)) $
      map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result) === expected
  let box = NominalType "Box" []
      carries value = NominalType "Carries" [value]
      rule value = ImplementationRule [] box (carries value) []
      probe rules unknownTarget = evalChecker $ do
        withDeclared emptyDeclared{declaredImpls = Map.singleton ("Box", "Carries") rules}
        unknown <- freshVariable
        (answer, proposals) <- inferBound
          (if unknownTarget then NominalType "Box" [unknown] else box) (carries unknown)
        untouched <- case unknown of
          VariableType variable -> resolveVariable variable
          _ -> pure (Just unknown)
        pure (answer, map snd proposals, untouched)
  pure $ conjoin (sourceChecks <>
    [ probe [rule integerType] False === (Proven, [integerType], Nothing)
    , probe [rule integerType, rule boolType] False === (ProofAmbiguous, [], Nothing)
    , probe [] False === (Unproved, [], Nothing)
    , probe [rule integerType] True === (Proven, [integerType], Nothing)
    ])


testBoundDocumentation :: IO Property
testBoundDocumentation = do
  source <- newSource (SourceName "Probe.pudu") (Text.unlines
    [ "module Probe", "trait Holds[A] { fn get(self: &Self) -> A }"
    , "fn first[A, Q: Holds[A]](held: Q) -> A = held.get()"
    , "fn second[B, R: Holds[B]](held: R) -> B = held.get()"
    ])
  result <- runCompile source
  let signature name = compileDocs result >>= \index -> case entriesFor name index of
        entry : _ -> docSignature entry
        _ -> Nothing
      first = signature "first"
      second = signature "second"
  pure $ counterexample (show (compileDiagnostics result)) $ conjoin
    [ property (null (compileDiagnostics result))
    , fmap alphaNormalise first === fmap alphaNormalise second
    , fmap renderSignature first === Just "Q -> A where Q: Probe.Holds[A]"
    , property (maybe False (Text.isInfixOf "Probe.Holds[A]" . encodeIndex) (compileDocs result))
    ]


testConstructors :: IO Property
testConstructors = conjoin <$> forM cases (\(input, expected) -> do
  source <- newSource (SourceName "Probe.pudu") (Text.unlines (prefix <> input))
  result <- runCompile source
  pure $ counterexample (show (compileDiagnostics result)) $
    map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result) === expected)
 where
  prefix =
    [ "module Probe", "trait Mapper[F[_]] { fn kept[A](self: &F[A]) -> F[A] }"
    , "impl Mapper[Array] for Array { fn kept[A](self: &Array[A]) -> Array[A] = *self }"
    , "trait Holds[A] { fn get(self: &Self) -> A }", "trait Has[A] {}"
    ]
  cases =
    [ (["fn through[F[_]: Mapper, A](held: &F[A]) -> F[A] = held.kept()"
        , "fn main() -> Array[Int] = through(&[1, 2])"], [])
    , (["fn through[F[_]: Mapper[F], A](held: &F[A]) -> F[A] = held.kept()"
        , "fn main() -> Array[Int] = through(&[1, 2])"], [])
    , (["fn through[F[_]: Mapper[Option], A](held: &F[A]) -> Int = 1"
        , "fn main() -> Int = through(&[1, 2])"], ["E3012"])
    , (["fn through[Q: Holds[A], A](held: Q) -> A = held.get()"], [])
    , (["fn through[A: Has[A]](held: A) -> Int = 1"], [])
    , (["fn through[Q: Holds[Missing]](held: Q) -> Int = 1"], ["E2011"])
    , (["fn through[A, A](held: A) -> Int = 1"], ["E2001"])
    ]
