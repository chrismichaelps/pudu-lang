{-| @Program.Lsp.Server.Module — answers an editor about a program -}
module Pudu.Lsp.Server
  ( Analysis (..)
  , Documents
  , analyse
  , answer
  , emptyDocuments
  , rememberAnalysis
  , runServer
  , serverCapabilities
  ) where

import Control.Exception (SomeException, evaluate, displayException, try)
import Control.Monad (unless)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
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
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..))
import Pudu.Format (FormatResult (..), formatSource)
import Pudu.Lsp.Feature
  ( completionItems
  , documentSymbols
  , offsetAt
  , rangeOfOffsets
  )
import Pudu.Lsp.Json (Json (..), lookupField, textOf)
import Pudu.Lsp.Definition (definitionAt)
import Pudu.Lsp.Hover (hoverAt)
import Pudu.Lsp.Documents
  ( Analysis (..)
  , Documents (..)
  , analysisOf
  , documentOf
  , emptyDocuments
  , forgetDocument
  , rememberAnalysis
  , uriOf
  )
import Pudu.Lsp.Protocol
  ( Incoming (..)
  , Message (..)
  , errorResponse
  , frame
  , notification
  , positionOf
  , rangeJson
  , readMessage
  , response
  )
import Pudu.Source (SourceName (..), newSource, spanEnd, spanStart, unOffset)
import Data.Char (isAlphaNum)
import Data.List (nub, sort)
import Pudu.Eval.Operator (builtinMethodNamesFor)
import Pudu.Type (Type (..), narrowestAt)
import Pudu.Type.Value (nominalName)
import System.Directory (getCurrentDirectory)
import System.Exit (ExitCode (ExitFailure), exitWith)
import System.FilePath (takeDirectory)
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
  source <- newSource (SourceName (pathOf uri)) content
  working <- getCurrentDirectory
  let root = sourceRootFor uri working
  program <- compileProgramSource root source
  pure
    Analysis
      { analysisText = content
      , analysisSource = source
      , analysisDiagnostics = programDiagnostics program
      , analysisIndex = programDocs program
      , analysisResolution = rootCompileResult program >>= compileResolution
      , analysisTypes = rootCompileResult program >>= compileTypes
      }

{-| A file's own directory is its source root, which is what makes a sibling
    module importable from an editor the same way it is from the command
    line. When the URI is not a file path, the working directory stands in. -}
sourceRootFor :: Text -> FilePath -> FilePath
sourceRootFor uri working = case Text.stripPrefix "file://" uri of
  Just path -> takeDirectory (Text.unpack (decodeUri path))
  Nothing -> working

pathOf :: Text -> Text
pathOf uri = maybe uri decodeUri (Text.stripPrefix "file://" uri)

{-| Turn `%20` and friends back into the scalars they stand for, so a path with
    a space is the path the reader sees. -}
decodeUri :: Text -> Text
decodeUri = go Text.empty
 where
  go accumulated rest = case Text.uncons rest of
    Nothing -> accumulated
    Just ('%', remaining)
      | Text.length hex == 2, Just value <- hexValue hex ->
          go (Text.snoc accumulated (toEnum value)) (Text.drop 2 remaining)
     where
      hex = Text.take 2 remaining
    Just (scalar, remaining) -> go (Text.snoc accumulated scalar) remaining
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

{-| Run the server over stdin and stdout until the client closes the stream.

    Both handles are binary: the protocol frames messages by byte length, and a
    handle that translated newlines or re-encoded text would make that length a
    lie. -}
runServer :: IO ()
runServer = do
  hSetBinaryMode stdin True
  hSetBinaryMode stdout True
  hSetBuffering stdout NoBuffering
  store <- newIORef emptyDocuments
  loop store

{-| Read a message, answer it, and go round again.

    Only the stream ending stops the loop. A frame the server cannot decode
    costs that frame and nothing else, which is what the protocol asks of a
    server, and a client's own reply carries no method and needs no answer. -}
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
    {-| A framing fault cannot be recovered from: there is no marker in the
        protocol to resynchronise on, so every later read would be guesswork.
        It leaves with a failing status, because an editor that saw success
        would report a clean shutdown for a session that actually broke. -}
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

{-| Work out the answer to one message, with its replies forced.

    `answer` is pure and its replies are built lazily, so a failure inside one
    would otherwise surface where it is written to the handle rather than where
    it can be caught. Forcing them here puts the whole of the work inside the
    same guarded region. -}
prepare :: Documents -> Message -> IO (Documents, [Text])
prepare documents message = do
  documents' <- refresh documents message
  let (documents'', replies) = answer documents' message
  mapM_ (evaluate . Text.length) replies
  pure (documents'', replies)

{-| Report a failure without ending the session.

    A request is answered, because a client that receives nothing waits for it
    for as long as the session lasts. A notification has no reply to carry the
    news, so it goes to the error stream, which is where an editor collects a
    server's output. The document store keeps whatever it last held, since what
    a failed analysis would have stored is unknown. -}
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

{-| Recompile before answering, when the message carried new text. This is the
    only place the server does IO on a document's behalf, which is what keeps
    every handler a pure function of what was compiled. -}
refresh :: Documents -> Message -> IO Documents
refresh documents message = case message of
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
    analysed <- analyse uri content
    pure (rememberAnalysis uri analysed documents)

isExit :: Message -> Bool
isExit message = case message of
  Notification "exit" _ -> True
  _ -> False

emit :: Handle -> Text -> IO ()
emit handle body = do
  TextIO.hPutStr handle (frame body)
  hFlush handle

{-| Answer one message.

    A pure function of what has already been compiled, so every behaviour here
    is testable without a client, a socket, or a running editor. -}
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
  "textDocument/documentSymbol" -> Just symbols
  "textDocument/completion" -> Just completion
  "textDocument/formatting" -> Just formatting
  _ -> Nothing

methodNotFound :: Int
methodNotFound = -32601

internalError :: Int
internalError = -32603

{-| What this server can do, answered once at startup.

    Only what is implemented is claimed. A capability announced and then not
    honoured is worse than one withheld: the editor stops offering its own
    fallback and the reader gets nothing at all. -}
serverCapabilities :: Json
serverCapabilities =
  JsonObject
    [ ( "capabilities"
      , JsonObject
          [ ("textDocumentSync", JsonNumber 1)
          , ("hoverProvider", JsonBool True)
          , ("definitionProvider", JsonBool True)
          , ("documentSymbolProvider", JsonBool True)
          , ("documentFormattingProvider", JsonBool True)
          , ( "completionProvider"
            , JsonObject [("triggerCharacters", JsonArray [JsonText "."])]
            )
          ]
      )
    , ( "serverInfo"
      , JsonObject [("name", JsonText "pudu"), ("version", JsonText "0.1.0.0")]
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

{-| Render one compiler diagnostic as the protocol's shape.

    The code travels as `code` rather than being folded into the message, so an
    editor can link `E3001` to its documentation and a reader can silence one
    class of warning without matching on prose. The help line is appended to the
    message because the protocol has nowhere else for it and losing it would
    lose the part that says what to do. -}
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

{-| The protocol's severity numbers. A note is information rather than a
    problem, which is what keeps it out of an editor's error count. -}
severityCode :: Severity -> Int
severityCode severity = case severity of
  Error -> 1
  Warning -> 2
  Note -> 3

hover :: Documents -> Json -> Json
hover documents parameters = case located documents parameters of
  Nothing -> JsonNull
  Just (value, offset) -> hoverAt value offset

{-| Jump to where a name was declared.

    The name under the cursor is matched against the index rather than the span
    under it, because a reader asks for the definition of a *use*, and a use is
    nowhere near the declaration's span. -}
definition :: Documents -> Json -> Json
definition documents parameters = case (uriOf parameters, located documents parameters) of
  (Just uri, Just (value, offset)) -> definitionAt uri value offset
  _ -> JsonNull

symbols :: Documents -> Json -> Json
symbols documents parameters = case documentOf documents parameters of
  Nothing -> JsonArray []
  Just value -> documentSymbols (analysisText value) (analysisIndex value)

completion :: Documents -> Json -> Json
completion documents parameters = case documentOf documents parameters of
  Nothing -> JsonArray []
  Just value -> case located documents parameters of
    {-| After a dot, offer what the value carries rather than what the module
        declares. The names come from the tables dispatch reads, so what the
        editor offers and what a call finds cannot drift apart.

        A request without a position asks about the document rather than a
        place in it, and is answered as it always was. -}
    Just (_, offset) -> case memberMethods value offset of
      names@(_ : _) -> JsonArray (map methodItem names)
      [] -> completionItems (analysisIndex value)
    Nothing -> completionItems (analysisIndex value)

{-| The methods the value before the cursor's dot carries, or none.

    The receiver is the expression ending where the dot is, which the checker
    already recorded a type for. Nothing is offered where the cursor is not
    after a dot, or where the receiver has no type — a list of names that do not
    apply costs a reader more than no list. -}
memberMethods :: Analysis -> Int -> [Text]
memberMethods value offset = case receiverEnd (analysisText value) offset of
  Nothing -> []
  Just dotOffset -> case analysisTypes value >>= narrowestAt (dotOffset - 1) of
    Nothing -> []
    Just typeValue ->
      let owner = ownerNameOf typeValue
       in sort (nub (methodsOfType typeValue <> implMethodsFor (analysisIndex value) owner))

{-| The methods an `impl` block wrote for this type.

    A type a reader declared carries what they gave it, and offering only the
    built-in sets would answer for `Str` and `Array` and say nothing about
    anything they wrote themselves. The index already names the type each
    method was implemented for. -}
implMethodsFor :: DocIndex -> Text -> [Text]
implMethodsFor index owner
  | Text.null owner = []
  | otherwise =
      [ docName entry
      | entry <- indexEntries index
      , DocMethod target <- [docKind entry]
      , target == owner
      ]

{-| The name a type is written under, which is what selects its methods. -}
ownerNameOf :: Type -> Text
ownerNameOf typeValue = case throughReferenceType typeValue of
  NominalType identity _ -> nominalName identity
  _ -> ""

{-| Where the receiver ends, when the cursor is completing a member of it.

    The cursor may sit straight after the dot or partway through a name, so the
    name being typed is skipped back over first. -}
receiverEnd :: Text -> Int -> Maybe Int
receiverEnd content offset =
  let before = Text.take offset content
      typed = Text.takeWhileEnd nameScalar before
      atDot = Text.dropEnd (Text.length typed) before
   in if Text.isSuffixOf "." atDot then Just (Text.length atDot - 1) else Nothing
 where
  nameScalar scalar = isAlphaNum scalar || scalar == '_'

methodsOfType :: Type -> [Text]
methodsOfType typeValue = case throughReferenceType typeValue of
  NominalType identity _ -> builtinMethodNamesFor (nominalName identity)
  _ -> []

throughReferenceType :: Type -> Type
throughReferenceType typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReferenceType target
  other -> other

methodItem :: Text -> Json
methodItem name =
  JsonObject [("label", JsonText name), ("kind", JsonNumber 2), ("detail", JsonText "method")]

{-| Format the whole document in one edit.

    One edit rather than a computed minimal set: the formatter guarantees it
    only moves whitespace, so replacing everything cannot change the program,
    and a client applies a single replacement atomically. -}
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

{-| A change carries the whole document, because the server announced full
    synchronisation. Accepting an incremental edit it did not ask for would mean
    applying a range it has no guarantee it can interpret. -}
changedText :: Json -> Maybe Text
changedText parameters = case lookupField "contentChanges" parameters of
  Just (JsonArray changes) -> case reverse changes of
    latest : _ -> lookupField "text" latest >>= textOf
    [] -> Nothing
  _ -> Nothing
