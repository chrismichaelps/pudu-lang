{-| @Test.Compiler.Literals — the evaluated module carries literals resolved -}
module Pudu.Compiler.LiteralsSpec (literalsProperties) where

import Data.Maybe (fromMaybe)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Frontend.Syntax.Located (Located (..))
import Pudu.Frontend.Syntax.Tree
import Pudu.IntegerLiteral (IntegerKind (..))
import Pudu.Source (SourceName (..), newSource)
import Test.QuickCheck (Property, counterexample, (.&&.), (===))

literalsProperties :: [(String, IO Property)]
literalsProperties =
  [ ("the evaluated module carries each integer literal resolved to its checked kind", testResolved)
  , ("the tree tooling reads keeps the literal's text", testSyntaxKept)
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
