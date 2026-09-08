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

import Control.Exception (SomeException, displayException, evaluate, try)
import Control.Monad (unless)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Maybe (fromMaybe)
import qualified Data.ByteString as ByteString
import qualified Data.Text.Encoding as Encoding
import Pudu.Version (versionText)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler (CompileResult (..))
import Pudu.Compiler.Program (ProgramResult (..), compileProgramSource, programDocs, rootCompileResult)
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
import Pudu.Lsp.CodeAction (codeActionsAt)
import Pudu.Lsp.Completion (completionAt)
import Pudu.Lsp.Definition (definitionAt)
import Pudu.Lsp.Documents
  ( Analysis (..)
  , Documents (..)
  , analysisOf
  , documentOf
  , emptyDocuments
  , forgetDocument
  , rememberAnalysis
  , setWorkspaceRoot
  , uriOf
  , workspaceRoot
  )
import Pudu.Lsp.Feature
  ( documentSymbols
  , offsetAt
  , rangeOfOffsets
  )
import Pudu.Lsp.Highlight (documentHighlightAt)
import Pudu.Lsp.Hover (hoverAt)
import Pudu.Lsp.InlayHints (inlayHintsAt)
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import Pudu.Lsp.Protocol
  ( Incoming (..)
  , Message (..)
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
import Pudu.Lsp.SignatureHelp (signatureHelpAt)
import Pudu.Lsp.WorkspaceSymbols (workspaceSymbolsAt)
import Pudu.Source (SourceName (..), newSource, spanEnd, spanStart, unOffset)
import System.Directory (doesDirectoryExist, doesFileExist, getCurrentDirectory)
import System.Exit (ExitCode (ExitFailure), exitWith)
import System.FilePath ((</>), takeDirectory)
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

{-| Compile one document's text as the program it is.

    The compile is the ordinary one, so an editor sees exactly what `pudu check`
    would print — the same codes, spans, and help — and `pudu doc` and the
    editor agree about every signature. A second implementation for the editor
    would drift from the first within a release. -}
analyse :: Text -> Text -> IO Analysis
analyse uri content = do
  root <- resolveSourceRoot Nothing uri
  analyseIn root uri content

analyseIn :: FilePath -> Text -> Text -> IO Analysis
analyseIn root uri content = do
  source <- newSource (SourceName (pathOf uri)) content
  program <- compileProgramSource root source
  pure
    Analysis
      { analysisText = content
      , analysisSource = source
      , analysisDiagnostics = programDiagnostics program
      , analysisFileIndex = fromMaybe mempty (rootCompileResult program >>= compileDocs)
      , analysisProgramIndex = programDocs program
      , analysisResolution = rootCompileResult program >>= compileResolution
      , analysisTypes = rootCompileResult program >>= compileTypes
      }

{-| Determine the project root for compilation.

    When the client declared a workspace root at initialization, that root is
    authoritative. Otherwise, walk up looking for repository/project boundary
    markers (`pudu.cabal`, `.git`, or `lib`), falling back to the file's directory. -}
resolveSourceRoot :: Maybe FilePath -> Text -> IO FilePath
resolveSourceRoot (Just root) _ = pure root
resolveSourceRoot Nothing uri = do
  working <- getCurrentDirectory
  case Text.stripPrefix "file://" uri of
    Nothing -> pure working
    Just path -> do
      let docDir = takeDirectory (Text.unpack (decodeUri path))
      findProjectRoot docDir docDir (8 :: Int)
 where
  findProjectRoot fallback current depth
    | depth <= 0 = pure fallback
    | otherwise = do
        hasCabal <- doesFileExist (current </> "pudu.cabal")
        hasGit <- doesDirectoryExist (current </> ".git")
        hasLib <- doesDirectoryExist (current </> "lib")
        if hasCabal || hasGit || hasLib
          then pure current
          else
            let parent = takeDirectory current
             in if parent == current then pure fallback else findProjectRoot fallback parent (depth - 1)

pathOf :: Text -> Text
pathOf uri = maybe uri decodeUri (Text.stripPrefix "file://" uri)

{-| Turn `%20` and friends back into the scalars they stand for. -}
decodeUri :: Text -> Text
decodeUri input = either (const input) id (Encoding.decodeUtf8' (ByteString.pack (go input)))
 where
  go rest = case Text.uncons rest of
    Nothing -> []
    Just ('%', remaining)
      | Text.length hex == 2, Just value <- hexValue hex ->
          fromIntegral value : go (Text.drop 2 remaining)
     where
      hex = Text.take 2 remaining
    Just (scalar, remaining) -> ByteString.unpack (Encoding.encodeUtf8 (Text.singleton scalar)) <> go remaining

  hexValue hex = case Text.foldl' step (Just 0) hex of
    Just value -> Just value
    Nothing -> Nothing
  step accumulated scalar = do
    total <- accumulated
    digit <- hexDigit scalar
    pure (total * 16 + digit)
  hexDigit scalar
    | scalar >= '0' && scalar <= '9' = Just (fromEnum scalar - fromEnum '0')
    | scalar >= 'a' && scalar <= 'f' = Just (fromEnum scalar - fromEnum 'a' + 10)
    | scalar >= 'A' && scalar <= 'F' = Just (fromEnum scalar - fromEnum 'A' + 10)
    | otherwise = Nothing

runServer :: IO ()
runServer = do
  hSetBinaryMode stdin True
  hSetBinaryMode stdout True
  hSetBuffering stdout NoBuffering
  store <- newIORef emptyDocuments
  loop store

loop :: IORef Documents -> IO ()
loop store = do
  incoming <- readMessage stdin
  case incoming of
    EndOfStream -> pure ()
    NotForServer -> loop store
    Unreadable reason -> do
      TextIO.hPutStrLn stderr ("pudu lsp: ignored a message; " <> reason)
      hFlush stderr
      loop store
    Unframed reason -> do
      TextIO.hPutStrLn stderr ("pudu lsp: stopping; " <> reason)
      hFlush stderr
      exitWith (ExitFailure 1)
    Received message -> do
      documents <- readIORef store
      outcome <- try (prepare documents message)
      case outcome of
        Right (documents', replies) -> do
          writeIORef store documents'
          mapM_ (emit stdout) replies
        Left failure -> mapM_ (emit stdout) =<< excuse message failure
      unless (isExit message) (loop store)

prepare :: Documents -> Message -> IO (Documents, [Text])
prepare documents message = do
  documents' <- refresh documents message
  let (documents'', replies) = answer documents' message
  mapM_ (evaluate . Text.length) replies
  pure (documents'', replies)

excuse :: Message -> SomeException -> IO [Text]
excuse message failure = do
  TextIO.hPutStrLn stderr ("pudu lsp: " <> subject <> " failed; " <> detail)
  hFlush stderr
  pure $ case message of
    Request identity _ _ -> [errorResponse identity internalError detail]
    Notification _ _ -> []
 where
  subject = case message of
    Request _ method _ -> method
    Notification method _ -> method
  detail = Text.strip (Text.pack (displayException failure))

refresh :: Documents -> Message -> IO Documents
refresh documents message = case message of
  Request _ "initialize" parameters ->
    pure $ case extractWorkspaceRoot parameters of
      Just root -> setWorkspaceRoot root documents
      Nothing -> documents
  Notification "textDocument/didOpen" parameters ->
    case (uriOf parameters, openedText parameters) of
      (Just uri, Just content) -> store uri content
      _ -> pure documents
  Notification "textDocument/didChange" parameters ->
    case (uriOf parameters, changedText parameters) of
      (Just uri, Just content) -> store uri content
      _ -> pure documents
  _ -> pure documents
 where
  store uri content = do
    root <- resolveSourceRoot (workspaceRoot documents) uri
    analysed <- analyseIn root uri content
    pure (rememberAnalysis uri analysed documents)

extractWorkspaceRoot :: Json -> Maybe FilePath
extractWorkspaceRoot params =
  case lookupField "rootUri" params >>= textOf of
    Just uri | Just path <- Text.stripPrefix "file://" uri ->
      Just (Text.unpack (decodeUri path))
    _ -> case lookupField "workspaceFolders" params of
      Just (JsonArray (folder : _)) ->
        case lookupField "uri" folder >>= textOf of
          Just uri | Just path <- Text.stripPrefix "file://" uri ->
            Just (Text.unpack (decodeUri path))
          _ -> Nothing
      _ -> case lookupField "rootPath" params >>= textOf of
        Just path | not (Text.null path) -> Just (Text.unpack path)
        _ -> Nothing

isExit :: Message -> Bool
isExit message = case message of
  Notification "exit" _ -> True
  _ -> False

emit :: Handle -> Text -> IO ()
emit handle body = do
  TextIO.hPutStr handle (frame body)
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

internalError :: Int
internalError = -32603

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
            , JsonObject [("triggerCharacters", JsonArray [JsonText "."])]
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
