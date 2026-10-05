{-| @Test.Derive.RecordSpec — checks and executes ordinary generated methods. -}
module Pudu.Derive.RecordSpec (recordResidualProperties) where

import Control.Exception (finally)
import Control.Monad (replicateM_)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler
  ( CompileResult (..), FrontendResult (..), compileFrontendWithDependencies, runFrontend )
import Pudu.Compiler.Program
  ( ProgramResult (..), compileProgram, programDependencies, programIntegerKinds )
import Pudu.Comptime.Limits (callDepthLimit, expansionNodeLimit, iterationLimit)
import Pudu.Derive.Record (instantiateRecord)
import Pudu.Derive.Reflection (reflectionReferences)
import Pudu.Derive.State
  ( ExpansionFailure (..), FieldObligation (..), iteration, runResidual, withinDepth )
import qualified Pudu.Derive.State as Residual
import Pudu.Diagnostic (diagnosticMessage, hasErrors)
import Pudu.Eval (EvalOutcome (..))
import Pudu.Eval.Program (evaluateProgramEntry)
import Pudu.Eval.Render (renderValue)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Name (moduleNameText)
import Pudu.Frontend.Syntax.Tree
  ( Declaration (..), Impl (..), Module (..), TypeSyntax (NamedType)
  , TypeDeclarationValue (..) )
import Pudu.Source (SourceName (SourceName), emptySpan, newSource, spanOrigin)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

recordResidualProperties :: [(String, IO Property)]
recordResidualProperties =
  [ ("derive record kernel generates ordinary metadata-free methods", testMetadata)
  , ("derive record kernel reads heterogeneous fields through user traits", testReads)
  , ("derive record kernel retains generic targets and lexical bindings", testScopes)
  , ("derive record kernel refuses shapes escapes and exhausted budgets", testRefusals)
  ]

testMetadata :: IO Property
testMetadata = do
  values <- mapM runCase
    [ ("canonical module", header "import Std.Meta" "Meta", "\"Sample(renamed,text,)\"")
    , ("aliased module", header "import Std.Meta as M" "M", "\"Sample(renamed,text,)\"")
    , ("selected functions", header "import Std.Meta {Field, fields, nameOf, FieldAccess}" "", "\"Sample(renamed,text,)\"")
    ]
  strict <- runCaseOutcome "strict attribute fallback"
    (Text.replace "field.name)" "panic(\"fallback evaluated\"))" (header "import Std.Meta" "Meta"))
    (Nothing, ["fallback evaluated"])
  pure (conjoin (strict : values))
 where
  header imported qualifier = Text.unlines
    [ "module Probe", imported
    , "trait Label { fn label(self: &Self) -> Str }"
    , "derive Label for T: Record {"
    , " fn label(self: &T) -> Str {"
    , "  var names = " <> meta "nameOf" <> "[T]() + \"(\""
    , "  comptime for field: " <> meta "Field" <> "[T, F] in " <> meta "fields" <> "[T]() {"
    , "   if !field.has(\"skip\") { names = names + field.attributeOr(\"wire\", field.name) + \",\" }"
    , "  }"
    , "  names + \")\""
    , " }", "}"
    , "type Sample = { @wire(\"renamed\") id: Int, @skip hidden: Bool, text: Str } derives Label"
    , "impl Label for Sample { fn label(self: &Self) -> Str = \"stub\" }"
    , "fn main() -> Str {\n let value = Sample{id: 1, hidden: true, text: \"value\"}\n value.label()\n }"
    ]
   where
    meta name = if Text.null qualifier then name else qualifier <> "." <> name

testReads :: IO Property
testReads = runCase ("heterogeneous capabilities", Text.unlines
  [ "module Probe", "import Std.Meta"
  , "trait Count { fn count(self: &Self) -> Int }"
  , "impl Count for Int { fn count(self: &Self) -> Int = *self }"
  , "impl Count for Bool { fn count(self: &Self) -> Int { if *self { 10 } else { 20 } } }"
  , "trait Total { fn total(self: &Self) -> Int }"
  , "derive Total for T: Record {"
  , " fn total(self: &T) -> Int {"
  , "  var count = 0"
  , "  comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Count {"
  , "   count = count + field.get(self).count()"
  , "  }"
  , "  count"
  , " }", "}"
  , "type Sample = { number: Int, flag: Bool } derives Total"
  , "type Other = { flag: Bool, number: Int, again: Int } derives Total"
  , "impl Total for Sample { fn total(self: &Self) -> Int = 0 }"
  , "impl Total for Other { fn total(self: &Self) -> Int = 0 }"
  , "fn main() -> Int {\n let a = Sample{number: 10, flag: true}\n let b = Other{flag: false, number: 2, again: 3}\n a.total() + b.total()\n }"
  ], "45")

testScopes :: IO Property
testScopes = conjoin <$> sequence [scopeCase, setterCase]
 where
  scopeCase = runCase ("generic field metadata and lexical scopes", Text.unlines
    [ "module Probe", "import Std.Meta"
    , "type Held = { name: Str }"
    , "trait Label { fn label(self: &Self) -> Str }"
    , "derive Label for T: Record {"
    , " fn label(self: &T) -> Str {"
    , "  var names = \"\""
    , "  comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
    , "   let read = fn(field: Int) -> Str { field.toText() }"
    , "   names = names + read(1)"
    , "   match Some(2) {\n case Some(field) => { names = names + field.toText() }\n case None => {}\n }"
    , "   for field in [3] { names = names + field.toText() }"
    , "   let field = Held{name: \"runtime\"}"
    , "   names = names + field.name"
    , "  }"
    , "  names"
    , " }", "}"
    , "type Sample[A] = { left: A, right: A } derives Label"
    , "impl[A] Label for Sample[A] { fn label(self: &Self) -> Str = \"stub\" }"
    , "fn main() -> Str {\n let value = Sample{left: 1, right: 2}\n value.label()\n }"
    ], "\"123runtime123runtime\"")
  setterCase = runCase ("mutable field projection", Text.unlines
    [ "module Probe", "import Std.Meta"
    , "trait Step { fn step(self: &Self) -> Self }"
    , "impl Step for Int { fn step(self: &Self) -> Self = (*self) + 1 }"
    , "impl Step for Bool { fn step(self: &Self) -> Self = !(*self) }"
    , "trait Advance { fn advance(self: &mut Self) -> () }"
    , "derive Advance for T: Record {"
    , " fn advance(self: &mut T) -> () {"
    , "  comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Step {"
    , "   if field.has(\"restore\") { field.set(self, field.get(&(*self)).step()) }"
    , "  }"
    , " }", "}"
    , "type Sample = { @restore mut number: Int, flag: Bool } derives Advance"
    , "impl Advance for Sample { fn advance(self: &mut Self) -> () = () }"
    , "fn main() -> Int {\n var value = Sample{number: 10, flag: false}\n value.advance()\n value.number\n }"
    ], "11")

runCase :: (String, Text, Text) -> IO Property
runCase (label, contents, expected) = runCaseOutcome label contents (Just expected, [])

runCaseOutcome :: String -> Text -> (Maybe Text, [Text]) -> IO Property
runCaseOutcome label contents expected = withSystemTempDirectory "pudu-derive-record" $ \directory -> do
  let path = directory </> "Probe.pudu"
  (original, checked) <- kernelFixture path contents
  case (compileSyntax checked, compileResolution checked) of
    (Just parsed, Just resolution) | not (hasErrors (programDiagnostics original <> compileDiagnostics checked)) -> do
      let templates = [Located at value | Located at (DeriveDeclaration value) <- moduleDeclarations parsed]
          targets = [value | Located _ (TypeDeclaration value) <- moduleDeclarations parsed]
          heads = [Located at value | Located at (ImplDeclaration value) <- moduleDeclarations parsed
                    , any (sameTarget value) targets]
          sameTarget value target = case locatedValue (implTarget value) of
            NamedType path' _ -> moduleNameText path' == locatedValue (typeName target)
            _ -> False
          generate (Located request head') = case
            [(template, target) | template <- templates, target <- targets, sameTarget head' target] of
              (template, target) : _ -> instantiateRecord (reflectionReferences parsed resolution)
                request template target (implTrait head') (implTarget head')
              _ -> Left (ExpansionFailure request "missing test template or target")
      case traverse generate heads of
        Left failure -> pure (counterexample (label <> ": " <> show failure) False)
        Right generated -> do
          let generatedHeads = zipWith (\(Located at _) (value, _) -> Located at (ImplDeclaration value)) heads generated
              remove (Located _ declaration) = case declaration of
                ImplDeclaration value -> not (any (sameTarget value) targets)
                DeriveDeclaration _ -> False
                _ -> True
              unit = parsed{moduleDeclarations = filter remove (moduleDeclarations parsed) <> generatedHeads}
              folded = Map.fromList
                [(moduleNameText name, compileFolded result)
                | (name, result) <- Map.toList (programModules original)]
          transformed <- compileFrontendWithDependencies folded (programIntegerKinds original)
            (programDependencies original) (programContext original) (FrontendResult [] (Just unit) [])
          case compileModule transformed of
            Nothing -> pure (counterexample (label <> ": generated check: " <> show (map diagnosticMessage (compileDiagnostics transformed))) False)
            Just runnable -> do
              let kinds = Map.union (compileIntegerKinds transformed) (programIntegerKinds original)
                  run mode = inMode mode $ do
                    outcome <- evaluateProgramEntry kinds (programDependencies original) "main" runnable
                    pure (fmap renderValue (outcomeValue outcome), map diagnosticMessage (outcomeDiagnostics outcome))
              tree <- run "tree"
              compiled <- run "compiled"
              pure $ counterexample label $ conjoin
                [ tree === expected
                , compiled === tree
                , property (all (all (hasOrigin . locatedSpan) . implFunctions . fst) generated)
                , property (all (all ((== Nothing) . spanOrigin . obligationField) . snd) generated)
                , property (all (all ((== Nothing) . spanOrigin . obligationRequest) . snd) generated)
                , property (all (all (not . null . obligationBounds) . snd) generated)
                , if label == "heterogeneous capabilities"
                    then length (concatMap snd generated) === 5 else property True
                ]
    _ -> pure (counterexample (label <> ": definition check: " <> show (map diagnosticMessage (programDiagnostics original))) False)
 where
  hasOrigin = (/= Nothing) . spanOrigin

testRefusals :: IO Property
testRefusals = do
  at <- emptySpan <$> newSource (SourceName "Limits.pudu") ""
  refusals <- mapM refusalCase
    [ ("sum shape", "type Sample = Ready | Done", "Meta.nameOf[T]()", "record target")
    , ("metadata escape", "type Sample = { number: Int }", "{\n let held = Meta.nameOf\n \"unused\"\n }", "metadata cannot escape")
    , ("attribute arity", "type Sample = { @wire(\"a\", \"b\") number: Int }",
       "{\n var names = \"\"\n comptime for field: Meta.Field[T, F] in Meta.fields[T]() {\n names = names + field.attributeOr(\"wire\", field.name)\n }\n names\n }", "exactly one attribute literal")
    ]
  let depth = runResidual at (withinDepth callDepthLimit at)
      allowed = runResidual at (replicateM_ iterationLimit (iteration at))
      exhausted = runResidual at (replicateM_ (iterationLimit + 1) (iteration at))
      nodes = runResidual at (replicateM_ (expansionNodeLimit + 1) (Residual.generated at ()))
  pure $ conjoin
    (refusals <>
    [ property (case depth of Left _ -> True; _ -> False)
    , allowed === Right ((), [])
    , property (case exhausted of Left _ -> True; _ -> False)
    , property (case nodes of Left _ -> True; _ -> False)
    ])

refusalCase :: (String, Text, Text, Text) -> IO Property
refusalCase (label, target, body, expected) = withSystemTempDirectory "pudu-derive-refusal" $ \directory -> do
  let path = directory </> "Probe.pudu"
      source = Text.unlines
        [ "module Probe", "import Std.Meta"
        , "trait Label { fn label(self: &Self) -> Str }"
        , "derive Label for T: Record { fn label(self: &T) -> Str = " <> body <> " }"
        , target <> " derives Label"
        , "impl Label for Sample { fn label(self: &Self) -> Str = \"stub\" }"
        , "fn main() -> Int = 0"
        ]
  (program, checked) <- kernelFixture path source
  pure $ case (compileSyntax checked, compileResolution checked) of
    (Just parsed, Just resolved) | not (hasErrors (programDiagnostics program <> compileDiagnostics checked)) ->
        case ([Located at template | Located at (DeriveDeclaration template) <- moduleDeclarations parsed],
              [value | Located _ (TypeDeclaration value) <- moduleDeclarations parsed],
              [Located at head' | Located at (ImplDeclaration head') <- moduleDeclarations parsed]) of
          ([template], [written], [Located request head']) ->
            case instantiateRecord (reflectionReferences parsed resolved) request template written
                (implTrait head') (implTarget head') of
              Left (ExpansionFailure where' message) -> counterexample (label <> ": " <> Text.unpack message) $
                conjoin [property (expected `Text.isInfixOf` message),
                  property (case spanOrigin where' of Just (_, actual, _) -> actual == request; _ -> False)]
              Right _ -> counterexample (label <> ": unsupported expansion was published") False
          _ -> counterexample (label <> ": refusal fixture changed") False
    _ -> counterexample (label <> ": generic definition failed: " <> show (map diagnosticMessage (programDiagnostics program <> compileDiagnostics checked))) False

kernelFixture :: FilePath -> Text -> IO (ProgramResult, CompileResult)
kernelFixture path contents = do
  TextIO.writeFile path "module Probe\nimport Std.Meta\nfn main() -> () = ()\n"
  dependencies <- compileProgram path
  source <- newSource (SourceName (Text.pack path)) contents
  checked <- compileFrontendWithDependencies Map.empty (programIntegerKinds dependencies)
    (programDependencies dependencies) (programContext dependencies) (runFrontend source)
  pure (dependencies, checked)

inMode :: String -> IO a -> IO a
inMode mode action = do
  previous <- lookupEnv "PUDU_EVAL"
  setEnv "PUDU_EVAL" mode
  action `finally` maybe (unsetEnv "PUDU_EVAL") (setEnv "PUDU_EVAL") previous
