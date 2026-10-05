{-| @Test.Lsp.ImplMembers — an implementation is offered the members it has yet to write. -}
module Pudu.Lsp.ImplMembersSpec (implMemberProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Completion (completionRepaired)
import Pudu.Lsp.Json (Json (..), lookupField, parse, textOf)
import Pudu.Lsp.Protocol (Message (..))
import Pudu.Lsp.Server (Documents, analyse, answer, emptyDocuments, rememberAnalysis)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

implMemberProperties :: [(String, IO Property)]
implMemberProperties =
  [ ("an implementation's body is offered its trait's unwritten members", testCompletion)
  , ("a quick fix writes every required member an implementation lacks", testQuickFix)
  ]

uri :: Text
uri = "file:///pudu-fixtures/Members.pudu"

header :: [Text]
header =
  [ "module Members"
  , "import Std.Order {Ord}"
  , "trait Shape {"
  , "  fn area(self: &Self) -> Int"
  , "  fn label(self: &Self) -> Str { \"shape\" }"
  , "  fn scaled[N](self: &Self, factor: N) -> Self where N: Ord"
  , "}"
  , "trait Holds[T] { fn held(self: &Self) -> T }"
  , "type Square = {side: Int}"
  ]

opened :: Text -> IO Documents
opened content = do
  analysed <- analyse uri content
  pure (rememberAnalysis uri analysed emptyDocuments)

at :: Int -> Int -> Json
at line character = JsonObject
  [ ("textDocument", JsonObject [("uri", JsonText uri)])
  , ("position", JsonObject [("line", JsonNumber (fromIntegral line)), ("character", JsonNumber (fromIntegral character))])
  ]

completions :: [Text] -> Int -> Int -> IO [(Text, Text, Text)]
completions body line character = do
  documents <- opened (Text.unlines (header <> body))
  reply <- completionRepaired (analyse uri) (pure []) documents (at line character)
  pure $ case reply of
    JsonArray members ->
      [ (label, field "detail" member, field "insertText" member)
      | member <- members, Just label <- [lookupField "label" member >>= textOf] ]
    _ -> []
 where
  field name member = maybe "" id (lookupField name member >>= textOf)

testCompletion :: IO Property
testCompletion = do
  empty <- completions ["impl Shape for Square {", "  ", "}"] 10 2
  partial <- completions ["impl Shape for Square {", "  fn area(self: &Self) -> Int { 1 }", "  ", "}"] 11 2
  typing <- completions ["impl Holds[Str] for Square {", "  fn ", "}"] 10 5
  imported <- completions ["impl Ord for Square {", "}"] 10 0
  inside <- completions ["impl Shape for Square {", "  fn area(self: &Self) -> Int { 1 }", "}"] 10 31
  let labels = map (\(label, _, _) -> label)
  pure $ conjoin
    [ counterexample (show empty) (labels empty === ["area", "label", "scaled"])
    , counterexample "a default is offered as an override" (property (any (\(label, detail, _) -> label == "label" && detail == "override Shape.label") empty))
    , counterexample "the signature keeps its parameters and where clause"
        (property (any (\(_, _, text) -> "fn scaled[N](self: &Self, factor: N) -> Self where N: Ord {" `Text.isPrefixOf` text) empty))
    , counterexample "a written member is not offered again" (labels partial === ["label", "scaled"])
    , counterexample (show typing) (map (\(label, _, text) -> (label, Text.takeWhile (/= '{') text)) typing === [("held", "held(self: &Self) -> Str ")])
    , counterexample "an imported trait's members" (labels imported === ["before"])
    , counterexample "a member's body is ordinary code" (property ("area" `notElem` labels inside))
    ]

testQuickFix :: IO Property
testQuickFix = do
  documents <- opened (Text.unlines (header <> ["impl Shape for Square {", "}"]))
  let range = JsonObject [("start", position 9 0), ("end", position 9 0)]
      parameters = JsonObject
        [ ("textDocument", JsonObject [("uri", JsonText uri)]), ("range", range)
        , ("context", JsonObject [("diagnostics", JsonArray [])]) ]
      position line character = JsonObject [("line", JsonNumber line), ("character", JsonNumber character)]
      actions = case answer documents (Request (JsonNumber 1) "textDocument/codeAction" parameters) of
        (_, [reply]) -> case parse reply >>= lookupField "result" of
          Just (JsonArray found) -> found
          _ -> []
        _ -> []
      titled = [action | action <- actions, (lookupField "title" action >>= textOf) == Just "Implement missing members of Shape"]
      inserted = case titled of
        action : _ -> maybe "" id (lookupField "edit" action >>= lookupField "changes" >>= lookupField uri >>= first >>= lookupField "newText" >>= textOf)
        [] -> ""
      first value = case value of
        JsonArray (member : _) -> Just member
        _ -> Nothing
  pure $ conjoin
    [ counterexample (show actions) (length titled === 1)
    , counterexample (Text.unpack inserted) $ inserted ===
        "\n  fn area(self: &Self) -> Int {\n    panic(\"not yet implemented\")\n  }\n\n  fn scaled[N](self: &Self, factor: N) -> Self where N: Ord {\n    panic(\"not yet implemented\")\n  }\n"
    ]
