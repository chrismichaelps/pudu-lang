{-| @Test.Compiler.Literals — the evaluated module carries literals resolved -}
module Pudu.Compiler.LiteralsSpec (literalsProperties) where

import Data.Maybe (fromMaybe)
import Pudu.Frontend.Syntax.Name (moduleNameText)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Type.Value (capabilityName)
import Pudu.Source (SourceName (..), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, (.&&.), (===))

literalsProperties :: [(String, IO Property)]
literalsProperties =
  [ ("the evaluated module carries each integer literal resolved to its checked kind", testResolved)
  , ("the tree tooling reads keeps the literal's text", testSyntaxKept)
  , ("executable implementation heads retain checked nested alias shape", testImplementationHead)
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
