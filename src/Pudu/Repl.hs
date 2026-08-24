{-| @Repl.Module — runs the puduci interactive session -}
module Pudu.Repl
  ( ReplOptions (..)
  , banner
  , defaultReplOptions
  , runRepl
  ) where

import Control.Monad (unless, when)
import Control.Monad.IO.Class (liftIO)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef, writeIORef)
import Data.Text (Text)
import GHC.Clock (getMonotonicTime)
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
import Pudu.Eval.Value (Value, renderValue, valueKind)
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
import Pudu.Doc (entriesFor, renderEntryLinesWith)
import Pudu.Doc.Search (Match (..), searchText)
import Pudu.Repl.Describe
  ( declarationSummary
  , describeInstances
  , describeKindLines
  , describeName
  , importSummary
  )
import Pudu.Repl.Outline (outlineBlock)
import Pudu.Repl.Session
  ( EntryResult (..)
  , LoadedModule (..)
  , Session (..)
  , inspectContext
  , inspectDocs
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

{-| @Repl.Settings — what the reader turned on for this session.

    Settings are session state, not options the entry point chose, so they live
    beside the session rather than in the options record. -}
data ReplSettings = ReplSettings
  { settingShowTypes :: !Bool
  , settingShowTiming :: !Bool
  }
  deriving stock (Eq, Show)

defaultSettings' :: ReplSettings
defaultSettings' = ReplSettings{settingShowTypes = False, settingShowTiming = False}

{-| @Repl.Context — what every command needs: the entry point's choices, the
    names completion offers, and the settings the reader turned on. -}
data ReplContext = ReplContext
  { contextOptions :: !ReplOptions
  , contextVisible :: !(IORef CompletionSource)
  , contextSettings :: !(IORef ReplSettings)
  }

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
  chosen <- newIORef defaultSettings'
  settings <- sessionSettings visible
  let context = ReplContext{contextOptions = options, contextVisible = visible, contextSettings = chosen}
  runInputT settings (withInterrupt (loop context session))

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

loop :: ReplContext -> Session -> InputT IO ()
loop context session =
  handleInterrupt (interrupted context session) $ do
    line <- readEntry prompt
    case line of
      Nothing -> say "Leaving puduci."
      Just raw -> case parseEntry raw of
        BlankEntry -> loop context session
        CommandEntry command -> do
          outcome <- runCommand context session command
          case outcome of
            Nothing -> say "Leaving puduci."
            Just next -> continueWith context next
        SourceEntry text -> do
          whole <- readContinuation text
          next <- runSource context session whole
          continueWith context next

{-| Ctrl-C abandons the line being typed and returns to the prompt with the
    session untouched, so an interrupt costs a line rather than a session. -}
interrupted :: ReplContext -> Session -> InputT IO ()
interrupted context session = do
  say "interrupted"
  loop context session

continueWith :: ReplContext -> Session -> InputT IO ()
continueWith context session = do
  liftIO (writeIORef (contextVisible context) =<< nameSourceFor session)
  loop context session

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
  pure
    ( not (null significant)
        && openDepth significant <= 0
        && not (awaitsOperand significant)
    )

{-| A submission with no tokens of its own is documentation waiting for the
    declaration it documents, so the prompt keeps reading. Typing `/// ...` and
    pressing enter is the start of an entry, not an entry.

    A line that ends with an operator, a separator, or a `=` is still waiting
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

runCommand :: ReplContext -> Session -> Command -> InputT IO (Maybe Session)
runCommand context session command = case command of
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
  BeginBlock -> Just <$> readBlock context session
  EndBlock -> do
    say "no multi-line block is open"
    pure (Just session)
  ShowInfo name -> describe describeName name
  ShowKind name -> describe describeKindLines name
  ShowInstances name -> describe (\moduleValue wanted -> emptyAs ("no instances for '" <> wanted <> "'") (describeInstances moduleValue wanted)) name
  ShowSetting flag -> adjust flag True
  ClearSetting flag -> adjust flag False
  ShowState topic -> do
    lines' <- liftIO (showState context session (Text.strip topic))
    mapM_ say lines'
    pure (Just session)
  ShowDoc name
    | Text.null (Text.strip name) -> do
        say "usage: :doc <name>"
        pure (Just session)
    | otherwise -> do
        index <- liftIO (inspectDocs session)
        let found = foldMap (entriesFor (Text.strip name)) index
        mapM_ say $
          if null found
            then ["not in scope: '" <> Text.strip name <> "'"]
            else concatMap (renderEntryLinesWith False) found
        pure (Just session)
  Search query
    | Text.null (Text.strip query) -> do
        say "usage: :search <name or type>"
        say "a type query looks like 'Array[a] -> a'"
        pure (Just session)
    | otherwise -> do
        index <- liftIO (inspectDocs session)
        let found = foldMap (searchText (Text.strip query)) index
        mapM_ say $
          if null found
            then ["no results for " <> Text.strip query]
            else concatMap (renderEntryLinesWith False . matchEntry) (take searchLimit found)
        pure (Just session)
  Unknown name -> do
    say ("unknown command ':" <> name <> "'")
    say "use :? for help."
    pure (Just session)
 where
  options = contextOptions context

  describe render name
    | Text.null (Text.strip name) = do
        say "usage: :info <name>"
        pure (Just session)
    | otherwise = do
        (_, parsed, _) <- liftIO (inspectContext session)
        case parsed of
          Nothing -> say "the session is empty"
          Just moduleValue ->
            mapM_ say $
              emptyAs
                ("not in scope: '" <> Text.strip name <> "'")
                (render moduleValue (Text.strip name))
        pure (Just session)

  adjust flag wanted = do
    let key = Text.strip flag
    case settingFor key of
      Nothing -> do
        say ("unknown setting '" <> key <> "'")
        say "known settings: +t (show types), +s (show timing)"
        pure (Just session)
      Just update -> do
        liftIO (modifyIORef' (contextSettings context) (update wanted))
        pure (Just session)

{-| How many search results one prompt shows.

    A prompt is not a results page: past a screenful the reader has stopped
    reading and should refine the query instead. -}
searchLimit :: Int
searchLimit = 20

{-| A prompt that says nothing has an answer too; say it rather than fall
    silent, so the reader knows the command ran. -}
emptyAs :: Text -> [Text] -> [Text]
emptyAs message entries = if null entries then [message] else entries

{-| @Repl.Settings — the switches a reader can flip mid-session. Named after the
    flag they answer to so the help text and the parser cannot drift apart. -}
settingFor :: Text -> Maybe (Bool -> ReplSettings -> ReplSettings)
settingFor key = case Text.dropWhile (== '+') key of
  "t" -> Just (\wanted settings -> settings{settingShowTypes = wanted})
  "s" -> Just (\wanted settings -> settings{settingShowTiming = wanted})
  _ -> Nothing

{-| @Repl.State — what the session holds right now, grouped the way a reader
    asks for it rather than the way the checker stores it. -}
showState :: ReplContext -> Session -> Text -> IO [Text]
showState context session topic = case topic of
  "settings" -> do
    settings <- readIORef (contextSettings context)
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

runSource :: ReplContext -> Session -> Text -> InputT IO Session
runSource context session text = do
  started <- liftIO getMonotonicTime
  result <- liftIO (submitEntry session text)
  settings <- liftIO (readIORef (contextSettings context))
  liftIO (reportEntry (contextOptions context) settings result)
  finished <- liftIO getMonotonicTime
  when (settingShowTiming settings) $
    say ("(" <> Text.pack (show (finished - started)) <> " secs)")
  pure (resultSession result)

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
entryTypeText :: EntryResult -> Value -> Text
entryTypeText result value = maybe (valueKind value) renderType (resultType result)

{-| `:{` reads until `:}`, so a declaration can be pasted or typed across lines
    even when its brackets balance on an early line. -}
readBlock :: ReplContext -> Session -> InputT IO Session
readBlock context session = collect []
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
    | otherwise = runSource context session (Text.intercalate "\n" (reverse gathered))

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
