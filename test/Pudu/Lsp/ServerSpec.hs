{-| @Test.Lsp.Server — what an editor is told about a program -}
module Pudu.Lsp.ServerSpec (serverProperties) where

import Data.List (sortOn)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.IORef (modifyIORef', newIORef, readIORef)
import Pudu.Lsp.Analysis (analyseOver, documentSourceRoot)
import Pudu.Lsp.RepairCache (cachedAnalyse, newRepairCache, repairCapacity)
import Pudu.Lsp.Documents (Analysis (..), analysisOf)
import Pudu.Lsp.Completion (completionRepaired)
import Pudu.Lsp.Definition (definitionAcross, fileUri)
import Pudu.Lsp.Feature (offsetAt, positionAt, wordAt)
import Pudu.Lsp.Json (Json (..), lookupField, parse, textOf)
import Pudu.Lsp.ModuleCatalog (modulesUnder)
import Pudu.Lsp.Protocol (Message (..), Position (..), frame)
import Pudu.Lsp.Server
  ( Documents
  , analyse
  , analyseIn
  , answer
  , emptyDocuments
  , rememberAnalysis
  , serverCapabilities
  )
import System.Directory (getCurrentDirectory, makeAbsolute)
import System.FilePath (normalise, (</>))
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

serverProperties :: [(String, IO Property)]
serverProperties =
  [ ("all implemented capabilities are announced", testCapabilities)
  , ("opening a document publishes what the compiler said", testDiagnostics)
  , ("hover reports the signature the checker inferred", testHover)
  , ("definition points at the declaration of the name under the cursor", testDefinition)
  , ("references locates declaration and use sites", testReferences)
  , ("rename produces atomic workspace edits", testRename)
  , ("document highlight covers identifier occurrences", testHighlight)
  , ("semantic tokens classifies syntax and symbols", testSemanticTokens)
  , ("inlay hints show inferred types for bindings", testInlayHints)
  , ("the outline lists what the file declares", testSymbols)
  , ("completion offers every documented name", testCompletion)
  , ("completion follows pattern and type syntax", testSyntaxDirectedCompletion)
  , ("pattern completion preserves owner payload and coverage", testPatternCompletion)
  , ("a served match arm offers its subject's variants only", testServedPatternCompletion)
  , ("a record literal offers the fields it has not set", testRecordLiteralCompletion)
  , ("an import ranks paths, skips chosen names, and offers as after a path", testImportRefinements)
  , ("an imported name is defined and described where its module declares it", testImportedDeclarations)
  , ("completion distinguishes imports values and prose", testCompletionContexts)
  , ("an import being written is offered whole module paths", testImportPathCompletion)
  , ("the module catalog names every module under a root", testModuleCatalog)
  , ("pattern completion survives a match the checker rejects", testPatternCompletionRejected)
  , ("completion offers only the bindings in scope at the cursor", testLexicalScopeCompletion)
  , ("field completion reads the receiver's canonical record", testRecordFieldCompletion)
  , ("method completion follows the checker's method rules", testMethodCompletion)
  , ("module qualifiers are the ones the imports bind", testImportQualifiers)
  , ("module candidates are exactly a module's exports", testExportCandidates)
  , ("member completion is on the whole receiver expression", testReceiverExpression)
  , ("completion recovers facts from unfinished text", testRecoveredCompletion)
  , ("each document is rooted by its own path and module", testDocumentSourceRoot)
  , ("open documents stand in for the disk in every import", testOpenDocumentOverlay)
  , ("a repair is compiled once while nothing changes", testRepairReuse)
  , ("foreign handles and asserted signatures reach every editor feature", testForeignTooling)
  , ("foreign provenance follows symbol identity through shadowing", testForeignShadowing)
  , ("a cursor is answered from the file it is in, not from an imported module", testImportedDocumentation)
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
    , counterexample "references" (announced "referencesProvider" === Just (JsonBool True))
    , counterexample "rename" (announced "renameProvider" === Just (JsonObject [("prepareProvider", JsonBool True)]))
    , counterexample "highlight" (announced "documentHighlightProvider" === Just (JsonBool True))
    , counterexample "semanticTokens" (property (announced "semanticTokensProvider" /= Nothing))
    , counterexample "signatureHelp" (property (announced "signatureHelpProvider" /= Nothing))
    , counterexample "inlayHint" (announced "inlayHintProvider" === Just (JsonBool True))
    , counterexample "symbols" (announced "documentSymbolProvider" === Just (JsonBool True))
    , counterexample "workspaceSymbols" (announced "workspaceSymbolProvider" === Just (JsonBool True))
    , counterexample "formatting" (announced "documentFormattingProvider" === Just (JsonBool True))
    , counterexample "codeAction" (announced "codeActionProvider" === Just (JsonBool True))
    ]
 where
  announced name = lookupField "capabilities" serverCapabilities >>= lookupField name

testReferences :: IO Property
testReferences = do
  documents <- opened demo
  let refs = request "textDocument/references" (atPosition 3 10) documents
  pure $ conjoin
    [ counterexample "references found for add"
        (property (case refs of Just (JsonArray items) -> not (null items); _ -> False))
    ]

testRename :: IO Property
testRename = do
  documents <- opened demo
  let prepared = request "textDocument/prepareRename" (atPosition 3 10) documents
      renameParams =
        JsonObject
          [ ("textDocument", JsonObject [("uri", JsonText uri)])
          , ("position", JsonObject [("line", JsonNumber 3), ("character", JsonNumber 10)])
          , ("newName", JsonText "sum")
          ]
      renamed = request "textDocument/rename" renameParams documents
  pure $ conjoin
    [ counterexample "prepare rename provides placeholder"
        (property (case prepared of Just (JsonObject fields) -> lookup "placeholder" fields == Just (JsonText "add"); _ -> False))
    , counterexample "rename generates workspace edits"
        (property (case renamed of Just (JsonObject fields) -> lookup "changes" fields /= Nothing; _ -> False))
    ]

testHighlight :: IO Property
testHighlight = do
  documents <- opened demo
  let highlights = request "textDocument/documentHighlight" (atPosition 3 10) documents
  pure $ conjoin
    [ counterexample "highlights found for add"
        (property (case highlights of Just (JsonArray items) -> not (null items); _ -> False))
    ]

testSemanticTokens :: IO Property
testSemanticTokens = do
  documents <- opened demo
  let tokens = request "textDocument/semanticTokens/full" wholeDocument documents
  let hasTokens = case tokens of
        Just (JsonObject fields) -> case lookup "data" fields of
          Just (JsonArray items) -> not (null items)
          _ -> False
        _ -> False
  pure $ conjoin
    [ counterexample "semantic tokens data array present" (property hasTokens)
    ]

testInlayHints :: IO Property
testInlayHints = do
  documents <- opened demo
  let rangeParam =
        JsonObject
          [ ("textDocument", JsonObject [("uri", JsonText uri)])
          , ( "range"
            , JsonObject
                [ ("start", JsonObject [("line", JsonNumber 0), ("character", JsonNumber 0)])
                , ("end", JsonObject [("line", JsonNumber 10), ("character", JsonNumber 0)])
                ]
            )
          ]
      hints = request "textDocument/inlayHint" rangeParam documents
  pure $ conjoin
    [ counterexample "inlay hints returns array"
        (property (case hints of Just (JsonArray _) -> True; _ -> False))
    ]

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
      callerBody =
        request "textDocument/hover" (atPosition 5 5) documents
          >>= lookupField "contents" >>= lookupField "value" >>= textOf
  pure $ conjoin
    [ counterexample "the signature comes first, being the answer to what is this"
        (property (maybe False (Text.isInfixOf "add : Int -> Int -> Int") body))
    , counterexample "the documentation follows it"
        (property (maybe False (Text.isInfixOf "Add two whole numbers.") body))
    , counterexample "and the origin is named"
        (property (maybe False (Text.isInfixOf "function in") body))
    , counterexample "hovering nothing answers null"
        (request "textDocument/hover" (atPosition 1 0) documents === Just JsonNull)
    , counterexample "a keyword is not named after the declaration around it"
        (request "textDocument/hover" (atPosition 5 1) documents === Just JsonNull)
    , counterexample "an operator is not named either"
        (request "textDocument/hover" (atPosition 5 13) documents === Just JsonNull)
    , counterexample "a function taking nothing shows that it takes nothing"
        (property (maybe False (Text.isInfixOf "caller : () -> Int") callerBody))
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

testSyntaxDirectedCompletion :: IO Property
testSyntaxDirectedCompletion = do
  documents <- opened $ Text.unlines
    [ "module Demo"
    , "type State = Ready | Loading | Failed"
    , "type Other = Unrelated | AlsoUnrelated"
    , "fn main(state: State) -> Int {"
    , "  match state {"
    , "    case Ready => 1"
    , "    case Loading => 2"
    , "    case Failed => 3"
    , "  }"
    , "}"
    , "fn identity[T](value: T) -> T { value }"
    ]
  let patterns = completionLabels (request "textDocument/completion" (atPosition 6 11) documents)
      types = completionLabels (request "textDocument/completion" (atPosition 10 29) documents)
  pure $ conjoin
    [ counterexample "the current sum's uncovered variant is offered" (property ("Loading" `elem` patterns))
    , counterexample "an earlier irrefutably covered variant is omitted" (property ("Ready" `notElem` patterns))
    , counterexample "a later variant remains useful at this arm" (property ("Failed" `elem` patterns))
    , counterexample "another sum's variants are absent" (property (all (`notElem` patterns) ["Unrelated", "AlsoUnrelated"]))
    , counterexample "declaration keywords are absent from patterns" (property ("fn" `notElem` patterns))
    , counterexample "the lexical type parameter is offered" (property ("T" `elem` types))
    , counterexample "value keywords are absent from types" (property ("let" `notElem` types))
    ]

testPatternCompletion :: IO Property
testPatternCompletion = do
  generic <- opened $ Text.unlines
    [ "module Demo"
    , "type Payload[T] = Empty | Full(T) | Named{value: T}"
    , "fn main(value: Payload[Int]) -> Int {"
    , "  match value {"
    , "    case Empty => 0"
    , "    case Full(item) => item"
    , "    case Named{value} => value"
    , "  }"
    , "}"
    ]
  collisionContent <- TextIO.readFile "test-fixtures/lspcompletion/Root.pudu"
  collisionAnalysis <- analyseIn "test-fixtures/lspcompletion" uri collisionContent
  let collision = rememberAnalysis uri collisionAnalysis emptyDocuments
  guarded <- opened $ Text.unlines
    [ "module Demo"
    , "type State = Ready | Loading | Failed"
    , "fn main(state: State) -> Int {"
    , "  match state {"
    , "    case Ready if false => 0"
    , "    case Loading => 1"
    , "    case Ready => 2"
    , "    case Failed => 3"
    , "  }"
    , "}"
    ]
  let genericItems = request "textDocument/completion" (atPosition 5 11) generic
      collisionItems = request "textDocument/completion" (atPosition 7 13) collision
      collisionLabels = completionLabels collisionItems
      guardedLabels = completionLabels (request "textDocument/completion" (atPosition 5 11) guarded)
  pure $ conjoin
    [ counterexample "a generic payload substitutes the subject argument"
        (completionDetail "Full" genericItems === Just "Payload.Full(Int)")
    , counterexample ("same-spelling imported variants stay owner-qualified: " <> show collisionLabels)
        (property ("F.Shared" `elem` collisionLabels))
    , counterexample "an imported generic payload retains its concrete argument"
        (completionDetail "F.Shared" collisionItems === Just "First.Shared(Int)")
    , counterexample "the other owner never leaks into the list"
        (property ("OnlySecond" `notElem` collisionLabels))
    , counterexample "a guarded arm does not cover its constructor"
        (property ("Ready" `elem` guardedLabels))
    ]

{-| Pattern completion as the server asks for it, through the repairing path,
    for an arm written whole, one half written, and one not begun. -}
testServedPatternCompletion :: IO Property
testServedPatternCompletion = do
  let header =
        [ "module Demo"
        , "type State = Ready | Loading | Failed"
        , "fn main(state: State) -> Int {"
        , "  match state {"
        , "    case Ready => 1"
        ]
      at arm line character = do
        documents <- opened (Text.unlines (header <> [arm, "  }", "}"]))
        reply <- completionRepaired (analyse uri) (pure []) documents (atPosition line character)
        pure (completionLabels (Just reply))
  whole <- at "    case Loading => 2" 5 11
  half <- at "    case Lo" 5 11
  begun <- at "    case " 5 9
  let variantsOnly labels = counterexample (show labels) (labels === ["Loading", "Failed", "_"])
  pure $ conjoin
    [ counterexample "a whole arm" (variantsOnly whole)
    , counterexample "a half-written arm" (variantsOnly half)
    , counterexample "an arm not yet begun" (variantsOnly begun)
    ]

testRecordLiteralCompletion :: IO Property
testRecordLiteralCompletion = do
  let at body line character = do
        documents <- opened (Text.unlines ["module Demo", "type Point = { x: Int, mut y: Int }", "fn make(n: Int) -> Point {", body, "}"])
        reply <- completionRepaired (analyse uri) (pure []) documents (atPosition line character)
        pure (Just reply)
  empty <- at "  Point{}" 3 8
  afterOne <- at "  Point{x: 1, }" 3 14
  unclosed <- at "  Point{x: 1, " 3 14
  inValue <- at "  Point{x: n, y: 2}" 3 12
  pure $ conjoin
    [ counterexample "every field of an empty literal" (completionLabels empty === ["x", "y"])
    , counterexample "a field's declared type and mutability" (completionDetail "y" empty === Just "mut Int")
    , counterexample "an editor that sorts keeps the declared order" (sortTextOf "x" empty < sortTextOf "y" empty)
    , counterexample "a field already set is left out" (completionLabels afterOne === ["y"])
    , counterexample "an unclosed literal still knows its fields" (completionLabels unclosed === ["y"])
    , counterexample "a field's value is an ordinary value position" (property ("n" `elem` completionLabels inValue))
    ]

sortTextOf :: Text -> Maybe Json -> Maybe Text
sortTextOf wanted value = case value of
  Just (JsonArray members) ->
    listToMaybe [rank | member <- members, (lookupField "label" member >>= textOf) == Just wanted, Just rank <- [lookupField "sortText" member >>= textOf]]
  _ -> Nothing

testImportedDeclarations :: IO Property
testImportedDeclarations = do
  root <- getCurrentDirectory
  let source =
        Text.unlines
          [ "module Demo"
          , "import Std.List as List"
          , "import Std.List { length }"
          , "fn main() -> Int {"
          , "  List.length([1]) + length([2])"
          , "}"
          ]
      readText path = Just <$> TextIO.readFile path
  documents <- opened source
  qualified <- definitionAcross readText uri (analysed documents) (offsetIn source 4 9)
  selected <- definitionAcross readText uri (analysed documents) (offsetIn source 4 24)
  path <- definitionAcross readText uri (analysed documents) (offsetIn source 1 12)
  let described = request "textDocument/hover" (atPosition 4 9) documents
      target reply = lookupField "uri" reply >>= textOf
      listFile = fileUri (normalise (root </> "packages/pudu/v0.1/lib/Std/List.pudu"))
      contents = described >>= lookupField "contents" >>= lookupField "value" >>= textOf
  pure $ conjoin
    [ counterexample (show qualified) (target qualified === Just listFile)
    , counterexample "a selected name is defined where it is exported, not at the import" (target selected === Just listFile)
    , counterexample "an import's path opens its module" (target path === Just listFile)
    , counterexample (show contents) (property (maybe False ("Std.List" `Text.isInfixOf`) contents))
    ]
 where
  analysed documents = case analysisOf uri documents of
    Just value -> value
    Nothing -> error "the document was not stored"
  offsetIn source line character = offsetAt source (Position line character)

testImportRefinements :: IO Property
testImportRefinements = do
  let catalog = pure ["Std.Bytes.Cursor", "Std.Io", "Std.List", "Tools"]
      at content line character = do
        documents <- opened content
        reply <- completionRepaired (analyse uri) catalog documents (atPosition line character)
        pure (Just reply)
  ranked <- at "module Demo\nimport Cur\n" 1 10
  chosen <- at "module Demo\nimport Std.List { length, \n" 1 25
  afterPath <- at "module Demo\nimport Std.List \nfn main() -> Int { 1 }\n" 1 16
  nextLine <- at "module Demo\nimport Std.List\n\nfn main() -> Int { 1 }\n" 2 0
  let triggered content line character typed = do
        documents <- opened content
        let parameters = case atPosition line character of
              JsonObject fields -> JsonObject (fields <> [("context", JsonObject [("triggerKind", JsonNumber 2), ("triggerCharacter", JsonText typed)])])
              other -> other
        reply <- completionRepaired (analyse uri) catalog documents parameters
        pure (Just reply)
  blockBrace <- triggered "module Demo\nfn main() -> Int {}\n" 1 18 "{"
  selectionBrace <- triggered "module Demo\nimport Std.List {}\n" 1 17 "{"
  argumentComma <- triggered "module Demo\nfn add(a: Int, b: Int) -> Int { a }\nfn main() -> Int { add(1,) }\n" 2 25 ","
  let sortTexts = case ranked of
        Just (JsonArray members) -> [(label, sortText) | member <- members, Just label <- [lookupField "label" member >>= textOf], Just sortText <- [lookupField "sortText" member >>= textOf]]
        _ -> []
      firstRanked = fmap fst (listToMaybe (sortOn snd sortTexts))
  pure $ conjoin
    [ counterexample ("a segment the typed name begins ranks first: " <> show sortTexts) (firstRanked === Just "Std.Bytes.Cursor")
    , counterexample "a name the selection holds is not offered again" (property ("length" `notElem` completionLabels chosen))
    , counterexample "the rest of the module's exports are" (property ("take" `elem` completionLabels chosen))
    , counterexample "after a finished path only as is offered" (completionLabels afterPath === ["as"])
    , counterexample "a brace opening a block offers nothing" (completionLabels blockBrace === [])
    , counterexample "a brace opening a selection offers the module's names" (property ("take" `elem` completionLabels selectionBrace))
    , counterexample "a comma between arguments offers nothing" (completionLabels argumentComma === [])
    , counterexample "a line after the import is not part of it" (property ("as" `notElem` completionLabels nextLine || "main" `elem` completionLabels nextLine))
    ]

testCompletionContexts :: IO Property
testCompletionContexts = do
  documents <- opened $ Text.unlines
    [ "module Demo"
    , "import Std.Io as Io"
    , "type Box = { value: Int }"
    , "fn use(value: Int) -> Int { value }"
    , "fn main() -> Int {"
    , "  let local = 1"
    , "  let text = \"inside\""
    , "  // prose only"
    , "  let box = Box{value: local}"
    , "  use(local)"
    , "}"
    ]
  let imports = completionLabels (request "textDocument/completion" (atPosition 1 10) documents)
      inString = completionLabels (request "textDocument/completion" (atPosition 6 15) documents)
      inComment = completionLabels (request "textDocument/completion" (atPosition 7 7) documents)
      recordValue = completionLabels (request "textDocument/completion" (atPosition 8 25) documents)
      callArgument = completionLabels (request "textDocument/completion" (atPosition 9 7) documents)
  pure $ conjoin
    [ counterexample "an import position offers modules" (property ("Std.Io" `elem` imports))
    , counterexample "an import position omits declaration keywords" (property ("fn" `notElem` imports))
    , counterexample "strings offer no code candidates" (inString === [])
    , counterexample "comments offer no code candidates" (inComment === [])
    , counterexample "record initializer values retain lexical scope" (property ("local" `elem` recordValue))
    , counterexample "call arguments retain lexical scope" (property ("local" `elem` callArgument))
    ]

testImportPathCompletion :: IO Property
testImportPathCompletion = do
  let catalog = pure ["Demo", "Std.Collections", "Std.Io", "Tools"]
      at content line character = do
        documents <- opened content
        reply <- completionRepaired (analyse uri) catalog documents (atPosition line character)
        pure (completionLabels (Just reply), reply)
  (partial, partialReply) <- at "module Demo\nimport Std.Co\nfn main() -> Int { 1 }\n" 1 13
  (dotted, _) <- at "module Demo\nimport Std.\n" 1 11
  (bare, _) <- at "module Demo\nimport \n" 1 7
  (finished, _) <- at "module Demo\nimport Std.Io\n\nfn main() -> Int { 1 }\n" 2 0
  (alias, _) <- at "module Demo\nimport Std.Io as \n" 1 17
  (multiline, _) <- at "module Demo\nimport\n  Std.I\n" 2 7
  pure $ conjoin
    [ counterexample "a half-written path is offered the catalog" (property ("Std.Collections" `elem` partial))
    , counterexample "a path ending in a dot is offered the catalog" (property ("Std.Io" `elem` dotted))
    , counterexample "an empty path is offered the catalog" (property ("Tools" `elem` bare))
    , counterexample "the document's own module is never offered" (property ("Demo" `notElem` bare))
    , counterexample "a path spanning lines is still an import path" (property ("Std.Io" `elem` multiline))
    , counterexample "a finished import leaves import context" (property ("Std.Collections" `notElem` finished))
    , counterexample "an alias being chosen is offered nothing" (alias === [])
    , counterexample "the whole written path is replaced"
        (completionEdit "Std.Collections" partialReply === Just ((1, 7), (1, 13)))
    ]

testModuleCatalog :: IO Property
testModuleCatalog = do
  found <- modulesUnder (const True) "test-fixtures/lspcompletion"
  standard <- modulesUnder (== "Std") "packages/pudu/v0.1/lib"
  pure $ conjoin
    [ counterexample (show found) (found === ["First", "Root", "Second"])
    , counterexample "standard modules are named by their path" (property ("Std.Io" `elem` standard))
    , counterexample "nested standard modules are reached" (property (any ("Std.App." `Text.isPrefixOf`) standard))
    ]

testPatternCompletionRejected :: IO Property
testPatternCompletionRejected = do
  documents <- opened $ Text.unlines
    [ "module Demo"
    , "type State = Ready | Loading | Failed"
    , "fn main(state: State) -> Int {"
    , "  match state {"
    , "    case Ready => 1"
    , "    case Loading => 2"
    , "  }"
    , "}"
    ]
  let labels = completionLabels (request "textDocument/completion" (atPosition 5 9) documents)
  pure $ conjoin
    [ counterexample (show labels) (property ("Loading" `elem` labels))
    , counterexample "the uncovered variant is still offered" (property ("Failed" `elem` labels))
    ]

testLexicalScopeCompletion :: IO Property
testLexicalScopeCompletion = do
  documents <- opened $ Text.unlines
    [ "module Demo"                                            -- 0
    , "type Item = SomeItem(Int) | NoItem"                     -- 1
    , "fn main(item: Item, limit: Int) -> Int {"               -- 2
    , "  if true {"                                            -- 3
    , "    let expired = 1"                                    -- 4
    , "    expired"                                            -- 5
    , "  }"                                                    -- 6
    , "  let shadow = 1"                                       -- 7
    , "  let inner = {"                                        -- 8
    , "    let shadow = \"text\""                            -- 9
    , "    shadow.length()"                                    -- 10
    , "  }"                                                    -- 11
    , "  let total = match item {"                             -- 12
    , "    case SomeItem(payload) => payload"                  -- 13
    , "    case NoItem => 0"                                   -- 14
    , "  }"                                                    -- 15
    , "  let add = fn(step: Int) -> Int { step + limit }"      -- 16
    , "  for index in 0..limit {"                              -- 17
    , "    let counted = index"                                -- 18
    , "  }"                                                    -- 19
    , "  if let SomeItem(found) = item { found } else { 0 }"   -- 20
    , "  let SomeItem(kept) = item else { return 0 }"          -- 21
    , "  let fresh = shadow"                                   -- 22
    , "  fresh + kept + later()"                               -- 23
    , "}"                                                      -- 24
    , "fn later() -> Int { 1 }"                                -- 25
    ]
  let at line character = completionLabels (request "textDocument/completion" (atPosition line character) documents)
      detailAt line character name = completionDetail name (request "textDocument/completion" (atPosition line character) documents)
      afterBlock = at 7 2
      insideBlock = at 5 4
      innerShadow = at 10 4
      noItemArm = at 14 20
      someItemArm = at 13 30
      closure = at 16 38
      loopBody = at 18 18
      afterLoop = at 20 2
      ifLetBody = at 20 35
      ifLetElse = at 20 49
      initializer = at 22 14
      tail' = at 23 2
  pure $ conjoin
    [ counterexample "a block's binding is visible inside it" (property ("expired" `elem` insideBlock))
    , counterexample "a block's binding expires with the block" (property ("expired" `notElem` afterBlock))
    , counterexample "parameters are visible in the body" (property (all (`elem` afterBlock) ["item", "limit"]))
    , counterexample "an inner shadow is the one offered inside its block"
        (detailAt 10 4 "shadow" === Just "Str")
    , counterexample "the outer binding returns after the inner block"
        (detailAt 22 14 "shadow" === Just "Int")
    , counterexample "the inner shadow is offered once" (length (filter (== "shadow") innerShadow) === 1)
    , counterexample "a pattern binding is visible in its own arm" (property ("payload" `elem` someItemArm))
    , counterexample "a pattern binding is absent from a sibling arm" (property ("payload" `notElem` noItemArm))
    , counterexample "a closure sees its parameter and the enclosing scope"
        (property (all (`elem` closure) ["step", "limit"]))
    , counterexample "a closure's parameter does not leak" (property ("step" `notElem` afterLoop))
    , counterexample "a loop binder is visible in its body" (property (all (`elem` loopBody) ["index"]))
    , counterexample "a loop binder and body bindings expire with the loop"
        (property (all (`notElem` afterLoop) ["index", "counted"]))
    , counterexample "an if-let binding is visible in its block" (property ("found" `elem` ifLetBody))
    , counterexample "an if-let binding is absent from its else branch" (property ("found" `notElem` ifLetElse))
    , counterexample "a let-else binding stays for the rest of the block" (property ("kept" `elem` tail'))
    , counterexample "a let is not visible in its own initializer" (property ("fresh" `notElem` initializer))
    , counterexample "a module function declared later is offered" (property ("later" `elem` tail'))
    ]

testRecordFieldCompletion :: IO Property
testRecordFieldCompletion = do
  local <- opened $ Text.unlines
    [ "module Demo"
    , "type Box[T] = { mut value: T, plain: T, nested: Array[Option[T]], call: fn(T) -> Str }"
    , "type Boxed = Box[Int]"
    , "fn main(box: Box[Int], borrowed: &Box[Str], aliased: Boxed) -> Int {"
    , "  box.plain"
    , "  borrowed.plain"
    , "  aliased.plain"
    , "}"
    ]
  importedContent <- TextIO.readFile "test-fixtures/lsprecords/Main.pudu"
  importedAnalysis <- analyseIn "test-fixtures/lsprecords" uri importedContent
  let imported = rememberAnalysis uri importedAnalysis emptyDocuments
      boxItems = request "textDocument/completion" (atPosition 4 6) local
      borrowedItems = request "textDocument/completion" (atPosition 5 11) local
      aliasedItems = request "textDocument/completion" (atPosition 6 10) local
      importedLabels = completionLabels (request "textDocument/completion" (atPosition 7 4) imported)
  pure $ conjoin
    [ counterexample "a mutable field is offered with its instantiated type"
        (completionDetail "value" boxItems === Just "mut Int")
    , counterexample "an immutable field is offered with its instantiated type"
        (completionDetail "plain" boxItems === Just "Int")
    , counterexample "nested generics substitute the argument"
        (completionDetail "nested" boxItems === Just "Array[Option[Int]]")
    , counterexample "a function-typed field is one field"
        (completionDetail "call" boxItems === Just "fn(Int) -> Str")
    , counterexample "a reference receiver reaches its record"
        (completionDetail "plain" borrowedItems === Just "Str")
    , counterexample "an alias receiver reaches the record it names"
        (completionDetail "plain" aliasedItems === Just "Int")
    , counterexample ("an imported record's fields are offered: " <> show importedLabels)
        (property (all (`elem` importedLabels) ["x", "label"]))
    , counterexample "a local record of the same name lends no fields"
        (property ("unrelated" `notElem` importedLabels))
    ]

testMethodCompletion :: IO Property
testMethodCompletion = do
  content <- TextIO.readFile "test-fixtures/lspmethods/Main.pudu"
  analysis <- analyseIn "test-fixtures/lspmethods" uri content
  builtin <- opened "module Demo\nfn main(text: Str) -> Int { text.length() }\n"
  let documents = rememberAnalysis uri analysis emptyDocuments
      at line character = completionLabels (request "textDocument/completion" (atPosition line character) documents)
      local = at 16 6
      elsewhere = at 20 6
      bounded = at 24 7
      dynamic = at 28 7
      strings = completionLabels (request "textDocument/completion" (atPosition 1 33) builtin)
  pure $ conjoin
    [ counterexample ("an inherited default is offered: " <> show local) (property ("size" `elem` local))
    , counterexample "an overriding method is offered" (property ("named" `elem` local))
    , counterexample "another module's same-named type lends no method" (property ("wrongMethod" `notElem` local))
    , counterexample ("an imported type offers its own methods: " <> show elsewhere) (property ("wrongMethod" `elem` elsewhere))
    , counterexample "an imported type does not borrow the local type's" (property ("size" `notElem` elsewhere))
    , counterexample ("a where-bound offers its trait's members: " <> show bounded) (property (all (`elem` bounded) ["size", "named"]))
    , counterexample ("a dynamic receiver offers its trait's members: " <> show dynamic) (property ("size" `elem` dynamic))
    , counterexample "a wired-in receiver keeps its runtime methods" (property ("length" `elem` strings))
    , counterexample "each method is offered once" (length (filter (== "size") local) === 1)
    ]

testImportQualifiers :: IO Property
testImportQualifiers = do
  let root = "test-fixtures/lspimports"
      at header body line character = do
        let content = "module Main\n" <> header <> "\nfn main() -> Int {\n  " <> body <> "\n}\n"
        analysis <- analyseIn root uri content
        let documents = rememberAnalysis uri analysis emptyDocuments
        reply <- completionRepaired (analyseIn root uri) (pure []) documents (atPosition line character)
        pure (completionLabels (Just reply))
  bare <- at "import Lib.Tools" "Tools.publicFn()" 3 8
  aliased <- at "import Lib.Tools as T" "T.publicFn()" 3 4
  multiline <- at "import Lib.Tools\n  as T" "T.publicFn()" 4 4
  tabbed <- at "import\tLib.Tools" "Tools.publicFn()" 3 8
  commented <- at "import Lib.Tools // the tools" "Tools.publicFn()" 3 8
  unfinished <- at "import Lib.Tools" "Tools." 3 8
  fullPath <- at "import Lib.Tools" "Lib.Tools." 3 12
  aliasOnly <- at "import Lib.Tools as T" "Tools." 3 8
  selective <- at "import Lib.Tools { publicFn }" "publicFn()" 3 2
  pure $ conjoin
    [ counterexample ("a bare import binds its last segment: " <> show bare) (property ("publicFn" `elem` bare))
    , counterexample "an alias binds the module" (property ("publicFn" `elem` aliased))
    , counterexample "an alias on the next line binds the module" (property ("publicFn" `elem` multiline))
    , counterexample "a tab after import is whitespace" (property ("publicFn" `elem` tabbed))
    , counterexample "a trailing comment changes nothing" (property ("publicFn" `elem` commented))
    , counterexample ("an unfinished member is still answered: " <> show unfinished) (property ("publicFn" `elem` unfinished))
    , counterexample "a full path is not a qualifier" (fullPath === [])
    , counterexample "an aliased import does not also bind its last segment" (aliasOnly === [])
    , counterexample "a selective import binds its items" (property ("publicFn" `elem` selective))
    , counterexample "a selective import binds no qualifier"
        (property (all (`notElem` selective) ["Tools", "Lib.Tools"]))
    ]

testExportCandidates :: IO Property
testExportCandidates = do
  let root = "test-fixtures/lspexports"
      analysed content = rememberAnalysis uri <$> analyseIn root uri content <*> pure emptyDocuments
      program imports = Text.unlines (["module Main"] <> imports <> ["fn main() -> Int {", "  chosen() + L.publicFn()", "}"])
      forward = ["import Lib as L", "import A.Wanted { chosen }", "import Z.Other as Z"]
  written <- analysed (program forward)
  reordered <- analysed (program (reverse forward))
  let members = request "textDocument/completion" (atPosition 5 15) written
      memberLabels = completionLabels members
      chosenIn documents line = completionDetail "chosen" (request "textDocument/completion" (atPosition line 2) documents)
  selectionAnalysis <- analyseIn root uri "module Main\nimport Lib { pub\n"
  selection <- completionRepaired (analyseIn root uri) (pure []) (rememberAnalysis uri selectionAnalysis emptyDocuments) (atPosition 1 15)
  let selectionLabels = completionLabels (Just selection)
  pure $ conjoin
    [ counterexample ("exported names are offered: " <> show memberLabels)
        (property (all (`elem` memberLabels) ["publicFn", "State", "Ready", "Loading", "Handle", "open", "close"]))
    , counterexample "a private function is not offered" (property ("privateFn" `notElem` memberLabels))
    , counterexample "a variant is described as its type's" (completionDetail "Ready" members === Just "State.Ready")
    , counterexample "a selected name is described by the module it came from" (chosenIn written 5 === Just "Int")
    , counterexample "the description does not depend on import order" (chosenIn reordered 5 === Just "Int")
    , counterexample ("an unfinished selection is offered the module's exports: " <> show selectionLabels)
        (property ("publicFn" `elem` selectionLabels && "privateFn" `notElem` selectionLabels))
    ]

testReceiverExpression :: IO Property
testReceiverExpression = do
  let header =
        [ "module Demo"
        , "fn produce(n: Int) -> Str { \"hi\" }"
        , "fn split(text: Str) -> Array[Str] { [text] }"
        , "type Inner = { label: Str }"
        , "type Outer = { inner: Inner }"
        ]
      at body character = do
        documents <- opened (Text.unlines (header <> ["fn main(text: Str, items: Array[Str], outer: Outer) -> Int {", "  " <> body, "}"]))
        pure (completionLabels (request "textDocument/completion" (atPosition 6 character) documents))
  exact <- at "produce(1).length()" 13
  padded <- at "produce(1 ).length()" 14
  spaced <- at "text .length()" 8
  commented <- at "text /* note */ .length()" 19
  indexed <- at "items[0].length()" 11
  chained <- at "outer.inner.label.length()" 20
  nested <- at "produce(split(text).length()).length()" 32
  literal <- at "\"a\".length()" 6
  unicode <- at "\"🦌\".length() + text.length()" 23
  arrayResult <- at "split(text).length()" 14
  midName <- at "text.length()" 9
  pure $ conjoin
    [ counterexample ("a call offers its result's members: " <> show exact) (property ("length" `elem` exact))
    , counterexample "padding inside the call changes nothing" (padded === exact)
    , counterexample "whitespace before the dot changes nothing" (property ("length" `elem` spaced && "let" `notElem` spaced))
    , counterexample "a comment before the dot changes nothing" (property ("length" `elem` commented))
    , counterexample "an index offers the element's members" (property ("length" `elem` indexed))
    , counterexample "a chain offers its last member's members" (property ("length" `elem` chained))
    , counterexample "a nested call offers the outer result's members" (property ("charAt" `elem` nested))
    , counterexample "a literal offers its own members" (property ("charAt" `elem` literal))
    , counterexample "a scalar beyond the BMP earlier on the line changes nothing" (property ("charAt" `elem` unicode))
    , counterexample "a cursor inside the member name is still a member position" (property ("length" `elem` midName))
    , counterexample ("a call's result, not its argument, decides: " <> show arrayResult)
        (property ("charAt" `notElem` arrayResult && not (null arrayResult)))
    ]

testRecoveredCompletion :: IO Property
testRecoveredCompletion = do
  let at content line character = do
        documents <- opened content
        reply <- completionRepaired (analyse uri) (pure []) documents (atPosition line character)
        pure (completionLabels (Just reply))
  unclosedMember <- at "module Demo\nfn main() -> Int {\n  let text = \"hi\"\n  text.\n" 3 7
  partialMember <- at "module Demo\nfn main() -> Int {\n  let text = \"hi\"\n  text.le\n" 3 9
  unclosedMatch <- at "module Demo\ntype State = Ready | Loading | Failed\nfn main(state: State) -> Int {\n  match state {\n    case \n" 4 9
  laterArm <- at "module Demo\ntype State = Ready | Loading | Failed\nfn main(state: State) -> Int {\n  match state {\n    case Ready => 1\n    case Lo\n" 5 11
  payload <- at "module Demo\ntype Color = Red | Green\ntype Item = Holds(Color) | Empty\nfn main(item: Item) -> Int {\n  match item {\n    case Holds(\n" 5 15
  scalarPayload <- at "module Demo\ntype Item = Holds(Int) | Empty\nfn main(item: Item) -> Int {\n  match item {\n    case Holds(\n" 4 15
  binding <- at "module Demo\nfn main() -> Int {\n  let text = \"hi\"\n  let size = \n" 3 13
  nested <- at "module Demo\nfn wrap(s: Str) -> Str { s }\nfn main() -> Int {\n  let text = \"hi\"\n  wrap(wrap(text.\n" 4 17
  elsewhere <- at "module Demo\nfn broken() -> Int { let = }\nfn main() -> Int {\n  let text = \"hi\"\n  text.length()\n}\n" 4 7
  unicode <- at "module Demo\nfn main() -> Int {\n  let text = \"🦌 hi\"\n  text.\n" 3 7
  unknown <- at "module Demo\nfn main() -> Int {\n  missing.\n" 2 10
  written <- opened "module Demo\nfn main() -> Int {\n  let text = \"hi\"\n  text.\n"
  _ <- completionRepaired (analyse uri) (pure []) written (atPosition 3 7)
  let diagnostics = case answer written (Notification "textDocument/didChange" (JsonObject [("textDocument", JsonObject [("uri", JsonText uri)])])) of
        (_, [published]) -> maybe 0 countDiagnostics (parse published)
        _ -> 0
  pure $ conjoin
    [ counterexample ("an unclosed function keeps its receiver: " <> show unclosedMember) (property ("length" `elem` unclosedMember))
    , counterexample "a partial member keeps its receiver" (property ("length" `elem` partialMember))
    , counterexample ("an unclosed match keeps its subject: " <> show unclosedMatch)
        (property (all (`elem` unclosedMatch) ["Ready", "Loading", "Failed"]))
    , counterexample "a later unfinished arm still sees earlier coverage"
        (property ("Loading" `elem` laterArm && "Ready" `notElem` laterArm))
    , counterexample ("a payload is offered its own type's variants: " <> show payload)
        (property (all (`elem` payload) ["Red", "Green"] && all (`notElem` payload) ["Holds", "Empty"]))
    , counterexample "a scalar payload is offered only a wildcard" (scalarPayload === ["_"])
    , counterexample "an unfinished let keeps what is in scope" (property ("text" `elem` binding && "size" `notElem` binding))
    , counterexample "nested open calls are closed" (property ("length" `elem` nested))
    , counterexample "a broken declaration elsewhere is set aside" (property ("length" `elem` elsewhere))
    , counterexample "a scalar beyond the BMP before the edit keeps offsets" (property ("length" `elem` unicode))
    , counterexample "an unknown receiver gets no invented members" (unknown === [])
    , counterexample "diagnostics still describe the written text" (property (diagnostics > 0))
    ]
 where
  countDiagnostics message = case lookupField "params" message >>= lookupField "diagnostics" of
    Just (JsonArray entries) -> length entries
    _ -> 0

testDocumentSourceRoot :: IO Property
testDocumentSourceRoot = do
  working <- getCurrentDirectory
  declared <- documentSourceRoot ["/w"] "file:///w/src/App/Main.pudu" "module App.Main\nfn main() -> Int { 0 }\n"
  commented <- documentSourceRoot ["/w"] "file:///w/src/Main.pudu" "// a program\n/// about it\nmodule Main\n"
  encoded <- documentSourceRoot [] "file:///w/with%20space/src/Main.pudu" "module Main\n"
  mismatched <- documentSourceRoot ["/w"] "file:///w/src/Other.pudu" "module Main\n"
  headerless <- documentSourceRoot ["/w", "/w/nested"] "file:///w/nested/src/Main.pudu" "fn main() -> Int { 0 }\n"
  unfinished <- documentSourceRoot ["/w"] "file:///w/src/Main.pudu" "module \n"
  untitled <- documentSourceRoot ["/w", "/v"] "untitled:Untitled-1" "module Main\n"
  untitledAlone <- documentSourceRoot [] "untitled:Untitled-1" "module Main\n"
  let root = "test-fixtures/lspworkspace"
      program folder = do
        content <- TextIO.readFile (root <> "/" <> folder <> "/src/Main.pudu")
        workspace <- makeAbsolute root
        let file = "file://" <> Text.pack (workspace <> "/" <> folder <> "/src/Main.pudu")
            parameters = JsonObject
              [ ("textDocument", JsonObject [("uri", JsonText file)])
              , ("position", JsonObject [("line", JsonNumber 5), ("character", JsonNumber 4)])
              ]
        sourceRoot <- documentSourceRoot [workspace] file content
        analysis <- analyseIn sourceRoot file content
        let documents = rememberAnalysis file analysis emptyDocuments
        pure (completionLabels (request "textDocument/completion" parameters documents))
  one <- program "one"
  two <- program "two"
  pure $ conjoin
    [ counterexample "a declared module roots its path" (declared === "/w/src")
    , counterexample "a header after comments is found" (commented === "/w/src")
    , counterexample "a percent-encoded path is decoded" (encoded === "/w/with space/src")
    , counterexample "a module its path does not name is rooted at its directory" (mismatched === "/w/src")
    , counterexample "a file without a header is rooted at the nearest folder holding it" (headerless === "/w/nested")
    , counterexample "an unfinished header falls back the same way" (unfinished === "/w")
    , counterexample "an untitled buffer uses the first folder" (untitled === "/w")
    , counterexample "an untitled buffer with no folder uses the working directory" (untitledAlone === working)
    , counterexample ("one program reads its own Lib: " <> show one) (property ("fromOne" `elem` one && "fromTwo" `notElem` one))
    , counterexample ("its sibling reads its own: " <> show two) (property ("fromTwo" `elem` two && "fromOne" `notElem` two))
    ]

testOpenDocumentOverlay :: IO Property
testOpenDocumentOverlay = do
  root <- makeAbsolute "test-fixtures/lspoverlay"
  content <- TextIO.readFile (root <> "/Chain.pudu")
  let file = "file://" <> Text.pack root <> "/Chain.pudu"
      deep = normalise (root <> "/Deep.pudu")
      mid = normalise (root <> "/Mid.pudu")
  fromDisk <- analyseIn root file content
  overlaid <- analyseOver (Map.singleton deep "module Deep\nexport fn deep() -> Str { \"changed\" }\n") root file content
  pure $ conjoin
    [ counterexample "the disk program is clean" (length (analysisDiagnostics fromDisk) === 0)
    , counterexample "a transitive open module's unsaved text is what is compiled"
        (property (not (null (analysisDiagnostics overlaid))))
    , counterexample "every module file read is a dependency"
        (property (all (`Set.member` analysisDependencies fromDisk) [mid, deep]))
    , counterexample "the document itself is not its own dependency"
        (property (not (Set.member (normalise (root <> "/Chain.pudu")) (analysisDependencies fromDisk))))
    ]

testRepairReuse :: IO Property
testRepairReuse = do
  documents <- opened "module Demo\nfn main() -> Int {\n  let text = \"hi\"\n  text.\n"
  valid <- opened "module Demo\nfn main(text: Str) -> Int { text.length() }\n"
  cache <- newRepairCache
  counted <- newIORef (0 :: Int)
  let counting text = modifyIORef' counted (+ 1) >> analyse uri text
      ask generation current line character =
        completionRepaired (cachedAnalyse cache generation uri counting) (pure []) current (atPosition line character)
      compiles = readIORef counted
  first <- ask 1 documents 3 7
  afterFirst <- compiles
  second <- ask 1 documents 3 7
  afterSecond <- compiles
  _ <- ask 2 documents 3 7
  afterEdit <- compiles
  _ <- ask 2 valid 1 33
  afterValid <- compiles
  let crowded = [Text.pack ("module Demo" <> replicate n ' ') | n <- [1 .. repairCapacity + 1]]
  mapM_ (cachedAnalyse cache 3 uri counting) crowded
  beforeEvicted <- compiles
  -- The first of them, the least recently used, has been evicted.
  _ <- cachedAnalyse cache 3 uri counting "module Demo "
  afterEvicted <- compiles
  pure $ conjoin
    [ counterexample "the first request repairs" (property (afterFirst > 0))
    , counterexample "the same request at the same state compiles nothing" (afterSecond === afterFirst)
    , counterexample "the answer is the same" (second === first)
    , counterexample "a new state compiles again" (property (afterEdit > afterSecond))
    , counterexample "a text that answers as written is never repaired" (afterValid === afterEdit)
    , counterexample "the cache is bounded" (afterEvicted === beforeEvicted + 1)
    ]

completionEdit :: Text -> Json -> Maybe ((Int, Int), (Int, Int))
completionEdit wanted reply = case reply of
  JsonArray members -> case [edit | member <- members, (lookupField "label" member >>= textOf) == Just wanted, Just edit <- [lookupField "textEdit" member]] of
    edit : _ -> do
      range <- lookupField "range" edit
      (,) <$> (lookupField "start" range >>= point) <*> (lookupField "end" range >>= point)
    [] -> Nothing
  _ -> Nothing
 where
  point value = do
    JsonNumber line <- lookupField "line" value
    JsonNumber character <- lookupField "character" value
    pure (round line, round character)

completionLabels :: Maybe Json -> [Text]
completionLabels value = case value of
  Just (JsonArray members) -> [label | member <- members, Just label <- [lookupField "label" member >>= textOf]]
  _ -> []

completionDetail :: Text -> Maybe Json -> Maybe Text
completionDetail wanted value = case value of
  Just (JsonArray members) ->
    case [detail | member <- members, (lookupField "label" member >>= textOf) == Just wanted, Just detail <- [lookupField "detail" member >>= textOf]] of
      detail : _ -> Just detail
      [] -> Nothing
  _ -> Nothing

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

{-| A span is an offset into one file, so a declaration of an imported module
    says nothing about where a cursor in this file is.

    The fixture is built so the imported declaration's span both covers the
    cursor and is narrower than the declaration the cursor is really in, which
    is what an index spanning several files makes possible. -}
testImportedDocumentation :: IO Property
testImportedDocumentation = do
  content <- TextIO.readFile "test-fixtures/lsphover/Root.pudu"
  analysed <- analyseIn "test-fixtures/lsphover" uri content
  let documents = rememberAnalysis uri analysed emptyDocuments
      shown = request "textDocument/hover" (atPosition 5 11) documents
      hoverBody = shown >>= lookupField "contents" >>= lookupField "value" >>= textOf
      listed = request "textDocument/documentSymbol" wholeDocument documents
  pure $ conjoin
    [ counterexample "hover answers about the declaration under the cursor"
        (property (maybe False (Text.isInfixOf "Documentation belonging to Root.") hoverBody))
    , counterexample "and never about a declaration of another module"
        (property (maybe True (not . Text.isInfixOf "Helper") hoverBody))
    , counterexample "the outline lists what this file declares and nothing else"
        (fmap outlineNames listed === Just ["rootOnly"])
    ]
 where
  outlineNames value = case value of
    JsonArray members -> [name | member <- members, Just name <- [lookupField "name" member >>= textOf]]
    _ -> []

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
  let (_, replies) = answer documents (Request (JsonNumber 7) "workspace/unknownRequest" (JsonObject []))
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
