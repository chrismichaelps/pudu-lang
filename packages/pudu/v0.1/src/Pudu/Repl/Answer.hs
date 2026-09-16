{-| @Repl.Answer — what a colon command puts on the screen.

    Every one of these takes a session and answers with text. None of them
    changes anything, which is what lets them be a module rather than part of
    the loop: inspecting a session cannot alter it. -}
module Pudu.Repl.Answer
  ( browseModule
  , emptyAs
  , performLoad
  , prompt
  , renderReplValue
  , reportEntry
  , showAst
  , showHelp
  , showState
  , showTokens
  , showType
  ) where

import Control.Monad (unless)
import Data.Foldable (toList)
import Data.IORef (IORef, readIORef)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Program (compileProgramSource, programDiagnostics, programDocs)
import Pudu.Diagnostic (Diagnostic, hasErrors)
import Pudu.Doc (DocEntry (..), DocIndex (..), DocKind (..), renderEntry)
import Pudu.Repl.Options (ReplOptions (..), ReplSettings (..))
import Pudu.Diagnostic.Render
  (defaultRenderConfig
  , interactiveRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Eval.Render (renderValue, valueKind)
import Pudu.Eval.Value (OrdValue (..), Value (..))
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.State (runParser)
import Pudu.Frontend.Token (Token (..), TokenKind (..))
import Pudu.Repl.Command (commandHelp)
import Pudu.Repl.Describe
  ( declarationSummary
  , importSummary
  )
import Pudu.Repl.Outline (outlineBlock)
import Pudu.Repl.Session
  ( EntryResult (..)
  , Session (..)
  , inspectContext
  , emptySession
  , inspectEntryType
  , inspectSession
  , loadModule
  , sessionDeclaredNames
  , sessionExports
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Pudu.Type (renderType)
import System.Directory (doesFileExist, getCurrentDirectory)

showAst :: ReplOptions -> Text -> IO ()
showAst options text
  | Text.null (Text.strip text) = TextIO.putStrLn "usage: :ast <text>"
  | otherwise = do
      source <- newSource (SourceName "<interactive>") ("{\n" <> text <> "\n}")
      let LexResult{lexTokens} = lexSource source
          action = parseBlock
          (parsed, diagnostics) = runParser source action lexTokens
      if hasErrors diagnostics
        then
          TextIO.putStrLn
            (renderDiagnosticsWith (defaultRenderConfig (replStyle options)) source diagnostics)
        else mapM_ TextIO.putStrLn (outlineBlock parsed)

showHelp :: IO ()
showHelp = do
  TextIO.putStrLn " Commands available from the prompt:"
  TextIO.putStrLn ""
  TextIO.putStrLn "   <statement>                 evaluate or define <statement>"
  mapM_ line commandHelp
 where
  line (name, description) =
    TextIO.putStrLn ("   " <> pad name <> description)
  pad name = name <> Text.replicate (max 1 (28 - Text.length name)) " "

{-| @Repl.State — what the session holds right now, grouped the way a reader
    asks for it rather than the way the checker stores it. -}
showState :: IORef ReplSettings -> Session -> Text -> IO [Text]
showState settingsRef session topic = case topic of
  "settings" -> do
    settings <- readIORef settingsRef
    pure
      [ "+t (show types)     " <> onOff (settingShowTypes settings)
      , "+s (show timing)    " <> onOff (settingShowTiming settings)
      , "+trunc (truncate)   " <> onOff (settingTruncate settings)
      ]
  "bindings" ->
    pure (emptyAs "no bindings" (map (("bind    " <>) . summarizeLine) (sessionStatements session)))
  "declarations" -> do
    (_, parsed, _) <- inspectContext session
    pure (emptyAs "no declarations" (foldMap declarationSummary parsed))
  "imports" -> do
    (_, parsed, _) <- inspectContext session
    pure (emptyAs "no imports" (foldMap importSummary parsed))
  _ -> pure ["usage: :show bindings|declarations|imports|settings"]
 where
  onOff wanted = if wanted then "on" else "off"
  summarizeLine value = case Text.lines value of
    [single] -> single
    found : _ -> found <> " ..."
    [] -> value

showTokens :: Text -> IO ()
showTokens text
  | Text.null (Text.strip text) = TextIO.putStrLn "usage: :tokens <text>"
  | otherwise = do
      source <- newSource (SourceName "<interactive>") text
      let LexResult{lexTokens} = lexSource source
      mapM_ (TextIO.putStrLn . describeToken) (filter (not . isEnd) lexTokens)
 where
  isEnd token = tokenKind token == EndOfFile

{-| Ask the compiler for an entry's type without entering the evaluator. -}
showType :: ReplOptions -> Session -> Text -> IO ()
showType options session expression
  | Text.null (Text.strip expression) = TextIO.putStrLn "usage: :type <expression>"
  | otherwise = do
      (source, firstLine, diagnostics, found) <- inspectEntryType session expression
      let config =
            interactiveRenderConfig (replStyle options) "<interactive>" firstLine
      unless (null diagnostics) $
        TextIO.putStrLn (renderDiagnosticsWith config source diagnostics)
      unless (hasErrors diagnostics) $ case found of
        Just typeValue -> TextIO.putStrLn (Text.strip expression <> " :: " <> renderType typeValue)
        Nothing -> TextIO.putStrLn "no type"

reportEntry :: ReplOptions -> ReplSettings -> EntryResult -> IO ()
reportEntry options settings result = do
  let diagnostics = resultDiagnostics result
      config =
        interactiveRenderConfig (replStyle options) "<interactive>" (resultFirstLine result)
  unless (null diagnostics) $
    TextIO.putStrLn (renderDiagnosticsWith config (resultSource result) diagnostics)
  case resultValue result of
    Just value
      | resultAccepted result ->
          let rendered = renderReplValue (settingTruncate settings) value
           in TextIO.putStrLn $
                if settingShowTypes settings
                  then rendered <> " :: " <> entryTypeText result value
                  else rendered
    _ -> pure ()

{-| Render a runtime value with optional bound truncation. -}
renderReplValue :: Bool -> Value -> Text
renderReplValue truncateEnabled value
  | not truncateEnabled = renderValue value
  | otherwise = case value of
      ArrayValue members
        | length members > 50 ->
            let shown = take 50 (toList members)
                more = length members - 50
             in "[" <> Text.intercalate ", " (map renderValue shown)
                  <> ", ... (+" <> Text.pack (show more) <> " more)]"
      SetValue members
        | Set.size members > 50 ->
            let shown = take 50 (Set.toAscList members)
                more = Set.size members - 50
             in "#{" <> Text.intercalate ", " (map (renderValue . unOrdValue) shown)
                  <> ", ... (+" <> Text.pack (show more) <> " more)}"
      MapValue entries
        | Map.size entries > 50 ->
            let shown = take 50 (Map.toAscList entries)
                more = Map.size entries - 50
             in "{" <> Text.intercalate ", " [renderValue (unOrdValue k) <> ": " <> renderValue v | (k, v) <- shown]
                  <> ", ... (+" <> Text.pack (show more) <> " more)}"
      StrValue text
        | Text.length text > 500 ->
            "\"" <> Text.take 500 text <> "... (truncated " <> Text.pack (show (Text.length text)) <> " chars)\""
      _ -> renderValue value

{-| Browse the active session context or an importable module. -}
browseModule :: ReplOptions -> Session -> Maybe Text -> IO ()
browseModule options session maybeMod = case maybeMod of
  Nothing -> browseSessionContext options session
  Just raw
    | Text.null (Text.strip raw) -> browseSessionContext options session
    | otherwise -> browseExternalModule options session (Text.strip raw)

browseSessionContext :: ReplOptions -> Session -> IO ()
browseSessionContext options session = do
  (resolution, diagnostics) <- inspectSession session
  unless (null diagnostics) (reportContext options diagnostics)
  case resolution of
    Nothing -> TextIO.putStrLn "nothing to browse"
    Just found -> case sessionExports found of
      [] -> case sessionDeclaredNames found of
        [] -> TextIO.putStrLn "the session context declares nothing"
        declared -> do
          TextIO.putStrLn "nothing is exported; the context declares:"
          mapM_ TextIO.putStrLn declared
      names -> mapM_ TextIO.putStrLn names

browseExternalModule :: ReplOptions -> Session -> Text -> IO ()
browseExternalModule options _ modName = do
  root <- getCurrentDirectory
  let probeSource = "module BrowseProbe\nimport " <> modName <> "\n"
  probe <- newSource (SourceName "<browse>") probeSource
  program <- compileProgramSource root probe
  let diagnostics = programDiagnostics program
  if hasErrors diagnostics
    then do
      TextIO.putStrLn ("cannot browse module '" <> modName <> "'")
      let config = defaultRenderConfig (replStyle options)
      TextIO.putStrLn (renderDiagnosticsWith config probe diagnostics)
    else do
      let docIdx = programDocs program
          entries = filter (\e -> docModule e == modName) (indexEntries docIdx)
          allEntries = if null entries
            then filter (\e -> docModule e /= "BrowseProbe") (indexEntries docIdx)
            else entries
      if null allEntries
        then TextIO.putStrLn ("module '" <> modName <> "' has no exported declarations")
        else renderCategorizedModule modName allEntries

renderCategorizedModule :: Text -> [DocEntry] -> IO ()
renderCategorizedModule modName entries = do
  TextIO.putStrLn ("-- Module " <> modName <> " --")
  renderGroup "Constants" [e | e <- entries, docKind e == DocConstant]
  renderGroup "Types" [e | e <- entries, docKind e == DocType]
  renderGroup "Traits" [e | e <- entries, docKind e == DocTrait]
  renderGroup "Functions" [e | e <- entries, isFuncKind (docKind e)]
  renderGroup "Foreign" [e | e <- entries, isForeignKind (docKind e)]
 where
  isFuncKind DocFunction = True
  isFuncKind (DocTraitMethod _) = True
  isFuncKind (DocMethod _) = True
  isFuncKind _ = False

  isForeignKind (DocForeign _) = True
  isForeignKind _ = False

  renderGroup _ [] = pure ()
  renderGroup title items = do
    TextIO.putStrLn ("\n-- " <> title <> " --")
    mapM_ printEntry items

  printEntry entry = do
    TextIO.putStrLn (renderEntry entry)
    mapM_ (\doc -> TextIO.putStrLn ("  /// " <> doc)) (docComment entry)

reportContext :: ReplOptions -> [Diagnostic] -> IO ()
reportContext _ diagnostics =
  TextIO.putStrLn ("session context has " <> renderSummary diagnostics)

{-| With `:set +t` the prompt reports the checked type when the checker
    produced one and the value's own kind when it did not, so the answer is
    never less precise than what the session actually knows. -}

{-| Loading replaces the session context with the file and clears entries typed
    against the previous context, so nothing survives that the new file cannot
    explain. -}
performLoad :: ReplOptions -> Session -> FilePath -> IO Session
performLoad options session path = do
  contents <- readSourceFile path
  case contents of
    Nothing -> do
      TextIO.putStrLn ("cannot read " <> Text.pack path)
      pure session
    Just text -> do
      (apply, diagnostics, resolution) <- loadModule path text
      source <- newSource (SourceName (Text.pack path)) text
      unless (null diagnostics) $
        TextIO.putStrLn
          (renderDiagnosticsWith (defaultRenderConfig (replStyle options)) source diagnostics)
      if hasErrors diagnostics
        then do
          TextIO.putStrLn ("failed, " <> renderSummary diagnostics)
          pure session
        else do
          let loaded = apply emptySession
              names = maybe [] sessionExports resolution
          TextIO.putStrLn
            ( "ok, loaded " <> Text.pack path <> ", "
                <> Text.pack (show (length names)) <> " exported"
            )
          pure loaded

describeToken :: Token -> Text
describeToken token =
  Text.pack (show (tokenKind token)) <> "  " <> tokenLexeme token

{-| A prompt that says nothing has an answer too; say it rather than fall
    silent, so the reader knows the command ran. -}
emptyAs :: Text -> [Text] -> [Text]
emptyAs message entries = if null entries then [message] else entries

{-| @Repl.Settings — the switches a reader can flip mid-session. Named after the
    flag they answer to so the help text and the parser cannot drift apart. -}

{-| With `:set +t` the prompt reports the checked type when the checker
    produced one and the value's own kind when it did not, so the answer is
    never less precise than what the session actually knows. -}
entryTypeText :: EntryResult -> Value -> Text
entryTypeText result value = maybe (valueKind value) renderType (resultType result)

{-| `:{` reads until `:}`, so a declaration can be pasted or typed across lines
    even when its brackets balance on an early line. -}

readSourceFile :: FilePath -> IO (Maybe Text)
readSourceFile path = do
  present <- doesFileExist path
  if present then Just <$> TextIO.readFile path else pure Nothing

prompt :: Text
prompt = "puduci> "

{-| Run the session until the reader quits or input ends.

    The session value itself stays pure and is threaded through the loop. A
    reference to it is kept only so completion can see what the session has
    declared; completion never writes to it. -}
