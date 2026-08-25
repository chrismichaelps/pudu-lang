{-| @Test.Format — the laws a formatter has to obey to be safe to run -}
module Pudu.FormatSpec (formatProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Token (Token (..), TokenKind (..), Trivia (..), TriviaKind (..))
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, ioProperty, property, (===))

formatProperties :: [(String, IO Property)]
formatProperties =
  [ ("formatting preserves every token", testTokensPreserved)
  , ("formatting is idempotent", testIdempotent)
  , ("formatting preserves every comment", testCommentsPreserved)
  , ("indentation follows brace depth", testIndentation)
  , ("spacing is normalised inside a line", testSpacing)
  , ("a record construction stays tight and a body does not", testBraces)
  , ("imports sort with the standard library first", testImportOrder)
  , ("input that does not lex is returned untouched", testUnlexable)
  , ("blank-line runs collapse to one", testBlankLines)
  ]

{-| The property that makes the formatter safe to run on anything.

    The token sequence out is the token sequence in — same kinds, same lexemes,
    same order. A formatter that can only change whitespace cannot change what
    a program means, and this is the check that it only changed whitespace. -}
testTokensPreserved :: IO Property
testTokensPreserved = pure $ conjoin (map (ioProperty . check) samples)
 where
  check text = do
    before <- tokensOf text
    formatted <- formatOf text
    after <- tokensOf formatted
    pure
      ( counterexample (Text.unpack ("formatted:\n" <> formatted))
          (after === before)
      )

testIdempotent :: IO Property
testIdempotent = pure $ conjoin (map (ioProperty . check) samples)
 where
  check text = do
    once <- formatOf text
    twice <- formatOf once
    pure (counterexample (Text.unpack once) (twice === once))

{-| A comment is the one thing in a file the compiler never reads, so nothing
    else would notice if the formatter dropped one. -}
testCommentsPreserved :: IO Property
testCommentsPreserved = pure $ conjoin (map (ioProperty . check) samples)
 where
  check text = do
    before <- commentsOf text
    formatted <- formatOf text
    after <- commentsOf formatted
    pure (counterexample (Text.unpack formatted) (after === before))

testIndentation :: IO Property
testIndentation = do
  formatted <- formatOf nested
  pure
    ( counterexample (Text.unpack formatted)
        (Text.lines formatted === expectedNested)
    )
 where
  nested =
    Text.unlines
      [ "module M"
      , "fn run(flag: Bool) -> Int {"
      , "if flag {"
      , "let inner = 1"
      , "inner"
      , "} else {"
      , "0"
      , "}"
      , "}"
      ]
  expectedNested =
    [ "module M"
    , "fn run(flag: Bool) -> Int {"
    , "  if flag {"
    , "    let inner = 1"
    , "    inner"
    , "  } else {"
    , "    0"
    , "  }"
    , "}"
    ]

testSpacing :: IO Property
testSpacing = do
  formatted <- formatOf messy
  pure
    ( counterexample (Text.unpack formatted)
        (Text.lines formatted === expected)
    )
 where
  messy =
    Text.unlines
      [ "module M"
      , "fn add( a : Int ,b : Int )->Int{a+b}"
      , "fn call() -> Int { add( 1,2 ) }"
      , "fn reach(xs: Array[Int]) -> Int { xs [ 0 ] }"
      ]
  expected =
    [ "module M"
    , "fn add(a: Int, b: Int) -> Int { a + b }"
    , "fn call() -> Int { add(1, 2) }"
    , "fn reach(xs: Array[Int]) -> Int { xs[0] }"
    ]

{-| `User{id: 1}` and `if ready {` look identical at the opening brace, so the
    formatter decides from the shape that follows: a field list means a record
    construction, and the closing brace is spaced to match whichever it
    closes. -}
testBraces :: IO Property
testBraces = do
  formatted <- formatOf source
  pure
    ( counterexample (Text.unpack formatted)
        (Text.lines formatted === expected)
    )
 where
  source =
    Text.unlines
      [ "module M"
      , "type User = {id: Int}"
      , "fn make() -> User { User{id: 1} }"
      , "fn pick(ready: Bool) -> Int { if ready {1} else {0} }"
      , "fn empty() -> Int { 0 }"
      ]
  expected =
    [ "module M"
    , "type User = { id: Int }"
    , "fn make() -> User { User{id: 1} }"
    , "fn pick(ready: Bool) -> Int { if ready { 1 } else { 0 } }"
    , "fn empty() -> Int { 0 }"
    ]

testImportOrder :: IO Property
testImportOrder = do
  formatted <- formatOf source
  pure
    ( counterexample (Text.unpack formatted)
        (take 4 (drop 1 (Text.lines formatted)) === expected)
    )
 where
  source =
    Text.unlines
      [ "module M"
      , "import Own.Thing as T"
      , "import Std.Text as X"
      , "import Std.Char as C"
      , "import Another.One as A"
      , "fn run() -> Int { 1 }"
      ]
  expected =
    [ "import Std.Char as C"
    , "import Std.Text as X"
    , "import Another.One as A"
    , "import Own.Thing as T"
    ]

{-| A formatter that rewrites text it could not read is a formatter that loses
    work, so a file it cannot lex comes back exactly as it went in. -}
testUnlexable :: IO Property
testUnlexable = do
  source <- newSource (SourceName "test") broken
  let result = formatSource source
  pure $ conjoin
    [ counterexample "the text is untouched" (formatText' result === broken)
    , counterexample "and nothing is reported as changed"
        (property (not (formatChanged result)))
    ]
 where
  broken = Text.unlines ["module M", "fn run() -> Str { \"unterminated }"]

testBlankLines :: IO Property
testBlankLines = do
  formatted <- formatOf source
  pure
    ( counterexample (Text.unpack formatted)
        (Text.lines formatted === expected)
    )
 where
  source =
    Text.unlines
      ["module M", "", "", "", "fn one() -> Int { 1 }", "", "", "fn two() -> Int { 2 }"]
  expected =
    ["module M", "", "fn one() -> Int { 1 }", "", "fn two() -> Int { 2 }"]

samples :: [Text]
samples =
  [ Text.unlines
      [ "module Sample"
      , "import Std.Text as T"
      , "/// A documented function."
      , "export fn run(a: Int, b: Int) -> Int {"
      , "  let total = a + b"
      , "  // an ordinary comment"
      , "  if total > 10 { total } else { 0 }"
      , "}"
      ]
  , Text.unlines
      [ "module Tight"
      , "type Point = { x: Int, y: Int }"
      , "fn make() -> Point { Point{x: 1, y: 2} }"
      , "fn sum(p: &Point) -> Int { p.x + p.y }"
      ]
  , Text.unlines
      [ "module Loops"
      , "fn run(grid: Array[Array[Int]]) -> Int {"
      , "  var seen = 0"
      , "  @rows for row in grid {"
      , "    for cell in row {"
      , "      if cell < 0 { break @rows }"
      , "      seen = seen + 1"
      , "    }"
      , "  }"
      , "  seen"
      , "}"
      ]
  , Text.unlines
      [ "module Matching"
      , "fn describe(value: Option[Int]) -> Int {"
      , "  match value {"
      , "    case Some(n) if n > 0 => n"
      , "    case Some(_) => 0"
      , "    case None => 0 - 1"
      , "  }"
      , "}"
      ]
  , Text.unlines
      [ "module Numbers"
      , "fn amounts() -> Decimal { 1.50d + 0.25d }"
      , "fn widths() -> UInt8 { 255u8 }"
      , "fn text() -> Str { \"a{1 + 2}b\" }"
      ]
  ]

formatOf :: Text -> IO Text
formatOf text = do
  source <- newSource (SourceName "test") text
  pure (formatText' (formatSource source))

{-| Every token's kind and lexeme, with spans erased.

    A span is an offset into the file, and formatting moves offsets by design —
    that is the whole point of it. What must not move is which tokens there are
    and what they say, so the comparison is over the kind's shape and the
    lexeme, not over the positions the lexer recorded inside them. -}
tokensOf :: Text -> IO [(Text, Text)]
tokensOf text = do
  source <- newSource (SourceName "test") text
  pure [(kindLabel (tokenKind token), tokenLexeme token) | token <- lexTokens (lexSource source)]

kindLabel :: TokenKind -> Text
kindLabel kind = case kind of
  Identifier _ -> "identifier"
  IntegerLiteral _ -> "integer"
  FloatLiteral _ -> "float"
  DecimalLiteral _ -> "decimal"
  StringLiteral _ -> "string"
  TemplateLiteral _ -> "template"
  CharLiteral _ -> "char"
  Keyword keyword -> Text.pack ("keyword " <> show keyword)
  Symbol symbol -> Text.pack ("symbol " <> show symbol)
  EndOfFile -> "end"
  Invalid _ -> "invalid"

commentsOf :: Text -> IO [Text]
commentsOf text = do
  source <- newSource (SourceName "test") text
  pure
    [ Text.strip (triviaText trivia)
    | token <- lexTokens (lexSource source)
    , trivia <- tokenLeadingTrivia token
    , triviaKind trivia /= Whitespace
    ]
