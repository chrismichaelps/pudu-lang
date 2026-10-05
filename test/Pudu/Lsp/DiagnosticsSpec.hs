{-| @Test.Lsp.Diagnostics — each finding is published where the reader can act on it. -}
module Pudu.Lsp.DiagnosticsSpec (diagnosticsProperties) where

import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Analysis (analyseOver)
import Pudu.Lsp.Diagnostics (diagnosticEntries)
import Pudu.Lsp.Documents (Analysis (..))
import Pudu.Lsp.Json (Json (..), integerOf, lookupField, textOf)
import Pudu.Lsp.Protocol (fileUri)
import System.Directory (makeAbsolute)
import System.FilePath (normalise, (</>))
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

diagnosticsProperties :: [(String, IO Property)]
diagnosticsProperties =
  [ ("help is a line of its own after the message", testHelpLine)
  , ("a derive's notes become related locations", testRelatedNotes)
  , ("an imported module's error is published at the import", testImportedError)
  , ("an empty derives clause is reported at derives", testEmptyDerives)
  ]

{-| A finding as published: its code, start line, message, and each related
    location's URI, start line, and message. -}
data Published = Published
  { publishedCode :: Text
  , publishedLine :: Int
  , publishedMessage :: Text
  , publishedRelated :: [(Text, Int, Text)]
  }
  deriving stock (Show)

published :: FilePath -> Map.Map FilePath Text -> Text -> IO [Published]
published name overlay content = do
  root <- makeAbsolute "test-fixtures/lspoverlay"
  let file = "file://" <> Text.pack (root </> name)
  value <- analyseOver (Map.mapKeys (normalise . (root </>)) overlay) root file content
  pure
    ( mapMaybe read'
        ( diagnosticEntries file content (analysisSource value) (analysisElsewhere value)
            (analysisDiagnostics value)
        )
    )
 where
  read' entry = do
    code <- lookupField "code" entry >>= textOf
    line <- lookupField "range" entry >>= lookupField "start" >>= lookupField "line" >>= integerOf
    message <- lookupField "message" entry >>= textOf
    let related = case lookupField "relatedInformation" entry of
          Just (JsonArray notes) -> mapMaybe note notes
          _ -> []
    pure (Published code line message related)
  note value = do
    location <- lookupField "location" value
    target <- lookupField "uri" location >>= textOf
    line <- lookupField "range" location >>= lookupField "start" >>= lookupField "line" >>= integerOf
    message <- lookupField "message" value >>= textOf
    pure (target, line, message)

testHelpLine :: IO Property
testHelpLine = do
  found <- published "Uses.pudu" Map.empty "module Uses\nfn wrong() -> Int { \"text\" }\n"
  pure $ case found of
    [one] ->
      conjoin
        [ publishedCode one === "E3001"
        , publishedLine one === 1
        , counterexample (Text.unpack (publishedMessage one))
            (property ("\nhelp: change the value" `Text.isInfixOf` publishedMessage one))
        ]
    other -> counterexample (show other) False

testRelatedNotes :: IO Property
testRelatedNotes = do
  root <- makeAbsolute "test-fixtures/lspoverlay"
  found <-
    published "Uses.pudu" Map.empty $
      Text.unlines
        [ "module Uses"
        , "import Std.Order {Eq}"
        , "type Opaque = { n: Int }"
        , "type Holder = { held: Opaque } derives Eq"
        ]
  let own = fileUri (root </> "Uses.pudu")
  pure $ case found of
    [one] ->
      conjoin
        [ publishedCode one === "E3092"
        , publishedLine one === 3
        , counterexample (show (publishedRelated one))
            (property ((own, 3, "derive requested here") `elem` publishedRelated one))
        , counterexample "a placed note is not repeated in the message"
            (property (not ("note:" `Text.isInfixOf` publishedMessage one)))
        ]
    other -> counterexample (show other) False

testImportedError :: IO Property
testImportedError = do
  root <- makeAbsolute "test-fixtures/lspoverlay"
  found <-
    published "Uses.pudu"
      ( Map.singleton "Faulty.pudu" $
          Text.unlines
            [ "module Faulty"
            , "export fn bad() -> Int { \"text\" }"
            , "export fn shadowed(value: Int) -> Int {"
            , "  let value = 1"
            , "  value"
            , "}"
            ]
      )
      (Text.unlines ["module Uses", "", "import Faulty", "fn main() -> Int { Faulty.bad() }"])
  let faulty = fileUri (root </> "Faulty.pudu")
  pure $
    conjoin
      [ counterexample (show found) (map publishedCode found === ["E3001"])
      , counterexample (show found) (map publishedLine found === [2])
      , counterexample (show found)
          (property (all (("Faulty: " `Text.isPrefixOf`) . publishedMessage) found))
      , counterexample (show found)
          (property (all (elem (faulty, 1, "reported here") . publishedRelated) found))
      ]

testEmptyDerives :: IO Property
testEmptyDerives = do
  found <-
    published "Uses.pudu" Map.empty $
      Text.unlines ["module Uses", "type A = { id: Int } derives", "type B = { id: Int }"]
  pure $ counterexample (show found) $ case found of
    [one] -> conjoin [publishedCode one === "E1065", publishedLine one === 1]
    _ -> property False
