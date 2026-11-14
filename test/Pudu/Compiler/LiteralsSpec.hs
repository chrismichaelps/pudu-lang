{-| @Test.Compiler.Literals — the evaluated module carries literals resolved -}
module Pudu.Compiler.LiteralsSpec (literalsProperties) where

import Data.Maybe (fromMaybe)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Pudu.Frontend.Syntax.Name (moduleNameText)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Type.Value (Type (..), ProviderSelection (..), capabilityName, nominalKey, integerType)
import Pudu.Type (ModuleTypes (..), checkTypesDetailed)
import Pudu.Type.Interface.Graph (emptyImportTypes)
import qualified Pudu.Type.Env as Env
import Pudu.Type.Unify (unify)
import Pudu.Source (SourceName (..), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (.&&.), (===))

literalsProperties :: [(String, IO Property)]
literalsProperties =
  [ ("the evaluated module carries each integer literal resolved to its checked kind", testResolved)
  , ("the tree tooling reads keeps the literal's text", testSyntaxKept)
  , ("executable implementation heads retain checked nested alias shape", testImplementationHead)
  , ("bound selections retain complete trait and applied receiver evidence", testProviderEvidence)
  , ("implementation trait arguments retain their formed canonical shape", testImplementationTrait)
  ]

source :: String
source = "module Probe\n\nfn small(x: UInt8) -> UInt8 { x + 1 }\n\nfn main() -> Int {\n  let big = 0xFF\n  let two = small(2)\n  big\n}\n"

testResolved :: IO Property
testResolved = do
  result <- compileProbe
  let literals = fromMaybe [] (literalsOf <$> compileModule result)
  pure $
    counterexample (show literals) $
      (ResolvedInteger PlatformSigned 255 `elem` literals)
        .&&. (ResolvedInteger (UnsignedKind 8) 1 `elem` literals)
        .&&. (ResolvedInteger (UnsignedKind 8) 2 `elem` literals)
        .&&. (null [text | IntegerValue text <- literals] === True)

testSyntaxKept :: IO Property
testSyntaxKept = do
  result <- compileProbe
  let literals = fromMaybe [] (literalsOf <$> compileSyntax result)
  pure $ counterexample (show literals) ([text | IntegerValue text <- literals] === ["1", "0xFF", "2"])

compileProbe :: IO CompileResult
compileProbe = newSource (SourceName "Probe.pudu") (Text.pack source) >>= runCompile

{-| Every literal in expression position, in source order. -}
literalsOf :: Module -> [Literal]
literalsOf moduleValue = concatMap (declaration . locatedValue) (moduleDeclarations moduleValue)
 where
  declaration value = case value of
    FunctionDeclaration function -> maybe [] (body . locatedValue) (functionBody function)
    BindingDeclaration _ _ _ _ initializer -> expression initializer
    _ -> []
  body value = case value of
    BlockBody (Located _ block) -> blockLiterals block
    ExpressionBody inner -> expression inner
  blockLiterals (Block statements final) = concatMap (statement . locatedValue) statements <> maybe [] expression final
  statement value = case value of
    DeclarationStatement (Located _ inner) -> declaration inner
    ExpressionStatement inner -> expression inner
    _ -> []
  expression (Located _ value) = case value of
    LiteralExpression literal -> [literal]
    BinaryExpression left _ right -> expression left <> expression right
    CallExpression callee arguments -> expression callee <> concatMap expression arguments
    _ -> []

{-| Implementation parameters match checked heads, not authored alias argument order. -}
testImplementationHead :: IO Property
testImplementationHead = conjoin <$> mapM check
  [ ("A, B", "Reversed[A, Array[B]]", "Probe.Pair[Array[B],A]")
  , ("A, B", "Reversed[(A, &B), Array[fn(A) -> B]]", "Probe.Pair[Array[fn(A)->B],(A,&B)]")
  , ("F[_], A", "Reversed[A, F[A]]", "Probe.Pair[F[A],A]")
  , ("A, B", "Reversed[dynamic Named, unsafe(raw) fn(A) -> B]", "Probe.Pair[unsafe(raw)fn(A)->B,dynamicProbe.Named]")
  , ("A", "Reversed[A, Never]", "Probe.Pair[Never,A]")
  ]
 where
  check (parameters, target, expected) = do
    result <- newSource (SourceName "Probe.pudu") (Text.unlines
      [ "module Probe"
      , "type Pair[L, R] = { left: L, right: R }"
      , "type Reversed[X, Y] = Pair[Y, X]"
      , "trait Named { fn label() -> Str }"
      , "impl[" <> parameters <> "] Named for " <> target <> " {"
      , "  fn label() -> Str { \"named\" }"
      , "}"
      ]) >>= runCompile
    let heads tree = [implTarget value | Located _ (ImplDeclaration value) <- moduleDeclarations tree]
        targets = maybe [] heads (compileModule result)
        authored = maybe [] heads (compileSyntax result)
    pure $ counterexample (show (compileDiagnostics result, targets, authored)) $
      map shape targets === [expected]
      .&&. (map shape authored === [Text.filter (/= ' ') target])
      .&&. (map locatedSpan targets === map locatedSpan authored)
  shape (Located _ syntax) = case syntax of
    NamedType path [] -> moduleNameText path
    NamedType path arguments -> moduleNameText path <> "[" <> joined arguments <> "]"
    DynamicType path -> "dynamic" <> moduleNameText path
    UnsafeType capabilities target -> "unsafe(" <> Text.intercalate "," (map (capabilityName . locatedValue) capabilities) <> ")" <> shape target
    TupleType members -> "(" <> joined members <> ")"
    ReferenceType mutable target -> (if mutable then "&mut" else "&") <> shape target
    FunctionType asynchronous inputs result -> (if asynchronous then "async" else "") <> "fn(" <> joined inputs <> ")->" <> shape result
    _ -> "invalid"
  joined = Text.intercalate "," . map shape


{-| Caller evidence must not erase a constructor application or an inference result. -}
testProviderEvidence :: IO Property
testProviderEvidence = do
  result <- newSource (SourceName "Probe.pudu") (Text.unlines
    [ "module Probe"
    , "trait Holds[Tag] { fn get(self: &Self) -> Tag }"
    , "trait Family[F[_]] { fn size(self: &Self) -> Int }"
    , "fn direct[T: Holds[Int]](value: &T) -> Int { value.get() }"
    , "fn saved[T: Holds[Int]](value: &T) -> Int {"
    , "  let read = value.get"
    , "  read()"
    , "}"
    , "fn higher[F[_]: Family[F], A](value: &F[A]) -> Int { value.size() }"
    ]) >>= runCompile
  pure $ case compileSyntax result of
    Nothing -> counterexample (show (compileDiagnostics result)) False
    Just authored ->
      let (facts, diagnostics) = checkTypesDetailed emptyImportTypes Set.empty authored
          bound = [(nominalKey owner, arguments, receiver)
            | ProviderSelection owner arguments (Just receiver) <- Map.elems (moduleProviders facts)]
          at = moduleSpan authored
          products = Env.runChecker $ do
            inferred <- Env.freshVariable
            Env.recordProviderSelection at (ProviderSelection "Holds" [inferred] (Just inferred))
            unify at inferred integerType
       in counterexample (show (compileDiagnostics result, diagnostics, bound)) $
            (null (compileDiagnostics result) && null diagnostics)
            .&&. (bound ===
              [ ("Probe.Holds", [integerType], RigidType "T")
              , ("Probe.Holds", [integerType], RigidType "T")
              , ("Probe.Family", [RigidType "F"], AppliedType (RigidType "F") [RigidType "A"]) ])
            .&&. (Env.producedProviders products ===
              [(at, ProviderSelection "Holds" [integerType] (Just integerType))])

{-| The selected trait can determine parameters absent from the receiver target. -}
testImplementationTrait :: IO Property
testImplementationTrait = do
  result <- newSource (SourceName "Probe.pudu") (Text.unlines
    [ "module Probe"
    , "type Pair[L, R] = { left: L, right: R }"
    , "type Reversed[X, Y] = Pair[Y, X]"
    , "type Box[A] = { value: A }"
    , "trait Choice[Tag] { fn label() -> Str }"
    , "impl[A, B] Choice[Reversed[A, Array[B]]] for Box[A] {"
    , "  fn label() -> Str { \"selected\" }"
    , "}"
    ]) >>= runCompile
  let traits tree = [implTrait value | Located _ (ImplDeclaration value) <- moduleDeclarations tree]
      chosen = maybe [] traits (compileModule result)
      authored = maybe [] traits (compileSyntax result)
      render (Located _ (NamedType path arguments)) = moduleNameText path <>
        (if null arguments then "" else "[" <> Text.intercalate "," (map render arguments) <> "]")
      render _ = "invalid"
  pure $ counterexample (show (compileDiagnostics result, chosen, authored)) $
    null (compileDiagnostics result)
    .&&. (map render chosen === ["Probe.Choice[Probe.Pair[Array[B],A]]"])
    .&&. (map render authored === ["Choice[Reversed[A,Array[B]]]"])
    .&&. (map locatedSpan chosen === map locatedSpan authored)
