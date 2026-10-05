{-| @Test.Lsp.DeriveTooling — a cursor in derive syntax is answered from the text as written. -}
module Pudu.Lsp.DeriveToolingSpec (deriveToolingProperties) where

import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Json (Json (..), integerOf, lookupField, parse, textOf)
import Pudu.Lsp.Protocol (Message (..))
import Pudu.Lsp.Server (Documents, analyse, answer, emptyDocuments, rememberAnalysis)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

deriveToolingProperties :: [(String, IO Property)]
deriveToolingProperties =
  [ ("a derives entry and a derive header name their trait", testTraitNames)
  , ("a derive template's metadata has its checked types", testTemplateTypes)
  , ("a derive template's member is described as the derive's", testTemplateMember)
  ]

uri :: Text
uri = "file:///pudu-fixtures/Tooling.pudu"

source :: Text
source =
  Text.unlines
    [ "module Tooling"
    , "import Std.Meta"
    , "import Std.Show {Show}"
    , "trait Tell { fn tell(self: &Self) -> Str }"
    , "derive Tell for T: Sum {"
    , "  fn tell(self: &T) -> Str {"
    , "    comptime for variant: Meta.Variant[T] in Meta.variants[T]() {"
    , "      if variant.matches(self) {"
    , "        comptime for field: Meta.Field[T, F] in variant.fields() where F: Show {"
    , "          return field.name + field.get(self).show()"
    , "        }"
    , "        return variant.name"
    , "      }"
    , "    }"
    , "    \"\""
    , "  }"
    , "}"
    , "type Shape = Dot | Circle(Int) derives Tell"
    , "export fn main() -> Str { Circle(1).tell() }"
    ]

opened :: IO Documents
opened = do
  analysed <- analyse uri source
  pure (rememberAnalysis uri analysed emptyDocuments)

ask :: Documents -> Text -> Int -> Int -> Maybe Json
ask documents method line character =
  case answer documents (Request (JsonNumber 1) method parameters) of
    (_, [reply]) -> parse reply >>= lookupField "result"
    _ -> Nothing
 where
  parameters =
    JsonObject
      [ ("textDocument", JsonObject [("uri", JsonText uri)])
      , ("position", JsonObject [("line", JsonNumber (fromIntegral line)), ("character", JsonNumber (fromIntegral character))])
      ]

hoverText :: Maybe Json -> Text
hoverText found = maybe "" id (found >>= lookupField "contents" >>= lookupField "value" >>= textOf)

definitionLine :: Maybe Json -> Maybe Int
definitionLine found = found >>= lookupField "range" >>= lookupField "start" >>= lookupField "line" >>= integerOf

labels :: Maybe Json -> [Text]
labels found = case found of
  Just (JsonArray items) -> mapMaybe (\item -> lookupField "label" item >>= textOf) items
  _ -> []

testTraitNames :: IO Property
testTraitNames = do
  documents <- opened
  pure $
    conjoin
      [ counterexample "derives Tell" (definitionLine (ask documents "textDocument/definition" 17 41) === Just 3)
      , counterexample "derive Tell for" (definitionLine (ask documents "textDocument/definition" 4 8) === Just 3)
      , counterexample (Text.unpack (hoverText (ask documents "textDocument/hover" 17 41)))
          (property ("trait in `Tooling`" `Text.isInfixOf` hoverText (ask documents "textDocument/hover" 17 41)))
      ]

testTemplateTypes :: IO Property
testTemplateTypes = do
  documents <- opened
  let variantMembers = labels (ask documents "textDocument/completion" 7 17)
      fieldMembers = labels (ask documents "textDocument/completion" 9 23)
  pure $
    conjoin
      [ counterexample (show variantMembers) (property (all (`elem` variantMembers) ["matches", "fields", "name"]))
      , counterexample (show fieldMembers) (property (all (`elem` fieldMembers) ["get", "name", "has"]))
      , counterexample "hover on a variant binding"
          (property ("variant : Variant[T]" `Text.isInfixOf` hoverText (ask documents "textDocument/hover" 7 12)))
      ]

testTemplateMember :: IO Property
testTemplateMember = do
  documents <- opened
  let described = hoverText (ask documents "textDocument/hover" 5 6)
  pure $ counterexample (Text.unpack described) (property ("derive T" `Text.isInfixOf` described))
