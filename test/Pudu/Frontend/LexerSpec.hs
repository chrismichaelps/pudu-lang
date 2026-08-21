module Pudu.Frontend.LexerSpec (lexerProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Diagnostic (diagnosticCode, diagnosticCodeText, diagnosticSpan)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Token
  ( Token, TokenKind (EndOfFile, Identifier, Invalid, Symbol)
  , SymbolKind (SymPlus), tokenKind, tokenLeadingTrivia, tokenLexeme
  , triviaText
  )
import Pudu.Source (SourceName (SourceName), newSource, spanEnd, spanStart, unOffset)
import Test.QuickCheck
  ( Gen, Property, conjoin, counterexample, elements, forAll, ioProperty
  , listOf, property, (===)
  )

lexerProperties :: [(String, IO Property)]
lexerProperties =
  [ ("facade integrates scanners losslessly", testIntegration)
  , ("unknown scalars recover one at a time with E0099", testUnknown)
  , ("arbitrary scanner boundaries always complete losslessly", testTotalLosslessness)
  ]

testIntegration :: IO Property
testIntegration = do
  let input = "// lead\nmodule Main fn f() -> Str = \"x\" 1..2 /*tail*/"
  source <- newSource (SourceName "integration.pudu") input
  let result = lexSource source
  pure $ conjoin [reconstruct (lexTokens result) === input, lexDiagnostics result === [],
    property (endsWithEof (lexTokens result))]

testUnknown :: IO Property
testUnknown = do
  source <- newSource (SourceName "unknown.pudu") "; name ٣ +"
  let LexResult{lexTokens, lexDiagnostics} = lexSource source
  pure $
    case (map tokenKind lexTokens, lexDiagnostics) of
      ([Invalid ";", Identifier "name", Invalid "٣", Symbol SymPlus, EndOfFile], [first, second]) ->
        conjoin
          [ map (diagnosticCodeText . diagnosticCode) [first, second] === ["E0099", "E0099"]
          , map (\finding -> (unOffset (spanStart (diagnosticSpan finding)), unOffset (spanEnd (diagnosticSpan finding)))) [first, second]
              === [(0, 1), (7, 8)]
          , reconstruct lexTokens === "; name ٣ +"
          ]
      _ -> counterexample "unknown-scalar recovery returned unexpected output" False

testTotalLosslessness :: IO Property
testTotalLosslessness = pure $ forAll sourceTextGenerator $ \input -> ioProperty $ do
  source <- newSource (SourceName "generated-lexer.pudu") input
  let LexResult{lexTokens} = lexSource source
  pure $ conjoin [reconstruct lexTokens === input, property (countEof lexTokens == 1),
    property (endsWithEof lexTokens)]

sourceTextGenerator :: Gen Text
sourceTextGenerator =
  Text.pack <$> listOf (elements "abcXYZ_019٣ +-*/.;'\"\\{}\n\r\t💡")

countEof :: [Token] -> Int
countEof = length . filter ((== EndOfFile) . tokenKind)

reconstruct :: [Token] -> Text
reconstruct = Text.concat . map (\token -> Text.concat (map triviaText (tokenLeadingTrivia token)) <> tokenLexeme token)

endsWithEof :: [Token] -> Bool
endsWithEof tokens = case reverse tokens of
  token : _ -> tokenKind token == EndOfFile
  [] -> False
