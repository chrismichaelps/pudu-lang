{-| @Repl.Answer — what a colon command puts on the screen.

    Every one of these takes a session and answers with text. None of them
    changes anything, which is what lets them be a module rather than part of
    the loop: inspecting a session cannot alter it. -}
module Pudu.Repl.Answer
  ( emptyAs
  , performLoad
  , prompt
  , reportEntry
  , showAst
  , showHelp
  , showState
  , showTokens
  , showType
  ) where

import Control.Monad (unless)
import Data.IORef (IORef, readIORef)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Diagnostic (hasErrors)
import Pudu.Repl.Options (ReplOptions (..), ReplSettings (..))
import Pudu.Diagnostic.Render
  (defaultRenderConfig
  , interactiveRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Eval.Value (Value, renderValue, valueKind)
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
  , contextSummary
  , emptySession
  , loadModule
  , sessionExports
  , submitEntry
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Pudu.Type (renderType)
import System.Directory (doesFileExist)

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
      [ "+t (show types)  " <> onOff (settingShowTypes settings)
      , "+s (show timing) " <> onOff (settingShowTiming settings)
      ]
  "bindings" -> pure (emptyAs "no bindings" (contextSummary session))
  "declarations" -> do
    (_, parsed, _) <- inspectContext session
    pure (emptyAs "no declarations" (foldMap declarationSummary parsed))
  "imports" -> do
    (_, parsed, _) <- inspectContext session
    pure (emptyAs "no imports" (foldMap importSummary parsed))
  _ -> pure ["usage: :show bindings|declarations|imports|settings"]
 where
  onOff wanted = if wanted then "on" else "off"

showTokens :: Text -> IO ()
showTokens text
  | Text.null (Text.strip text) = TextIO.putStrLn "usage: :tokens <text>"
  | otherwise = do
      source <- newSource (SourceName "<interactive>") text
      let LexResult{lexTokens} = lexSource source
      mapM_ (TextIO.putStrLn . describeToken) (filter (not . isEnd) lexTokens)
 where
  isEnd token = tokenKind token == EndOfFile

{-| Static types arrive with the typing phase. Until then `:type` reports the
    runtime shape the evaluator produced, and says so. -}
showType :: ReplOptions -> Session -> Text -> IO ()
showType options session expression
  | Text.null (Text.strip expression) = TextIO.putStrLn "usage: :type <expression>"
  | otherwise = do
      result <- submitEntry session expression
      let diagnostics = resultDiagnostics result
          config =
            interactiveRenderConfig (replStyle options) "<interactive>" (resultFirstLine result)
      if not (null diagnostics)
        then TextIO.putStrLn (renderDiagnosticsWith config (resultSource result) diagnostics)
        else case resultType result of
          Just typeValue -> TextIO.putStrLn (Text.strip expression <> " :: " <> renderType typeValue)
          Nothing -> case resultValue result of
            Nothing -> TextIO.putStrLn "no type"
            Just value ->
              TextIO.putStrLn (Text.strip expression <> " :: " <> valueKind value)

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
          TextIO.putStrLn $
            if settingShowTypes settings
              then renderValue value <> " :: " <> entryTypeText result value
              else renderValue value
    _ -> pure ()

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
