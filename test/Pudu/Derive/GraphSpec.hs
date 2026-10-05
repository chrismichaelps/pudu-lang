{-| @Test.Derive.GraphSpec — actual loaded-program generated evidence and execution. -}
module Pudu.Derive.GraphSpec (deriveGraphProperties) where

import Control.Exception (finally)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileContext (..), CompileResult (..))
import Pudu.Compiler.Program
  ( ProgramResult (..), compileProgram, programDependencies, programIntegerKinds, rootCompileResult )
import Pudu.Diagnostic
  ( diagnosticCode, diagnosticCodeText, diagnosticMessage, diagnosticRelated, hasErrors )
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree (Declaration (..), Module (..))
import Pudu.Source (spanOrigin)
import Pudu.Type.Env (DeclaredTypes (..))
import Pudu.Type.Interface.Graph (graphDeclared)
import Pudu.Type.Implementation (ImplementationRule (..))
import Pudu.Type.Value (Type (..), nominalKey)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

deriveGraphProperties :: [(String, IO Property)]
deriveGraphProperties =
  [ ("derive graph preserves definition captures and canonical targets", captures)
  , ("derive graph publishes nested conditional heads before callers", conditional)
  , ("derive graph residualizes all Sum payload shapes in definition scope", sums)
  , ("derive graph refuses author field ownership and overlap errors once", refusals)
  ]

captures :: IO Property
captures = conjoin <$> sequence
  [ run "cross-module private captures"
      [ ("Strategy", "module Strategy\nimport Std.Meta\nexport trait Label {fn label(self: &Self) -> Str}\nconst PREFIX: Str = \"private:\"\nfn wire() -> Str = PREFIX\nexport derive Label for T: Record {fn label(self: &T) -> Str = wire() + Meta.nameOf[T]()}\n")
      , ("Main", "module Main\nimport Strategy {Label}\nconst PREFIX: Str = \"consumer:\"\nfn wire() -> Str = PREFIX\ntype Sample = {id: Int} derives Label\nfn main() -> Str {let value = Sample{id: 1}\nvalue.label()}\n")
      ] "\"private:Sample\""
  , run "transitive inferred private captures"
      [ ("Strategy", "module Strategy\nimport Std.Meta\nexport trait Label {fn label(self: &Self) -> Str}\nconst PREFIX = \"inferred:\"\nfn wire() = leaf()\nfn leaf() = PREFIX\nexport derive Label for T: Record {fn label(self: &T) -> Str = wire() + Meta.nameOf[T]()}\n")
      , ("Main", "module Main\nimport Strategy {Label}\nfn wire() -> Str = \"consumer\"\ntype Sample = {} derives Label\nfn main() -> Str {let value = Sample{}\nvalue.label()}\n")
      ] "\"inferred:Sample\""
  , run "canonical external alias application"
      [ ("Target", "module Target\nexport type Box[A] = {value: A}\n")
      , ("Strategy", "module Strategy\nimport Std.Meta\nimport Target\nexport trait Label {fn label(self: &Self) -> Str}\nexport derive Label for T: Record {fn label(self: &T) -> Str = Meta.nameOf[T]()}\ntype Alias = Target.Box[Int]\nderive impl Label for Alias\n")
      , ("Main", "module Main\nimport Strategy {Label}\nimport Target\nfn main() -> Str {let value: Target.Box[Int] = Target.Box{value: 1}\nvalue.label()}\n")
      ] "\"Box\""
  ]

sums :: IO Property
sums = run "unit positional named generic and attributed variants"
  [ ("Strategy", Text.unlines
      [ "module Strategy", "import Std.Meta"
      , "export trait Report {fn report(self: &Self) -> Str}"
      , "export derive Report for T: Sum {fn report(self: &T) -> Str {"
      , "var out = \"\""
      , "comptime for variant: Meta.Variant[T] in Meta.variants[T]() {"
      , "if variant.matches(self) {"
      , "out = variant.attributeOr(\"wire\", variant.name) + \":\" + variant.index.toText()"
      , "comptime for field: Meta.Field[T, F] in variant.fields() {"
      , "if !field.has(\"skip\") {out = out + \"|\" + field.name + \"=\" + field.get(self).toText()}"
      , "}", "}", "}", "out", "}}" ])
  , ("Main", Text.unlines
      [ "module Main", "import Strategy {Report}"
      , "type Value = Empty | Pair(Int, Str) | @wire(\"record\") Named{@skip cache: Bool, id: Int} derives Report"
      , "type Choice[A] = Missing | Present(A) derives Report"
      , "fn main() -> Str {"
      , "let empty = Value.Empty", "let pair = Value.Pair(3, \"x\")"
      , "let named = Value.Named{cache: true, id: 7}"
      , "let choice: Choice[Int] = Choice.Present(9)"
      , "empty.report() + \";\" + pair.report() + \";\" + named.report() + \";\" + choice.report()"
      , "}" ])
  ] "\"Empty:0;Pair:1|0=3|1=x;record:2|id=7;Present:1|0=9\""

conditional :: IO Property
conditional = withProgram
  [ ("Main", "module Main\nimport Std.Meta\n" <> total <>
      "\ntype Box[T] = {value: T} derives Total\ntype Wrapper[F] = {value: Box[F]} derives Total\nfn main() -> Int {let value: Wrapper[Int] = Wrapper{value: Box{value: 9}}\nvalue.total()}\n")
  ] $ \result -> do
    output <- outputs result
    let rules = [(nominalKey owner, implementationRequirements rule)
          | ((owner, trait), values) <- Map.toList (declaredImpls (graphDeclared (contextTypes (programContext result))))
          , nominalKey trait == "Main.Total", rule <- values]
        expected name parameter = property (any (\(owner, bounds) -> owner == name
          && any (\(subject, bound) -> subject == RigidType parameter && case bound of
            NominalType trait [] -> nominalKey trait == "Main.Total"
            _ -> False) bounds) rules)
        generated = [at | compiled <- Map.elems (programModules result)
          , Just unit <- [compileModule compiled], Located at (ImplDeclaration _) <- moduleDeclarations unit
          , spanOrigin at /= Nothing]
    pure $ counterexample (show (programDiagnostics result, rules)) $ conjoin
      [ output === [(Just "9", []), (Just "9", [])]
      , expected "Main.Box" "T", expected "Main.Wrapper" "F"
      , length generated === 2
      ]
 where
  total = Text.unlines
    [ "trait Total {fn total(self: &Self) -> Int}"
    , "impl Total for Int {fn total(self: &Self) -> Int = *self}"
    , "derive Total for T: Record {fn total(self: &T) -> Int {"
    , "var result = 0"
    , "comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Total {result = result + field.get(self).total()}"
    , "result", "}}"
    ]

refusals :: IO Property
refusals = conjoin <$> mapM one
  [ ("definition once", [local "derive Label for T: Record {fn label(self: &T) -> Str = false}\ntype A = {} derives Label\ntype B = {} derives Label"], "E3001", 1)
  , ("inferred helper once", [local "fn wire() = leaf()\nfn leaf() = false\nderive Label for T: Record {fn label(self: &T) -> Str = wire()}\ntype A = {} derives Label\ntype B = {} derives Label"], "E3001", 1)
  , ("generated overlap", [local "derive Label for T: Record {fn label(self: &T) -> Str = \"value\"}\ntype A = {} derives Label\nimpl Label for A {fn label(self: &Self) -> Str = \"other\"}"], "E3015", 1)
  , ("private strategy", strategy <> [("Main", "module Main\nimport Strategy {Label}\ntype A = {} derives Label")], "E3091", 1)
  , ("orphan through alias", strategy <> [("Target", "module Target\nexport type A = {}"),
      ("Main", "module Main\nimport Strategy {Label}\nimport Target\ntype Alias = Target.A\nderive impl Label for Alias")], "E3014", 1)
  , ("unmet concrete field", [("Main", "module Main\nimport Std.Meta\ntrait Needed {fn needed(self: &Self) -> Int}\ntrait Total {fn total(self: &Self) -> Int}\nderive Total for T: Record {fn total(self: &T) -> Int {comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Needed {field.get(self).needed()}\n0}}\ntype A = {value: Int} derives Total")], "E3092", 1)
  ]
 where
  local body = ("Main", "module Main\ntrait Label {fn label(self: &Self) -> Str}\n" <> body)
  strategy = [("Strategy", "module Strategy\nexport trait Label {fn label(self: &Self) -> Str}\nderive Label for T: Record {fn label(self: &T) -> Str = \"private\"}")]
  one (label, sources, code, count) = withProgram sources $ \result -> do
    let errors = programDiagnostics result
        codes = map (diagnosticCodeText . diagnosticCode) errors
    pure $ counterexample (label <> ": " <> show errors) $ conjoin
      [ codes === replicate count code
      , property (all ((== Nothing) . compileModule) (Map.elems (programModules result)))
      , if code == "E3092" then property (all (not . null . diagnosticRelated) errors) else property True
      ]

run :: String -> [(Text, Text)] -> Text -> IO Property
run label sources expected = withProgram sources $ \result -> do
  output <- outputs result
  pure $ counterexample (label <> ": " <> show (programDiagnostics result))
    (output === [(Just expected, []), (Just expected, [])])

outputs :: ProgramResult -> IO [(Maybe Text, [Text])]
outputs result = case rootCompileResult result >>= compileModule of
  Nothing -> pure [(Nothing, map diagnosticMessage (programDiagnostics result))]
  Just unit | not (hasErrors (programDiagnostics result)) -> mapM (\mode -> inMode mode $ do
    outcome <- evaluateProgramEntry (programIntegerKinds result) (programDependencies result) "main" unit
    pure (renderValue <$> outcomeValue outcome, map diagnosticMessage (outcomeDiagnostics outcome))) ["tree", "compiled"]
  Just _ -> pure [(Nothing, map diagnosticMessage (programDiagnostics result))]

withProgram :: [(Text, Text)] -> (ProgramResult -> IO Property) -> IO Property
withProgram sources check = withSystemTempDirectory "pudu-derive-graph" $ \root -> do
  mapM_ (\(name, body) -> TextIO.writeFile (root </> Text.unpack name <> ".pudu") body) sources
  compileProgram (root </> "Main.pudu") >>= check

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
