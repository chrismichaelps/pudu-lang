{-| @Test.Lsp.Server — what an editor is told about a program -}
module Pudu.Lsp.ServerSpec (serverProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Lsp.Feature (offsetAt, positionAt, wordAt)
import Pudu.Lsp.Json (Json (..), lookupField, parse, textOf)
import Pudu.Lsp.Protocol (Message (..), Position (..), frame)
import Pudu.Lsp.Server
  ( Documents
  , analyse
  , answer
  , emptyDocuments
  , rememberAnalysis
  , serverCapabilities
  )
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

serverProperties :: [(String, IO Property)]
serverProperties =
  [ ("only implemented capabilities are announced", testCapabilities)
  , ("opening a document publishes what the compiler said", testDiagnostics)
  , ("hover reports the signature the checker inferred", testHover)
  , ("definition points at the declaration of the name under the cursor", testDefinition)
  , ("the outline lists what the file declares", testSymbols)
  , ("completion offers every documented name", testCompletion)
  , ("foreign handles and asserted signatures reach every editor feature", testForeignTooling)
  , ("foreign provenance follows symbol identity through shadowing", testForeignShadowing)
  , ("formatting replaces the document in one edit", testFormatting)
  , ("an unknown request is refused rather than ignored", testUnknownRequest)
  , ("a notification is never answered", testNotificationSilence)
  , ("positions convert through UTF-16 code units", testPositions)
  , ("framing counts bytes, not scalars", testFraming)
  ]

demo :: Text
demo =
  Text.unlines
    [ "module Demo"
    , ""
    , "/// Add two whole numbers."
    , "export fn add(a: Int, b: Int) -> Int { a + b }"
    , ""
    , "fn caller() -> Int { add(1, 2) }"
    ]

broken :: Text
broken =
  Text.unlines
    [ "module Demo"
    , "fn wrong() -> Int { \"text\" }"
    ]

foreignDemo :: Text
foreignDemo =
  Text.unlines
    [ "module Demo"
    , ""
    , "foreign \"c\" {"
    , "  type Box"
    , "  fn pudu_ffi_cpp_box_new(value: Int32) -> owned Box by pudu_ffi_cpp_box_delete"
    , "  fn readBox symbol \"pudu_ffi_cpp_box_read\"(box: Box) -> Int32"
    , "  fn pudu_ffi_cpp_box_delete(box: Box) -> ()"
    , "}"
    , ""
    , "fn caller(box: Box) -> Int32 { unsafe(foreign) { readBox(box) } }"
    ]

foreignShadowDemo :: Text
foreignShadowDemo =
  Text.unlines
    [ "module Demo"
    , ""
    , "foreign \"c\" {"
    , "  fn readBox symbol \"abs\"(value: Int32) -> Int32"
    , "}"
    , ""
    , "fn caller(readBox: Int32) -> Int32 { readBox }"
    ]

{-| The name of the document under test.

    The server is handed the text of a document alongside its name and never
    opens the name itself, so this points at no file on any machine. -}
uri :: Text
uri = "file:///pudu-fixtures/Demo.pudu"

opened :: Text -> IO Documents
opened content = do
  analysed <- analyse uri content
  pure (rememberAnalysis uri analysed emptyDocuments)

request :: Text -> Json -> Documents -> Maybe Json
request method parameters documents =
  case answer documents (Request (JsonNumber 1) method parameters) of
    (_, [reply]) -> parse reply >>= lookupField "result"
    _ -> Nothing

atPosition :: Int -> Int -> Json
atPosition line character =
  JsonObject
    [ ("textDocument", JsonObject [("uri", JsonText uri)])
    , ("position", JsonObject [("line", JsonNumber (fromIntegral line)), ("character", JsonNumber (fromIntegral character))])
    ]

wholeDocument :: Json
wholeDocument = JsonObject [("textDocument", JsonObject [("uri", JsonText uri)])]

{-| A capability announced and then not honoured is worse than one withheld: the
    editor stops offering its own fallback and the reader gets nothing. -}
testCapabilities :: IO Property
testCapabilities =
  pure $ conjoin
    [ counterexample "hover" (announced "hoverProvider" === Just (JsonBool True))
    , counterexample "definition" (announced "definitionProvider" === Just (JsonBool True))
    , counterexample "symbols" (announced "documentSymbolProvider" === Just (JsonBool True))
    , counterexample "formatting" (announced "documentFormattingProvider" === Just (JsonBool True))
    , counterexample "nothing claims to rename, which is not implemented"
        (announced "renameProvider" === Nothing)
    , counterexample "nor to find references"
        (announced "referencesProvider" === Nothing)
    ]
 where
  announced name = lookupField "capabilities" serverCapabilities >>= lookupField name

{-| The editor sees exactly what `pudu check` prints, because it is the same
    compile. -}
testDiagnostics :: IO Property
testDiagnostics = do
  documents <- opened broken
  clean <- opened demo
  let reported = published documents
      quiet = published clean
  pure $ conjoin
    [ counterexample "the code travels separately from the prose"
        ((reported >>= lookupField "code" >>= textOf) === Just "E3001")
    , counterexample "an error is severity one"
        ((reported >>= lookupField "severity") === Just (JsonNumber 1))
    , counterexample "the help is kept, since the protocol has nowhere else for it"
        (property (maybe False (Text.isInfixOf "change the value") (reported >>= lookupField "message" >>= textOf)))
    , counterexample "a program that checks reports nothing" (quiet === Nothing)
    ]
 where
  published documents =
    case answer documents (Notification "textDocument/didOpen" wholeDocument) of
      (_, [reply]) -> do
        parsed <- parse reply
        entries <- lookupField "params" parsed >>= lookupField "diagnostics"
        case entries of
          JsonArray (first : _) -> Just first
          _ -> Nothing
      _ -> Nothing

testHover :: IO Property
testHover = do
  documents <- opened demo
  let shown = request "textDocument/hover" (atPosition 3 12) documents
      body = shown >>= lookupField "contents" >>= lookupField "value" >>= textOf
  pure $ conjoin
    [ counterexample "the signature comes first, being the answer to what is this"
        (property (maybe False (Text.isInfixOf "add : Int -> Int -> Int") body))
    , counterexample "the documentation follows it"
        (property (maybe False (Text.isInfixOf "Add two whole numbers.") body))
    , counterexample "and the origin is named"
        (property (maybe False (Text.isInfixOf "function in") body))
    , counterexample "hovering nothing answers null"
        (request "textDocument/hover" (atPosition 1 0) documents === Just JsonNull)
    ]

{-| A reader asks for the definition of a *use*, which is nowhere near the
    declaration's own span. -}
testDefinition :: IO Property
testDefinition = do
  documents <- opened demo
  let found = request "textDocument/definition" (atPosition 5 22) documents
      line = found >>= lookupField "range" >>= lookupField "start" >>= lookupField "line"
  pure $ conjoin
    [ counterexample "the use resolves to the declaring line" (line === Just (JsonNumber 3))
    , counterexample "and carries the file it is in"
        ((found >>= lookupField "uri" >>= textOf) === Just uri)
    , counterexample "a cursor on nothing answers null"
        (request "textDocument/definition" (atPosition 1 0) documents === Just JsonNull)
    ]

testSymbols :: IO Property
testSymbols = do
  documents <- opened demo
  let listed = request "textDocument/documentSymbol" wholeDocument documents
  pure $ conjoin
    [ counterexample "both declarations appear" (fmap count listed === Just 2)
    , counterexample "each carries its signature as detail"
        (property (maybe False (Text.isInfixOf "Int -> Int -> Int") (listed >>= names "detail")))
    , counterexample "and its name" (property (maybe False (Text.isInfixOf "add") (listed >>= names "name")))
    ]
 where
  count value = case value of
    JsonArray members -> length members
    _ -> 0
  names field value = case value of
    JsonArray members ->
      Just (Text.intercalate " " [content | member <- members, Just content <- [lookupField field member >>= textOf]])
    _ -> Nothing

testCompletion :: IO Property
testCompletion = do
  documents <- opened demo
  let offered = request "textDocument/completion" wholeDocument documents
  pure
    ( counterexample "every documented name is offered"
        (fmap size offered === Just 2)
    )
 where
  size value = case value of
    JsonArray members -> length members
    _ -> 0

testForeignTooling :: IO Property
testForeignTooling = do
  documents <- opened foreignDemo
  let shown = request "textDocument/hover" (atPosition 9 52) documents
      hoverBody = shown >>= lookupField "contents" >>= lookupField "value" >>= textOf
      found = request "textDocument/definition" (atPosition 9 52) documents
      definitionLine = found >>= lookupField "range" >>= lookupField "start" >>= lookupField "line"
      listed = request "textDocument/documentSymbol" wholeDocument documents
      offered = request "textDocument/completion" wholeDocument documents
  pure $ conjoin
    [ counterexample "hover keeps the compiler-inferred handle signature"
        (property (maybe False (Text.isInfixOf "Box -> Int32") hoverBody))
    {-| The requirement is part of the signature, so a reader sees what calling
        it needs without being told separately. It is in the type because that
        is what stops the requirement being lost when the function is stored in
        a variable or handed to a parameter. -}
    , counterexample "hover shows what calling the function requires"
        (property (maybe False (Text.isInfixOf "unsafe(foreign)") hoverBody))
    , counterexample "hover identifies an asserted foreign boundary"
        (property (maybe False (Text.isInfixOf "foreign function from c, asserted rather than proved") hoverBody))
    , counterexample "definition reaches the foreign declaration"
        (definitionLine === Just (JsonNumber 5))
    , counterexample "the outline contains the opaque handle type"
        (property (containsLabel "Box" listed))
    , counterexample "completion contains the opaque handle type"
        (property (containsLabel "Box" offered))
    , counterexample "completion contains the local name of a mapped foreign function"
        (property (containsLabel "readBox" offered))
    ]
 where
  containsLabel expected value = case value of
    Just (JsonArray members) ->
      any (== Just expected) [lookupField "label" member >>= textOf | member <- members]
        || any (== Just expected) [lookupField "name" member >>= textOf | member <- members]
    _ -> False

testForeignShadowing :: IO Property
testForeignShadowing = do
  documents <- opened foreignShadowDemo
  let shown = request "textDocument/hover" (atPosition 6 40) documents
      hoverBody = shown >>= lookupField "contents" >>= lookupField "value" >>= textOf
      found = request "textDocument/definition" (atPosition 6 40) documents
      definitionCharacter =
        found >>= lookupField "range" >>= lookupField "start" >>= lookupField "character"
  pure $ conjoin
    [ counterexample "the shadowing parameter keeps its inferred type"
        (property (maybe False (Text.isInfixOf "readBox : Int32") hoverBody))
    , counterexample "the shadowing parameter is not labelled foreign"
        (property (maybe True (not . Text.isInfixOf "asserted rather than proved") hoverBody))
    , counterexample "definition resolves to the parameter, not the foreign declaration"
        (definitionCharacter === Just (JsonNumber 10))
    ]

{-| One edit rather than a computed minimal set: the formatter only moves
    whitespace, so replacing everything cannot change the program. -}
testFormatting :: IO Property
testFormatting = do
  messy <- opened (Text.unlines ["module Demo", "fn add( a : Int )->Int{a}"])
  tidy <- opened demo
  let edits = request "textDocument/formatting" wholeDocument messy
      none = request "textDocument/formatting" wholeDocument tidy
  pure $ conjoin
    [ counterexample "an unformatted document gets exactly one edit"
        (fmap size edits === Just 1)
    , counterexample "whose text is the formatted document"
        (property (maybe False (Text.isInfixOf "fn add(a: Int) -> Int { a }") (newText edits)))
    , counterexample "a formatted document gets none" (fmap size none === Just 0)
    ]
 where
  size value = case value of
    JsonArray members -> length members
    _ -> 0
  newText value = case value of
    Just (JsonArray (first : _)) -> lookupField "newText" first >>= textOf
    _ -> Nothing

{-| An unknown request must be refused, because a client waits for an answer to
    every request it sends. -}
testUnknownRequest :: IO Property
testUnknownRequest = do
  documents <- opened demo
  let (_, replies) = answer documents (Request (JsonNumber 7) "textDocument/rename" (JsonObject []))
      body = case replies of
        [reply] -> parse reply
        _ -> Nothing
  pure $ conjoin
    [ counterexample "exactly one reply" (length replies === 1)
    , counterexample "carrying the request's identifier"
        ((body >>= lookupField "id") === Just (JsonNumber 7))
    , counterexample "and method-not-found"
        ((body >>= lookupField "error" >>= lookupField "code") === Just (JsonNumber (-32601)))
    ]

{-| Replying to a notification is the one protocol error a client cannot
    recover from: it waits forever for a response to a request it never made. -}
testNotificationSilence :: IO Property
testNotificationSilence = do
  documents <- opened demo
  pure $ conjoin
    [ counterexample "an unknown notification is silent"
        (length (snd (answer documents (Notification "$/setTrace" (JsonObject [])))) === 0)
    , counterexample "so is initialized"
        (length (snd (answer documents (Notification "initialized" (JsonObject [])))) === 0)
    ]

{-| An editor's cursor after one emoji reports character 2, because the protocol
    counts UTF-16 code units. Reading it as scalars lands a position early and
    grows worse along the line. -}
testPositions :: IO Property
testPositions =
  pure $ conjoin
    [ offsetAt "abc\ndef" (Position 1 2) === 6
    , offsetAt "abc\ndef" (Position 0 0) === 0
    , counterexample "an astral scalar counts as two units"
        (offsetAt "\128512x" (Position 0 2) === 1)
    , counterexample "and the offset after it accounts for that"
        (offsetAt "\128512x" (Position 0 3) === 2)
    , counterexample "the inverse agrees" (positionAt "abc\ndef" 6 === Position 1 2)
    , counterexample "including across an astral scalar"
        (positionAt "\128512x" 1 === Position 0 2)
    , counterexample "a word is found from inside it" (wordAt "let value = 1" 6 === Just "value")
    , counterexample "and nothing is found in whitespace" (wordAt "a  b" 2 === Nothing)
    ]

{-| Getting the length wrong by one byte desynchronises every message after
    it. -}
testFraming :: IO Property
testFraming =
  pure $ conjoin
    [ counterexample "ascii" (headerOf (frame "{}") === Just "2")
    , counterexample "an accented scalar is two bytes"
        (headerOf (frame "\233") === Just "2")
    , counterexample "an emoji is four" (headerOf (frame "\128512") === Just "4")
    , counterexample "the body follows a blank line"
        (property (Text.isInfixOf "\r\n\r\n" (frame "{}")))
    ]
 where
  headerOf framed = do
    header <- case Text.splitOn "\r\n" framed of
      first : _ -> Just first
      [] -> Nothing
    Text.stripPrefix "Content-Length: " header
