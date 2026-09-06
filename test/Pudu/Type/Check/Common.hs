{-| @Test.Type.Check.Common — shared compilation and type query helpers -}
module Pudu.Type.Check.Common
  ( codes
  , codesOf
  , codesOfExpression
  , compile
  , diagnosticContract
  , region
  , typeOf
  , typeOfIn
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic
  ( diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSpan
  )
import Pudu.Source (SourceName (SourceName), newSource, spanStart, unOffset)
import Pudu.Type (renderType, widestWithin)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

codes :: [Text] -> IO [Text]
codes inputLines = do
  result <- compile (Text.unlines inputLines)
  pure (codesOf result)

codesOfExpression :: Text -> IO [Text]
codesOfExpression expression =
  codes ["module M", "fn run() {", "  " <> expression, "}"]

codesOf :: CompileResult -> [Text]
codesOf result = map (diagnosticCodeText . diagnosticCode) (compileDiagnostics result)

compile :: Text -> IO CompileResult
compile source = do
  snapshot <- newSource (SourceName "type.pudu") source
  runCompile snapshot

typeOf :: Text -> IO Text
typeOf expression = typeOfIn ["fn run() {", "  " <> expression, "}"] expression

{-| Compile a module and report the type of the widest expression inside the
    region the given text occupies. -}
typeOfIn :: [Text] -> Text -> IO Text
typeOfIn body needle = do
  let source = Text.unlines (["module M"] <> body)
  result <- compile source
  case compileTypes result of
    Nothing -> pure ("no types: " <> Text.intercalate "," (codesOf result))
    Just info -> case region source needle of
      Nothing -> pure "not found"
      Just (start, end) -> case widestWithin start end info of
        Nothing -> pure "no type"
        Just found -> pure (renderType found)

{-| Locate the last occurrence of the text, which is the one in expression
    position when a name is first declared and then used. -}
region :: Text -> Text -> Maybe (Int, Int)
region source needle = case Text.breakOnEnd needle source of
  (before, _)
    | Text.null before -> Nothing
    | otherwise -> Just (Text.length before - Text.length needle, Text.length before)

diagnosticContract :: Text -> Text -> Text -> Text -> Maybe Text -> CompileResult -> Property
diagnosticContract source needle expectedCode expectedMessage expectedHelp result =
  case (compileDiagnostics result, region source needle) of
    ([value], Just (expectedStart, _)) ->
      conjoin
        [ diagnosticCodeText (diagnosticCode value) === expectedCode
        , diagnosticMessage value === expectedMessage
        , diagnosticHelp value === expectedHelp
        , unOffset (spanStart (diagnosticSpan value)) === expectedStart
        ]
    (values, location) ->
      counterexample ("unexpected diagnostics or location: " <> show (length values, location)) False
