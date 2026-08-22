{-| @Repl.Module — runs the puduci interactive session -}
module Pudu.Repl
  ( ReplOptions (..)
  , banner
  , defaultReplOptions
  , runRepl
  ) where

import Control.Monad (unless)
import Control.Monad.IO.Class (liftIO)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Diagnostic (Diagnostic, hasErrors)
import Pudu.Diagnostic.Render
  ( RenderStyle (..)
  , defaultRenderConfig
  , interactiveRenderConfig
  , renderDiagnosticsWith
  , renderSummary
  )
import Pudu.Eval.Value (renderValue, valueKind)
import Pudu.Frontend.Lexer (LexResult (..), lexSource)
import Pudu.Frontend.Parser.Declaration.Block (parseBlock)
import Pudu.Frontend.Parser.State (runParser)
import Pudu.Frontend.Token (Keyword (..), Token (..), TokenKind (..), symbolText)
import Pudu.Repl.Command (Command (..), Entry (..), commandHelp, parseEntry)
import Pudu.Repl.Complete
  ( CompletionSource (..)
  , completionsFor
  , isNameCharacter
  , wantsFilename
  )
import Pudu.Repl.Outline (outlineBlock)
import Pudu.Repl.Session
  ( EntryResult (..)
  , LoadedModule (..)
  , Session (..)
  , inspectSession
  , contextSummary
  , emptySession
  , loadModule
  , sessionDeclaredNames
  , sessionVisibleNames
  , sessionExports
  , submitEntry
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Pudu.Type (renderType)
import System.Directory (doesFileExist)
import System.Console.Haskeline
  ( Completion (..)
  , CompletionFunc
  , InputT
  , Settings (..)
  , completeFilename
  , defaultSettings
  , getInputLine
  , handleInterrupt
  , outputStrLn
  , runInputT
  , withInterrupt
  )
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))
import System.IO (BufferMode (LineBuffering), hSetBuffering, hSetEncoding, stdout, utf8)

{-| @Repl.Options — everything the caller decides before the loop starts -}
data ReplOptions = ReplOptions
  { replStyle :: !RenderStyle
  , replInitialLoad :: !(Maybe FilePath)
  }
  deriving stock (Eq, Show)

defaultReplOptions :: ReplOptions
defaultReplOptions = ReplOptions{replStyle = PlainStyle, replInitialLoad = Nothing}

banner :: Text
banner = "puduci, version " <> versionText <> ": the Pudu interactive session  :? for help"

versionText :: Text
versionText = "0.1.0.0"

prompt :: Text
prompt = "puduci> "

continuationPrompt :: Text
continuationPrompt = "puduci| "

{-| Run the session until the reader quits or input ends.

    The session value itself stays pure and is threaded through the loop. A
    reference to it is kept only so completion can see what the session has
    declared; completion never writes to it. -}
runRepl :: ReplOptions -> IO ()
runRepl options = do
  hSetEncoding stdout utf8
  hSetBuffering stdout LineBuffering
  TextIO.putStrLn banner
  session <- case replInitialLoad options of
    Nothing -> pure emptySession
    Just path -> performLoad options emptySession path
  visible <- newIORef =<< nameSourceFor session
  settings <- sessionSettings visible
  runInputT settings (withInterrupt (loop options visible session))

{-| History lives beside the reader's other tool history, and completion is
    session-aware. -}
sessionSettings :: IORef CompletionSource -> IO (Settings IO)
sessionSettings visible = do
  home <- getHomeDirectory
  pure
    (defaultSettings :: Settings IO)
      { historyFile = Just (home </> ".puduci_history")
      , autoAddHistory = True
      , complete = sessionCompletion visible
      }

{-| Complete a colon command at the start of a line, a filename after a command
    that takes one, and otherwise a name the session can see. -}
sessionCompletion :: IORef CompletionSource -> CompletionFunc IO
sessionCompletion visible (leftReversed, right) = do
  let before = Text.pack (reverse leftReversed)
      word = Text.takeWhileEnd completionCharacter before
      prefix = Text.dropEnd (Text.length word) before
  if wantsFilename prefix
    then completeFilename (leftReversed, right)
    else do
      source <- readIORef visible
      let matches = completionsFor source prefix word
          finished = Text.isPrefixOf ":" word
      pure (drop (Text.length word) leftReversed, map (toCompletion finished) matches)

completionCharacter :: Char -> Bool
completionCharacter character = isNameCharacter character || character == ':'

{-| A completed command is finished, so a space follows it and its argument can
    be typed straight away. A completed name is not: `measure` is usually
    followed by `(`, and an inserted space would have to be deleted. -}
toCompletion :: Bool -> Text -> Completion
toCompletion finished value =
  Completion
    { replacement = Text.unpack value
    , display = Text.unpack value
    , isFinished = finished
    }

{-| The names completion offers: whatever the session context declares. -}
nameSourceFor :: Session -> IO CompletionSource
nameSourceFor session = do
  (resolution, _) <- inspectSession session
  pure CompletionSource{sourceSessionNames = maybe [] sessionVisibleNames resolution}

loop :: ReplOptions -> IORef CompletionSource -> Session -> InputT IO ()
loop options visible session =
  handleInterrupt (interrupted options visible session) $ do
    line <- readEntry prompt
    case line of
      Nothing -> say "Leaving puduci."
      Just raw -> case parseEntry raw of
        BlankEntry -> loop options visible session
        CommandEntry command -> do
          outcome <- runCommand options session command
          case outcome of
            Nothing -> say "Leaving puduci."
            Just next -> continueWith options visible next
        SourceEntry text -> do
          whole <- readContinuation text
          next <- runSource options session whole
          continueWith options visible next

{-| Ctrl-C abandons the line being typed and returns to the prompt with the
    session untouched, so an interrupt costs a line rather than a session. -}
interrupted :: ReplOptions -> IORef CompletionSource -> Session -> InputT IO ()
interrupted options visible session = do
  say "interrupted"
  loop options visible session

continueWith :: ReplOptions -> IORef CompletionSource -> Session -> InputT IO ()
continueWith options visible session = do
  liftIO (writeIORef visible =<< nameSourceFor session)
  loop options visible session

say :: Text -> InputT IO ()
say = outputStrLn . Text.unpack

{-| A construct that is still open keeps reading at the continuation prompt.

    Once continuation has begun, reading ends at a closing `}` that balances the
    entry or at a blank line. The blank line is what lets a form whose next line
    starts with `|`, `.`, or `?` — a sum type or a fluent chain — be entered
    without a lookahead the prompt cannot perform. -}
readContinuation :: Text -> InputT IO Text
readContinuation first = do
  complete <- liftIO (isComplete first)
  if complete then pure first else continueEntry first

continueEntry :: Text -> InputT IO Text
continueEntry accumulated = do
  more <- readEntry continuationPrompt
  case more of
    Nothing -> pure accumulated
    Just next
      | Text.null (Text.strip next) -> pure accumulated
      | otherwise -> do
          let extended = accumulated <> "\n" <> next
          complete <- liftIO (isComplete extended)
          if complete && closesBlock next then pure extended else continueEntry extended

{-| A line whose last token is `}` finishes a braced construct, so the reader
    does not have to add a blank line after every function or match. -}
closesBlock :: Text -> Bool
closesBlock line = Text.isSuffixOf "}" (Text.stripEnd line)

readEntry :: Text -> InputT IO (Maybe Text)
readEntry shown = fmap Text.pack <$> getInputLine (Text.unpack shown)

{-| An entry is complete when every bracket it opened is closed. The check runs
    over real tokens, so a brace inside a string or a comment can never leave
    the session waiting for input that will not come. -}
isComplete :: Text -> IO Bool
isComplete text = do
  source <- newSource (SourceName "<interactive>") text
  let LexResult{lexTokens} = lexSource source
      significant = filter (\token -> tokenKind token /= EndOfFile) lexTokens
  pure (openDepth significant <= 0 && not (awaitsOperand significant))

{-| A line that ends with an operator, a separator, or a `=` is still waiting
    for its right-hand side, which is the same continuation rule the language
    itself applies across line breaks. -}
awaitsOperand :: [Token] -> Bool
awaitsOperand tokens = case reverse tokens of
  [] -> False
  final : _ -> case tokenKind final of
    Symbol symbol -> symbolText symbol `elem` continuationSymbols
    Keyword keyword -> keyword `elem` [KwElse, KwIn, KwWhere, KwAs, KwReturn, KwMatch, KwWhile, KwFor, KwIf]
    _ -> False

continuationSymbols :: [Text]
continuationSymbols =
  [ "=", "=>", "->", ",", "|", "+", "-", "*", "/", "%", "&", "&&", "||"
  , "==", "!=", "<", "<=", ">", ">=", "..", "..=", ":", "."
  , "&+", "&-", "&*", "+|", "-|", "*|", "!"
  ]

openDepth :: [Token] -> Int
openDepth = foldl step 0
 where
  step total token = case tokenKind token of
    Symbol symbol
      | symbolText symbol `elem` ["(", "[", "{"] -> total + 1
      | symbolText symbol `elem` [")", "]", "}"] -> max 0 (total - 1)
    _ -> total

runCommand :: ReplOptions -> Session -> Command -> InputT IO (Maybe Session)
runCommand options session command = case command of
  Quit -> pure Nothing
  Help -> liftIO showHelp >> pure (Just session)
  Reset -> say "session cleared" >> pure (Just emptySession)
  Load path
    | Text.null (Text.strip path) -> do
        say "usage: :load <file>"
        pure (Just session)
    | otherwise ->
        Just <$> liftIO (performLoad options session (Text.unpack (Text.strip path)))
  Reload -> case sessionLoaded session of
    Nothing -> say "no file is loaded" >> pure (Just session)
    Just loaded -> Just <$> liftIO (performLoad options session (loadedPath loaded))
  Browse -> liftIO (browseSession options session) >> pure (Just session)
  ShowContext -> do
    let entries = contextSummary session
    if null entries
      then say "the session is empty"
      else mapM_ say entries
    pure (Just session)
  ShowType expression -> liftIO (showType options session expression) >> pure (Just session)
  ShowTokens text -> liftIO (showTokens text) >> pure (Just session)
  ShowAst text -> liftIO (showAst options text) >> pure (Just session)
  BeginBlock -> Just <$> readBlock options session
  EndBlock -> do
    say "no multi-line block is open"
    pure (Just session)
  Unknown name -> do
    say ("unknown command ':" <> name <> "'")
    say "use :? for help."
    pure (Just session)

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

runSource :: ReplOptions -> Session -> Text -> InputT IO Session
runSource options session text = do
  result <- liftIO (submitEntry session text)
  liftIO (reportEntry options result)
  pure (resultSession result)

reportEntry :: ReplOptions -> EntryResult -> IO ()
reportEntry options result = do
  let diagnostics = resultDiagnostics result
      config =
        interactiveRenderConfig (replStyle options) "<interactive>" (resultFirstLine result)
  unless (null diagnostics) $
    TextIO.putStrLn (renderDiagnosticsWith config (resultSource result) diagnostics)
  case resultValue result of
    Just value | resultAccepted result -> TextIO.putStrLn (renderValue value)
    _ -> pure ()

{-| `:{` reads until `:}`, so a declaration can be pasted or typed across lines
    even when its brackets balance on an early line. -}
readBlock :: ReplOptions -> Session -> InputT IO Session
readBlock options session = collect []
 where
  collect gathered = do
    line <- readEntry continuationPrompt
    case line of
      Nothing -> finish gathered
      Just raw
        | Text.strip raw == ":}" -> finish gathered
        | otherwise -> collect (raw : gathered)
  finish gathered
    | null gathered = pure session
    | otherwise = runSource options session (Text.intercalate "\n" (reverse gathered))

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

readSourceFile :: FilePath -> IO (Maybe Text)
readSourceFile path = do
  present <- doesFileExist path
  if present then Just <$> TextIO.readFile path else pure Nothing

browseSession :: ReplOptions -> Session -> IO ()
browseSession options session = do
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

reportContext :: ReplOptions -> [Diagnostic] -> IO ()
reportContext _ diagnostics =
  TextIO.putStrLn ("session context has " <> renderSummary diagnostics)

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

showTokens :: Text -> IO ()
showTokens text
  | Text.null (Text.strip text) = TextIO.putStrLn "usage: :tokens <text>"
  | otherwise = do
      source <- newSource (SourceName "<interactive>") text
      let LexResult{lexTokens} = lexSource source
      mapM_ (TextIO.putStrLn . describeToken) (filter (not . isEnd) lexTokens)
 where
  isEnd token = tokenKind token == EndOfFile

describeToken :: Token -> Text
describeToken token =
  Text.pack (show (tokenKind token)) <> "  " <> tokenLexeme token

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
