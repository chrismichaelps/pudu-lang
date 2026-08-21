module Pudu.Frontend.ParserImportSpec (parserImportProperties) where

import Data.List.NonEmpty (NonEmpty (..))
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (Diagnostic, diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Import (parseImport, parseImports)
import Pudu.Frontend.Parser.State (peekKind, runParser)
import Pudu.Frontend.Syntax (Import (..), Located (..), ModuleName (..))
import Pudu.Frontend.Token (Keyword (KwImport), TokenKind (..))
import Pudu.Source (SourceName (SourceName), spanEnd, spanStart, unOffset)
import qualified Pudu.Source as Source
import Test.QuickCheck (Property, conjoin, counterexample, (===))

parserImportProperties :: [(String, IO Property)]
parserImportProperties =
  [ ("import forms preserve explicit syntax", testImportForms)
  , ("invalid import suffixes emit exact diagnostics", testInvalidSuffixes)
  , ("missing selection closure recovers at EOF", testMissingClosure)
  , ("hostile import selections share the nesting budget", testHostileSelection)
  , ("hostile import lists share the nesting budget", testHostileImports)
  ]

testImportForms :: IO Property
testImportForms = do
  bare <- parseOne "import Core.Net"
  aliased <- parseOne "import Core.Net as Net"
  selected <- parseOne "import Core.Net {Client, Error,}"
  pure $ conjoin
    [ shape bare === "Core.Net||"
    , shape aliased === "Core.Net|Net|"
    , shape selected === "Core.Net||Client,Error"
    , spanOffsets selected === (0, 32)
    ]

testInvalidSuffixes :: IO Property
testInvalidSuffixes = do
  lowercase <- parseOne "import Core as alias"
  missingAlias <- parseOne "import Core as"
  emptySelection <- parseOne "import Core {}"
  conflicting <- parseOne "import Core as Alias {Thing}"
  pure $ conjoin
    [ counterexample "lowercase alias codes" (codes lowercase === ["E1011"])
    , diagnosticOffsets lowercase === [15]
    , counterexample "missing alias codes" (codes missingAlias === ["E1001"])
    , diagnosticOffsets missingAlias === [14]
    , counterexample "empty selection codes" (codes emptySelection === ["E1030"])
    , diagnosticOffsets emptySelection === [13]
    , counterexample "conflicting suffix codes" (codes conflicting === ["E1031"])
    , diagnosticOffsets conflicting === [21]
    ]

testMissingClosure :: IO Property
testMissingClosure = do
  result <- parseOne "import Core {Thing"
  pure $ conjoin [codes result === ["E1001"], remainingKind result === EndOfFile]

testHostileSelection :: IO Property
testHostileSelection = do
  let input = "import Core {" <> Text.intercalate "," (replicate 520 "A") <> "}"
  result <- parseOne input
  pure $ conjoin
    [ codes result === ["E1099"]
    , diagnosticOffsets result === [1039]
    ]

testHostileImports :: IO Property
testHostileImports = do
  let input = Text.concat (replicate 520 "import Core ")
  (_, remaining, diagnostics) <- parseMany input
  pure $ conjoin
    [ map diagnosticText diagnostics === ["E1099"]
    , map diagnosticOffset diagnostics === [6144]
    , remaining === Keyword KwImport
    ]

parseOne :: Text -> IO (Located Import, TokenKind, [Diagnostic])
parseOne input = do
  source <- Source.newSource (SourceName "import.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parseImport <*> peekKind
      ((parsed, remaining), diagnostics) = runParser source action lexTokens
  pure (parsed, remaining, diagnostics)

parseMany :: Text -> IO ([Located Import], TokenKind, [Diagnostic])
parseMany input = do
  source <- Source.newSource (SourceName "imports.pudu") input
  let LexResult{lexTokens} = lexSource source
      action = (,) <$> parseImports <*> peekKind
      ((parsed, remaining), diagnostics) = runParser source action lexTokens
  pure (parsed, remaining, diagnostics)

shape :: (Located Import, TokenKind, [Diagnostic]) -> Text
shape (Located _ Import{importModule = Located _ (ModuleName segments), importAlias, importItems}, remaining, diagnostics)
  | remaining == EndOfFile && null diagnostics =
      Text.intercalate "." (toList segments)
        <> "|" <> maybe "" locatedValue importAlias
        <> "|" <> Text.intercalate "," (map locatedValue importItems)
  | otherwise = "invalid"
 where
  toList :: NonEmpty Text -> [Text]
  toList (first :| rest) = first : rest

codes :: (parsed, TokenKind, [Diagnostic]) -> [Text]
codes (_, _, diagnostics) = map diagnosticText diagnostics

diagnosticOffsets :: (parsed, TokenKind, [Diagnostic]) -> [Int]
diagnosticOffsets (_, _, diagnostics) = map diagnosticOffset diagnostics

diagnosticText :: Diagnostic -> Text
diagnosticText = diagnosticCodeText . diagnosticCode

diagnosticOffset :: Diagnostic -> Int
diagnosticOffset = unOffset . spanStart . diagnosticSpan

spanOffsets :: (Located Import, TokenKind, [Diagnostic]) -> (Int, Int)
spanOffsets (Located spanValue _, _, _) =
  (unOffset (spanStart spanValue), unOffset (spanEnd spanValue))

remainingKind :: (parsed, TokenKind, [Diagnostic]) -> TokenKind
remainingKind (_, kind, _) = kind
