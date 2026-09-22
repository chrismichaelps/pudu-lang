{-| @Program.Lsp.Server.Module — answers an editor about a program -}
module Pudu.Lsp.Server
  ( Analysis (..)
  , Documents
  , analyse
  , analyseIn
  , answer
  , emptyDocuments
  , rememberAnalysis
  , runServer
  , serverCapabilities
  ) where

import Control.Concurrent.MVar (newMVar, withMVar)
import Control.Exception (IOException, evaluate, try)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import System.FilePath (normalise)
import qualified Data.ByteString as ByteString
import qualified Data.Text.Encoding as Encoding
import Pudu.Version (versionText)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Diagnostic
  ( Diagnostic
  , Severity (..)
  , diagnosticCode
  , diagnosticCodeText
  , diagnosticHelp
  , diagnosticMessage
  , diagnosticSeverity
  , diagnosticSpan
  )
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Lsp.Analysis (analyse, analyseIn, analyseOver, documentSourceRoot, fileUriPath)
import Pudu.Lsp.CodeAction (codeActionsAt)
import Pudu.Lsp.Completion (completionAt, completionRepaired)
import Pudu.Lsp.Definition (definitionAcross, definitionAt)
import Pudu.Lsp.Documents
  ( Analysis (..)
  , Documents (..)
  , allDocuments
  , analysisOf
  , documentOf
  , documentGeneration
  , emptyDocuments
  , forgetDocument
  , nextGeneration
  , rememberAnalysis
  , setWorkspaceFolders
  , uriOf
  , workspaceFolders
  )
import Pudu.Lsp.Feature
  ( documentSymbols
  , offsetAt
  , rangeOfOffsets
  )
import Pudu.Lsp.Highlight (documentHighlightAt)
import Pudu.Lsp.Hover (hoverAt)
import Pudu.Lsp.InlayHints (inlayHintsAt)
import Pudu.Lsp.ModuleCatalog (moduleCatalog)
import Pudu.Lsp.RepairCache (RepairCache, cachedAnalyse, newRepairCache)
import Pudu.Lsp.Scheduler (schedule)
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import Pudu.Lsp.Protocol
  ( Message (..)
  , errorResponse
  , frame
  , notification
  , positionOf
  , rangeJson
  , rangeOf
  , readMessage
  , response
  )
import Pudu.Lsp.References (referencesAt)
import Pudu.Lsp.Rename (prepareRenameAt, renameAt)
import Pudu.Lsp.SemanticTokens (semanticTokensFull, semanticTokensLegend)
import Pudu.Lsp.SignatureHelp (signatureHelpAt, signatureHelpRepaired)
import Pudu.Lsp.WorkspaceSymbols (workspaceSymbolsAt)
import Pudu.Source (spanEnd, spanStart, unOffset)
import System.Exit (ExitCode (ExitFailure), exitWith)
import System.IO
  ( BufferMode (NoBuffering)
  , Handle
  , hFlush
  , hSetBinaryMode
  , hSetBuffering
  , stderr
  , stdin
  , stdout
  )

runServer :: IO ()
runServer = do
  hSetBinaryMode stdin True
  hSetBinaryMode stdout True
  hSetBuffering stdout NoBuffering
  catalogs <- newIORef Map.empty
  repairs <- newRepairCache
  writing <- newMVar ()
  let session = Session catalogs repairs
      -- Replies and cancellations are written from two threads; each frame
      -- is written whole.
      write body = withMVar writing (const (emit stdout body))
      logLine line = TextIO.hPutStrLn stderr ("pudu lsp: " <> line) >> hFlush stderr
      step documents message = do
        invalidateCatalogs catalogs message
        prepare session documents message
  ended <- schedule (readMessage stdin) write logLine step emptyDocuments
  case ended of
    Right () -> pure ()
    Left _ -> exitWith (ExitFailure 1)

{-| The modules each source root offers an import, found once and kept until a
    file is saved, created, or removed — the only events that change them. -}
type Catalogs = IORef (Map FilePath [Text])

{-| What the session keeps beside the documents: work that is expensive to
    redo and valid until something changes. -}
data Session = Session
  { sessionCatalogs :: !Catalogs
  , sessionRepairs :: !(IORef RepairCache)
  }

invalidateCatalogs :: Catalogs -> Message -> IO ()
invalidateCatalogs catalogs message = case message of
  Notification method _
    | method `elem` ["textDocument/didSave", "workspace/didChangeWatchedFiles", "workspace/didCreateFiles", "workspace/didDeleteFiles", "workspace/didRenameFiles"] ->
        writeIORef catalogs Map.empty
  _ -> pure ()

{-| The catalog for the source root a document compiles under, built on first
    use. -}
catalogFor :: Catalogs -> Documents -> Json -> IO [Text]
catalogFor catalogs documents parameters = do
  root <- rootOf documents parameters
  known <- readIORef catalogs
  case Map.lookup root known of
    Just found -> pure found
    Nothing -> do
      found <- moduleCatalog root
      _ <- evaluate (length found)
      writeIORef catalogs (Map.insert root found known)
      pure found

prepare :: Session -> Documents -> Message -> IO (Documents, [Text])
prepare session documents message = do
  (documents', touched) <- refresh documents message
  (documents'', replies) <- case message of
    Request identity "textDocument/completion" parameters -> do
      items <-
        completionRepaired (repaired documents' parameters) (catalogFor (sessionCatalogs session) documents' parameters)
          documents' parameters
      pure (documents', [response identity items])
    Request identity "textDocument/definition" parameters -> do
      found <- case (uriOf parameters, located documents' parameters) of
        (Just uri, Just (value, offset)) -> definitionAcross (textOfFile documents') uri value offset
        _ -> pure JsonNull
      pure (documents', [response identity found])
    Request identity "textDocument/signatureHelp" parameters -> do
      help <- case located documents' parameters of
        Just (value, offset) -> signatureHelpRepaired (repaired documents' parameters) value offset
        Nothing -> pure JsonNull
      pure (documents', [response identity help])
    _ -> pure (answer documents' message)
  -- Another open document whose program read the one that changed was
  -- analysed again, and what it reports may have changed with it.
  let republished = [publish uri (diagnosticEntries (analysisOf uri documents'')) | uri <- touched]
  mapM_ (evaluate . Text.length) (replies <> republished)
  pure (documents'', replies <> republished)
 where
  -- A repaired text compiled for this state of the documents is not compiled
  -- again while the state holds.
  repaired current parameters =
    cachedAnalyse (sessionRepairs session) (documentGeneration current) (fromMaybe "" (uriOf parameters))
      (reanalyse current parameters)

{-| Compile other text as the document a request names, for an answer the text
    as written cannot give. Nothing is stored: the editor's copy stays the one
    every other answer is read from. The source root is the written
    document's, so a repaired or probe text reaches the same modules. -}
reanalyse :: Documents -> Json -> Text -> IO Analysis
reanalyse documents parameters content = do
  let uri = fromMaybe "" (uriOf parameters)
  root <- rootOf documents parameters
  analyseOver (overlayFor documents uri) root uri content

{-| The text of the file at `path`: the editor's copy when it is open, since it
    holds edits the disk has not seen, and otherwise the disk's, read as UTF-8.
    Nothing when neither can be read. -}
textOfFile :: Documents -> FilePath -> IO (Maybe Text)
textOfFile documents path =
  case [analysisText value | (uri, value) <- allDocuments documents, fmap normalise (fileUriPath uri) == Just (normalise path)] of
    open : _ -> pure (Just open)
    [] -> do
      read' <- try (ByteString.readFile path) :: IO (Either IOException ByteString.ByteString)
      pure (either (const Nothing) (either (const Nothing) Just . Encoding.decodeUtf8') read')

{-| The text of every open document except `uri`, by the normalised path of
    its file: what a compile reads in place of the disk, because the editor's
    copy of an open file is authoritative. -}
overlayFor :: Documents -> Text -> Map FilePath Text
overlayFor documents uri =
  Map.fromList
    [ (normalise path, analysisText value)
    | (other, value) <- allDocuments documents
    , other /= uri
    , Just path <- [fileUriPath other]
    ]

{-| The source root of the document a request names, from the text the editor
    holds for it. -}
rootOf :: Documents -> Json -> IO FilePath
rootOf documents parameters =
  let uri = fromMaybe "" (uriOf parameters)
      written = maybe "" analysisText (documentOf documents parameters)
   in documentSourceRoot (workspaceFolders documents) uri written

{-| Take in what a message says the files now hold, and analyse again every
    open document whose program read a file that changed. The documents
    analysed again beside the one the message named are returned, so their
    diagnostics can be published too.

    An edit to an open module changes what its importers see; closing it hands
    authority back to the disk; a file changed on disk while closed — saved by
    another tool, created, deleted — changes it too. A save of an open file
    changes nothing: its buffer was already what everything read. -}
refresh :: Documents -> Message -> IO (Documents, [Text])
refresh documents message = case message of
  Request _ "initialize" parameters ->
    pure (setWorkspaceFolders (extractWorkspaceFolders parameters) documents, [])
  Notification "textDocument/didOpen" parameters ->
    case (uriOf parameters, openedText parameters) of
      (Just uri, Just content) -> store uri content
      _ -> pure (documents, [])
  Notification "textDocument/didChange" parameters ->
    case (uriOf parameters, changedText parameters) of
      (Just uri, Just content) -> store uri content
      _ -> pure (documents, [])
  Notification "textDocument/didClose" parameters -> case uriOf parameters of
    Just uri -> dependentsOf (forgetDocument uri documents) [uri]
    Nothing -> pure (documents, [])
  Notification "workspace/didChangeWatchedFiles" parameters ->
    dependentsOf (nextGeneration documents)
      [ uri
      | Just (JsonArray changes) <- [lookupField "changes" parameters]
      , change <- changes
      , Just uri <- [lookupField "uri" change >>= textOf]
      , Nothing <- [analysisOf uri documents]
      ]
  Notification method _
    | method `elem` ["workspace/didCreateFiles", "workspace/didDeleteFiles", "workspace/didRenameFiles"] ->
        pure (nextGeneration documents, [])
  _ -> pure (documents, [])
 where
  store uri content = do
    analysed <- analyseDocument documents uri content
    dependentsOf (rememberAnalysis uri analysed documents) [uri]

{-| Analyse again every open document other than `changed` whose program read
    one of `changed`'s files. -}
dependentsOf :: Documents -> [Text] -> IO (Documents, [Text])
dependentsOf documents changed = go documents [] stale
 where
  paths = Set.fromList [normalise path | uri <- changed, Just path <- [fileUriPath uri]]
  stale =
    [ uri
    | (uri, value) <- allDocuments documents
    , uri `notElem` changed
    , not (Set.disjoint paths (analysisDependencies value))
    ]
  go current touched pending = case pending of
    [] -> pure (current, reverse touched)
    uri : rest -> case analysisOf uri current of
      Nothing -> go current touched rest
      Just value -> do
        analysed <- analyseDocument current uri (analysisText value)
        go (rememberAnalysis uri analysed current) (uri : touched) rest

{-| Analyse a document's text under its own source root, reading the other open
    documents in place of the disk. -}
analyseDocument :: Documents -> Text -> Text -> IO Analysis
analyseDocument documents uri content = do
  root <- documentSourceRoot (workspaceFolders documents) uri content
  analyseOver (overlayFor documents uri) root uri content

{-| Every folder the editor opened: each workspace folder, and the older
    single `rootUri` or `rootPath` when a client sends only that. -}
extractWorkspaceFolders :: Json -> [FilePath]
extractWorkspaceFolders params =
  distinct (folders <> rootUri <> rootPath)
 where
  folders = case lookupField "workspaceFolders" params of
    Just (JsonArray entries) -> [path | entry <- entries, Just path <- [lookupField "uri" entry >>= textOf >>= fileUriPath]]
    _ -> []
  rootUri = [path | Just path <- [lookupField "rootUri" params >>= textOf >>= fileUriPath]]
  rootPath = [Text.unpack path | Just path <- [lookupField "rootPath" params >>= textOf], not (Text.null path)]
  distinct = foldr (\path kept -> if path `elem` kept then kept else path : kept) []

{-| Write one framed message as UTF-8.

    The handle is in binary mode, where writing text keeps only the low byte of
    each scalar. The frame's length counts UTF-8 bytes, so text written that way
    is shorter than its header says whenever it holds anything beyond ASCII —
    a documentation comment with a dash is enough — and the client then waits
    for bytes that never come. The frame is encoded before it is written. -}
emit :: Handle -> Text -> IO ()
emit handle body = do
  ByteString.hPut handle (Encoding.encodeUtf8 (frame body))
  hFlush handle

answer :: Documents -> Message -> (Documents, [Text])
answer documents message = case message of
  Request identity "initialize" _ ->
    (documents, [response identity serverCapabilities])
  Request identity "shutdown" _ -> (documents, [response identity JsonNull])
  Request identity method parameters ->
    (documents, [respond identity method parameters])
  Notification "textDocument/didOpen" parameters -> (documents, published parameters)
  Notification "textDocument/didChange" parameters -> (documents, published parameters)
  Notification "textDocument/didSave" parameters -> (documents, published parameters)
  Notification "textDocument/didClose" parameters -> case uriOf parameters of
    Nothing -> (documents, [])
    Just uri -> (forgetDocument uri documents, [publish uri []])
  Notification _ _ -> (documents, [])
 where
  respond identity method parameters = case handler method of
    Nothing ->
      errorResponse identity methodNotFound ("no handler for " <> method)
    Just answerWith -> response identity (answerWith documents parameters)

  published parameters = case uriOf parameters of
    Nothing -> []
    Just uri -> [publish uri (diagnosticEntries (analysisOf uri documents))]

handler :: Text -> Maybe (Documents -> Json -> Json)
handler method = case method of
  "textDocument/hover" -> Just hover
  "textDocument/definition" -> Just definition
  "textDocument/references" -> Just references
  "textDocument/prepareRename" -> Just prepareRename
  "textDocument/rename" -> Just rename
  "textDocument/documentHighlight" -> Just highlight
  "textDocument/semanticTokens/full" -> Just semanticTokens
  "textDocument/signatureHelp" -> Just signatureHelp
  "textDocument/inlayHint" -> Just inlayHint
  "textDocument/documentSymbol" -> Just symbols
  "textDocument/completion" -> Just completionAt
  "textDocument/formatting" -> Just formatting
  "textDocument/codeAction" -> Just codeAction
  "workspace/symbol" -> Just workspaceSymbols
  _ -> Nothing

methodNotFound :: Int
methodNotFound = -32601

serverCapabilities :: Json
serverCapabilities =
  JsonObject
    [ ( "capabilities"
      , JsonObject
          [ ("textDocumentSync", JsonNumber 1)
          , ("hoverProvider", JsonBool True)
          , ("definitionProvider", JsonBool True)
          , ("referencesProvider", JsonBool True)
          , ("renameProvider", JsonObject [("prepareProvider", JsonBool True)])
          , ("documentHighlightProvider", JsonBool True)
          , ( "semanticTokensProvider"
            , JsonObject
                [ ("legend", semanticTokensLegend)
                , ("full", JsonBool True)
                ]
            )
          , ( "signatureHelpProvider"
            , JsonObject
                [ ("triggerCharacters", JsonArray [JsonText "(", JsonText ","])
                , ("retriggerCharacters", JsonArray [JsonText ","])
                ]
            )
          , ("inlayHintProvider", JsonBool True)
          , ("documentSymbolProvider", JsonBool True)
          , ("workspaceSymbolProvider", JsonBool True)
          , ("documentFormattingProvider", JsonBool True)
          , ("codeActionProvider", JsonBool True)
          , ( "completionProvider"
            , JsonObject [("triggerCharacters", JsonArray [JsonText ".", JsonText "{", JsonText ","])]
            )
          ]
      )
    , ( "serverInfo"
      , JsonObject [("name", JsonText "pudu"), ("version", JsonText versionText)]
      )
    ]

publish :: Text -> [Json] -> Text
publish uri entries =
  notification
    "textDocument/publishDiagnostics"
    (JsonObject [("uri", JsonText uri), ("diagnostics", JsonArray entries)])

diagnosticEntries :: Maybe Analysis -> [Json]
diagnosticEntries found = case found of
  Nothing -> []
  Just value -> map (diagnosticJson (analysisText value)) (analysisDiagnostics value)

diagnosticJson :: Text -> Diagnostic -> Json
diagnosticJson content value =
  JsonObject
    [ ("range", rangeJson (rangeOfOffsets content start end))
    , ("severity", JsonNumber (fromIntegral (severityCode (diagnosticSeverity value))))
    , ("code", JsonText (diagnosticCodeText (diagnosticCode value)))
    , ("source", JsonText "pudu")
    , ("message", JsonText message)
    ]
 where
  spanValue = diagnosticSpan value
  start = unOffset (spanStart spanValue)
  end = unOffset (spanEnd spanValue)
  message = case diagnosticHelp value of
    Nothing -> diagnosticMessage value
    Just guidance -> diagnosticMessage value <> "\n\n" <> guidance

severityCode :: Severity -> Int
severityCode severity = case severity of
  Error -> 1
  Warning -> 2
  Note -> 3

hover :: Documents -> Json -> Json
hover documents parameters = case located documents parameters of
  Nothing -> JsonNull
  Just (value, offset) -> hoverAt value offset

{-| The declaration in this document a name resolves to. The server answers
    definition through `definitionAcross`, which also reaches other modules'
    files; this is the answer from the document alone. -}
definition :: Documents -> Json -> Json
definition documents parameters = case (uriOf parameters, located documents parameters) of
  (Just uri, Just (value, offset)) -> definitionAt uri value offset
  _ -> JsonNull

references :: Documents -> Json -> Json
references documents parameters = case (uriOf parameters, located documents parameters) of
  (Just uri, Just (value, offset)) ->
    let includeDecl =
          case lookupField "context" parameters >>= lookupField "includeDeclaration" of
            Just (JsonBool b) -> b
            _ -> False
     in referencesAt uri value offset includeDecl
  _ -> JsonArray []

prepareRename :: Documents -> Json -> Json
prepareRename documents parameters = case located documents parameters of
  Just (value, offset) -> prepareRenameAt value offset
  Nothing -> JsonNull

rename :: Documents -> Json -> Json
rename documents parameters = case (uriOf parameters, located documents parameters) of
  (Just uri, Just (value, offset)) ->
    case lookupField "newName" parameters >>= textOf of
      Just newName -> renameAt uri value offset newName
      Nothing -> JsonNull
  _ -> JsonNull

highlight :: Documents -> Json -> Json
highlight documents parameters = case located documents parameters of
  Just (value, offset) -> documentHighlightAt value offset
  Nothing -> JsonArray []

semanticTokens :: Documents -> Json -> Json
semanticTokens documents parameters = case documentOf documents parameters of
  Just value -> semanticTokensFull value
  Nothing -> JsonObject [("data", JsonArray [])]

signatureHelp :: Documents -> Json -> Json
signatureHelp documents parameters = case located documents parameters of
  Just (value, offset) -> signatureHelpAt value offset
  Nothing -> JsonNull

inlayHint :: Documents -> Json -> Json
inlayHint documents parameters =
  case (documentOf documents parameters, lookupField "range" parameters >>= rangeOf) of
    (Just value, Just reqRange) -> inlayHintsAt value reqRange
    _ -> JsonArray []

symbols :: Documents -> Json -> Json
symbols documents parameters = case documentOf documents parameters of
  Nothing -> JsonArray []
  Just value -> documentSymbols (analysisText value) (analysisFileIndex value)

workspaceSymbols :: Documents -> Json -> Json
workspaceSymbols documents parameters =
  let query = maybe "" id (lookupField "query" parameters >>= textOf)
   in workspaceSymbolsAt documents query

codeAction :: Documents -> Json -> Json
codeAction documents parameters =
  case (uriOf parameters, documentOf documents parameters, lookupField "range" parameters >>= rangeOf) of
    (Just uri, Just value, Just reqRange) ->
      codeActionsAt uri value reqRange (maybe (JsonObject []) id (lookupField "context" parameters))
    _ -> JsonArray []

formatting :: Documents -> Json -> Json
formatting documents parameters = case documentOf documents parameters of
  Nothing -> JsonArray []
  Just value -> JsonArray (edits value)
 where
  edits value =
    let content = analysisText value
        result = formatText' (formatSource (analysisSource value))
     in [ JsonObject
            [ ("range", rangeJson (rangeOfOffsets content 0 (Text.length content)))
            , ("newText", JsonText result)
            ]
        | result /= content
        ]

located :: Documents -> Json -> Maybe (Analysis, Int)
located documents parameters = do
  value <- documentOf documents parameters
  position <- lookupField "position" parameters >>= positionOf
  pure (value, offsetAt (analysisText value) position)

openedText :: Json -> Maybe Text
openedText parameters =
  lookupField "textDocument" parameters >>= lookupField "text" >>= textOf

changedText :: Json -> Maybe Text
changedText parameters = case lookupField "contentChanges" parameters of
  Just (JsonArray changes) -> case reverse changes of
    latest : _ -> lookupField "text" latest >>= textOf
    [] -> Nothing
  _ -> Nothing
