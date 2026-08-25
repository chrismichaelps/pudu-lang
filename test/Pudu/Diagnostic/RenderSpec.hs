module Pudu.Diagnostic.RenderSpec (renderProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Diagnostic.Render
  ( RenderStyle (..)
  , defaultRenderConfig
  , interactiveRenderConfig
  , renderDiagnostics
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

renderProperties :: [(String, IO Property)]
renderProperties =
  [ ("a diagnostic renders headline location excerpt and caret", testLayout)
  , ("related context and help render once each", testRelated)
  , ("plain style contains no escape sequences", testPlain)
  , ("interactive rendering reports the typed line", testInteractive)
  , ("summaries count errors and warnings", testSummary)
  , ("tabs keep the caret aligned", testTabs)
  ]

testLayout :: IO Property
testLayout = do
  rendered <- render ["module M", "fn run() -> Int { missing }"]
  pure $ conjoin
    [ counterexample (Text.unpack rendered)
        (property (Text.isInfixOf "error[E2010]: unresolved value name missing" rendered))
    , property (Text.isInfixOf "--> render.pudu:2:19" rendered)
    , property (Text.isInfixOf "fn run() -> Int { missing }" rendered)
    , property (Text.isInfixOf "^^^^^^^" rendered)
    , property (Text.isInfixOf "= help:" rendered)
    ]

testRelated :: IO Property
testRelated = do
  rendered <- render ["module M", "fn run() -> Int { 1 }", "fn run() -> Int { 2 }"]
  pure $ conjoin
    [ property (Text.isInfixOf "error[E2001]" rendered)
    , counterexample "the first declaration is located"
        (property (Text.isInfixOf "= note: first declared here (render.pudu:2:4)" rendered))
    , counterexample "help appears once" (countOf "= help:" rendered === 1)
    ]

testPlain :: IO Property
testPlain = do
  rendered <- render ["module M", "fn run() -> Int { missing }"]
  pure (property (not (Text.isInfixOf "\ESC[" rendered)))

testInteractive :: IO Property
testInteractive = do
  source <- newSource (SourceName "<interactive>") (Text.unlines
    [ "module Repl.Session"
    , "fn __session() {"
    , "missing"
    , "}"
    ])
  result <- runCompile source
  let config = interactiveRenderConfig PlainStyle "<interactive>" 3
      rendered = renderDiagnosticsWith config source (compileDiagnostics result)
  pure $ conjoin
    [ counterexample (Text.unpack rendered)
        (property (Text.isInfixOf "<interactive>:1:1" rendered))
    , counterexample "the generated preamble is not quoted"
        (property (not (Text.isInfixOf "__session" rendered)))
    ]

testSummary :: IO Property
testSummary = do
  source <- newSource (SourceName "summary.pudu") (Text.unlines
    [ "module M"
    , "fn run(value: Int) -> Int {"
    , "  {"
    , "    let value = missing"
    , "    value"
    , "  }"
    , "}"
    ])
  result <- runCompile source
  pure (renderSummary (compileDiagnostics result) === "1 error, 1 warning")

testTabs :: IO Property
testTabs = do
  source <- newSource (SourceName "tabs.pudu") "module M\nfn run() -> Int {\n\tmissing\n}\n"
  result <- runCompile source
  let rendered = renderDiagnostics PlainStyle source (compileDiagnostics result)
      caretLine = quotedLineWith "^" rendered
      sourceLine = quotedLineWith "missing" rendered
  pure $ conjoin
    [ counterexample (Text.unpack rendered)
        (property (not (Text.isInfixOf "\t" rendered)))
    , counterexample (Text.unpack rendered)
        (indentAfterBar caretLine === indentAfterBar sourceLine)
    ]

{-| Only excerpt rows carry a `|` gutter, so this ignores the headline and the
    help line while comparing alignment. -}
quotedLineWith :: Text -> Text -> Text
quotedLineWith needle rendered =
  case filter matches (Text.lines rendered) of
    found : _ -> found
    [] -> Text.empty
 where
  matches line = Text.isInfixOf "| " line && Text.isInfixOf needle line

indentAfterBar :: Text -> Int
indentAfterBar line =
  Text.length (Text.takeWhile (== ' ') (Text.drop 1 (Text.dropWhile (/= '|') line)))

countOf :: Text -> Text -> Int
countOf needle = length . filter (Text.isInfixOf needle) . Text.lines

render :: [Text] -> IO Text
render inputLines = do
  source <- newSource (SourceName "render.pudu") (Text.unlines inputLines)
  result <- runCompile source
  pure (renderDiagnosticsWith (defaultRenderConfig PlainStyle) source (compileDiagnostics result))
