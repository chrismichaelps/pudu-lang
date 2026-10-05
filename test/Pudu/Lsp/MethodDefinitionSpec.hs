{-| @Test.Lsp.MethodDefinition — a method call is defined where its owner declares it. -}
module Pudu.Lsp.MethodDefinitionSpec (methodDefinitionProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Lsp.Definition (definitionAcross)
import Pudu.Lsp.Feature (offsetAt)
import Pudu.Lsp.Json (Json (..), integerOf, lookupField, textOf)
import Pudu.Lsp.Protocol (Position (..), fileUri)
import Pudu.Lsp.Server (analyse)
import System.Directory (getCurrentDirectory)
import System.FilePath (normalise, (</>))
import Test.QuickCheck (Property, conjoin, counterexample, (===))

methodDefinitionProperties :: [(String, IO Property)]
methodDefinitionProperties =
  [ ("a method call on a value is defined in its impl", testValueReceiver)
  , ("a static call through a type is defined in its impl", testStaticCall)
  , ("a derived method is defined in the derive that wrote it", testDerivedMethod)
  , ("a library derive's method is defined in the library", testLibraryDerive)
  , ("a call through a type parameter is defined at its trait member", testTypeParameter)
  , ("an inherited default is defined at its trait member", testInheritedDefault)
  ]

uri :: Text
uri = "file:///pudu-fixtures/Methods.pudu"

source :: Text
source =
  Text.unlines
    [ "module Methods"
    , "import Std.Meta"
    , "import Std.Order {Eq}"
    , "trait Shape {"
    , "  fn area(self: &Self) -> Int"
    , "  fn label(self: &Self) -> Str { \"shape\" }"
    , "  fn unit() -> Self"
    , "}"
    , "type Square = { side: Int } derives Eq"
    , "impl Shape for Square {"
    , "  fn area(self: &Self) -> Int { self.side * self.side }"
    , "  fn unit() -> Square { Square{side: 1} }"
    , "}"
    , "trait Named { fn named(self: &Self) -> Str }"
    , "derive Named for T: Record {"
    , "  fn named(self: &T) -> Str { Meta.nameOf[T]() }"
    , "}"
    , "type Point = { x: Int } derives Named"
    , "fn total[A: Shape](shape: &A) -> Int { shape.area() + A.unit().area() }"
    , "fn main() -> Int {"
    , "  let square = Square.unit()"
    , "  let point = Point{x: 1}"
    , "  if square.equals(&square) && point.named() == square.label() { square.area() } else { total(&square) }"
    , "}"
    ]

{-| The URI and start line of each location the definition at a position
    answers. -}
definedAt :: Int -> Int -> IO [(Text, Int)]
definedAt line character = do
  value <- analyse uri source
  reply <- definitionAcross readText uri value (offsetAt source (Position line character))
  pure $ case reply of
    JsonArray several -> concatMap one several
    single -> one single
 where
  readText path = Just <$> TextIO.readFile path
  one location = case (lookupField "uri" location >>= textOf, lookupField "range" location >>= lookupField "start" >>= lookupField "line" >>= integerOf) of
    (Just target, Just start) -> [(target, start)]
    _ -> []

expectAt :: String -> [(Text, Int)] -> [(Text, Int)] -> Property
expectAt label expected found = counterexample (label <> ": " <> show found) (found === expected)

testValueReceiver :: IO Property
testValueReceiver = expectAt "square.area()" [(uri, 10)] <$> definedAt 22 74

testStaticCall :: IO Property
testStaticCall = expectAt "Square.unit()" [(uri, 11)] <$> definedAt 20 23

testDerivedMethod :: IO Property
testDerivedMethod = expectAt "point.named()" [(uri, 15)] <$> definedAt 22 39

testLibraryDerive :: IO Property
testLibraryDerive = do
  root <- getCurrentDirectory
  found <- definedAt 22 14
  let order = fileUri (normalise (root </> "packages/pudu/v0.1/lib/Std/Order.pudu"))
  pure $ counterexample (show found) (map fst found === [order])

testTypeParameter :: IO Property
testTypeParameter = do
  onValue <- definedAt 18 47
  onType <- definedAt 18 58
  pure $ conjoin [expectAt "shape.area()" [(uri, 4)] onValue, expectAt "A.unit()" [(uri, 6)] onType]

testInheritedDefault :: IO Property
testInheritedDefault = expectAt "square.label()" [(uri, 5)] <$> definedAt 22 57
