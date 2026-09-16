{-| @Repl.Module — runs the puduci interactive session -}
module Pudu.Repl
  ( ReplOptions (..)
  , banner
  , defaultReplOptions
  , runRepl
  ) where

import Control.Exception (IOException, try)
import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.IORef (IORef, modifyIORef', newIORef, readIORef, writeIORef)
import Pudu.Version (versionText)
import Data.Text (Text)
import GHC.Clock (getMonotonicTime)
import qualified GHC.Conc as Conc
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Repl.Input (continuationPrompt, isTriviaOnly, readContinuation, readEntry)
import Pudu.Repl.Options
  ( ReplOptions (..)
  , ReplSettings (..)
  , defaultReplOptions
  , defaultReplSettings
  )
import Pudu.Repl.Answer
  ( browseModule
  , emptyAs
  , performLoad
  , prompt
  , reportEntry
  , showAst
  , showHelp
  , showState
  , showTokens
  , showType
  )
import Pudu.Repl.Command (Command (..), Entry (..), parseEntry)
import Pudu.Repl.Complete
  ( CompletionSource (..)
  , completionsFor
  , isNameCharacter
  , memberContext
  , wantsFilename
  )
import Pudu.Eval.Context (EvaluationContext, withEvaluationContext)
import Pudu.Diagnostic (diagnosticMessage)
import Pudu.Eval.Operator (builtinMethodNamesFor)
import Pudu.Doc (entriesFor, renderEntryLinesWith)
import Pudu.Doc.Search (Match (..), searchText)
import Pudu.Repl.Describe
  (describeInstances
  , describeKindLines
  , describeName
  )
import Pudu.Repl.Session
  ( EntryResult (..)
  , LoadedModule (..)
  , Session (..)
  , inspectContext
  , inspectDocs
  , inspectSession
  , contextSummary
  , emptySession
  , sessionVisibleNames
  , submitEntryInContext
  , typeOfEntry
  )
import Data.List (sort)
import Pudu.Type (Type (..))
import Pudu.Type.Value (nominalName)
import System.Environment (lookupEnv)
import System.Process (callProcess)
import Text.Printf (printf)
import System.Console.Haskeline
  ( Completion (..)
  , CompletionFunc
  , InputT
  , Settings (..)
  , completeFilename
  , defaultSettings
  , handleInterrupt
  , outputStrLn
  , runInputT
  , withInterrupt
  )
import System.Directory (getHomeDirectory)
import System.FilePath ((</>))
import System.IO (BufferMode (LineBuffering), hSetBuffering, hSetEncoding, stdout, utf8)

{-| @Repl.Context — what every command needs: the entry point's choices, the
    names completion offers, and the settings the reader turned on. -}
data ReplContext = ReplContext
  { contextOptions :: !ReplOptions
  , contextVisible :: !(IORef CompletionSource)
  , contextSettings :: !(IORef ReplSettings)
  {-| The session as completion sees it, so asking what a receiver is uses the
      declarations the reader has actually made. -}
  , contextCurrent :: !(IORef Session)
  , contextRuntime :: !EvaluationContext
  }


banner :: Text
banner = "puduci, version " <> versionText <> ": the Pudu interactive session  :? for help"


runRepl :: ReplOptions -> IO ()
runRepl options = do
  hSetEncoding stdout utf8
  hSetBuffering stdout LineBuffering
  TextIO.putStrLn banner
  session <- case replInitialLoad options of
    Nothing -> pure emptySession
    Just path -> performLoad options emptySession path
  visible <- newIORef =<< nameSourceFor session
  chosen <- newIORef defaultReplSettings
  current <- newIORef session
  settings <- sessionSettings visible current
  let runSession active = do
        writeIORef current active
        writeIORef visible =<< nameSourceFor active
        (next, problems) <- withEvaluationContext $ \runtime -> do
          let context = ReplContext
                { contextOptions = options
                , contextVisible = visible
                , contextSettings = chosen
                , contextCurrent = current
                , contextRuntime = runtime
                }
          runInputT settings (withInterrupt (loop context active))
        mapM_ (TextIO.putStrLn . ("cleanup: " <>) . diagnosticMessage) problems
        case next of
          Nothing -> pure ()
          Just replacement -> runSession replacement
  runSession session

{-| History lives beside the reader's other tool history, and completion is
    session-aware. -}
sessionSettings :: IORef CompletionSource -> IORef Session -> IO (Settings IO)
sessionSettings visible current = do
  home <- getHomeDirectory
  pure
    (defaultSettings :: Settings IO)
      { historyFile = Just (home </> ".puduci_history")
      , autoAddHistory = True
      , complete = sessionCompletion visible current
      }

{-| Complete a colon command at the start of a line, a filename after a command
    that takes one, and otherwise a name the session can see. -}
sessionCompletion :: IORef CompletionSource -> IORef Session -> CompletionFunc IO
sessionCompletion visible current (leftReversed, right) = do
  let before = Text.pack (reverse leftReversed)
      word = Text.takeWhileEnd completionCharacter before
      prefix = Text.dropEnd (Text.length word) before
  if wantsFilename prefix
    then completeFilename (leftReversed, right)
    else case memberContext prefix word of
      Just (receiver, partial) -> do
        session <- readIORef current
        offered <- memberCompletions session receiver partial
        pure (drop (Text.length partial) leftReversed, map (toCompletion False) offered)
      Nothing -> do
        source <- readIORef visible
        let matches = completionsFor source prefix word
            finished = Text.isPrefixOf ":" word
        pure (drop (Text.length word) leftReversed, map (toCompletion finished) matches)

{-| What the value in front of the cursor carries.

    The receiver's type is asked for without running it — a reader pressing tab
    after `removeFile(\"notes\")` has asked what a result carries, not for the
    file to be removed.

    A receiver whose type cannot be worked out offers nothing rather than
    everything: a list of names that do not apply is worse than no list, because
    the reader has to check each one. -}
memberCompletions :: Session -> Text -> Text -> IO [Text]
memberCompletions session receiver partial = do
  found <- typeOfEntry session receiver
  pure $ case found of
    Nothing -> []
    Just typeValue -> sort (filter (Text.isPrefixOf partial) (methodsOf typeValue))

{-| The methods a type carries, read from the tables dispatch reads. -}
methodsOf :: Type -> [Text]
methodsOf typeValue = case throughReference typeValue of
  NominalType identity _ -> builtinMethodNamesFor (nominalName identity)
  _ -> []

{-| A borrow carries what it refers to, so `&text` offers what text does. -}
throughReference :: Type -> Type
throughReference typeValue = case typeValue of
  ReferenceTypeValue _ target -> throughReference target
  other -> other

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

loop :: ReplContext -> Session -> InputT IO (Maybe Session)
loop context session =
  handleInterrupt (interrupted context session) $ do
    line <- readEntry prompt
    case line of
      Nothing -> say "Leaving puduci." >> pure Nothing
      Just raw -> case parseEntry raw of
        BlankEntry -> loop context session
        CommandEntry Reset -> say "session cleared" >> pure (Just emptySession)
        CommandEntry command -> do
          outcome <- runCommand context session command
          case outcome of
            Nothing -> say "Leaving puduci." >> pure Nothing
            Just next
              | replacesContext command && next /= session -> pure (Just next)
              | otherwise -> continueWith context next
        SourceEntry text -> do
          whole <- readContinuation text
          trivia <- liftIO (isTriviaOnly whole)
          if trivia then loop context session else do
            next <- runSource context session whole
            continueWith context next

{-| Ctrl-C abandons the line being typed and returns to the prompt with the
    session untouched, so an interrupt costs a line rather than a session. -}
interrupted :: ReplContext -> Session -> InputT IO (Maybe Session)
interrupted context _ = do
  say "interrupted"
  current <- liftIO (readIORef (contextCurrent context))
  continueWith context current

replacesContext :: Command -> Bool
replacesContext command = case command of
  Load _ -> True
  Reload -> True
  Edit _ -> True
  _ -> False

continueWith :: ReplContext -> Session -> InputT IO (Maybe Session)
continueWith context session = do
  liftIO (writeIORef (contextVisible context) =<< nameSourceFor session)
  {-| Completion asks the session what a receiver is, so it has to be the
      session the reader is actually in — a declaration made a moment ago
      offers its methods on the next line. -}
  liftIO (writeIORef (contextCurrent context) session)
  loop context session

say :: Text -> InputT IO ()
say = outputStrLn . Text.unpack

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
  Browse maybeMod -> liftIO (browseModule options session maybeMod) >> pure (Just session)
  Edit maybePath -> do
    let path = resolveEditPath session maybePath
    newSession <- liftIO (performEdit options session path)
    pure (Just newSession)
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
  ShowInfo name -> describe "info" describeName name
  ShowKind name -> describe "kind" describeKindLines name
  ShowInstances name ->
    describe "instances" (\moduleValue wanted -> emptyAs ("no instances for '" <> wanted <> "'") (describeInstances moduleValue wanted)) name
  ShowSetting flag -> adjust flag True
  ClearSetting flag -> adjust flag False
  ShowState topic -> do
    lines' <- liftIO (showState (contextSettings context) session (Text.strip topic))
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

  describe cmdName render name
    | Text.null (Text.strip name) = do
        say ("usage: :" <> cmdName <> " <name>")
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
        say "known settings: +t (show types), +s (show timing), +trunc (truncate collections)"
        pure (Just session)
      Just update -> do
        liftIO (modifyIORef' (contextSettings context) (update wanted))
        pure (Just session)

{-| How many search results one prompt shows.

    A prompt is not a results page: past a screenful the reader has stopped
    reading and should refine the query instead. -}
searchLimit :: Int
searchLimit = 20

settingFor :: Text -> Maybe (Bool -> ReplSettings -> ReplSettings)
settingFor key = case Text.dropWhile (== '+') key of
  "t" -> Just (\wanted settings -> settings{settingShowTypes = wanted})
  "s" -> Just (\wanted settings -> settings{settingShowTiming = wanted})
  "trunc" -> Just (\wanted settings -> settings{settingTruncate = wanted})
  _ -> Nothing

runSource :: ReplContext -> Session -> Text -> InputT IO Session
runSource context session text = do
  settings <- liftIO (readIORef (contextSettings context))
  started <- if settingShowTiming settings
    then liftIO (Conc.setAllocationCounter maxBound >> Just <$> getMonotonicTime)
    else pure Nothing
  result <- liftIO (submitEntryInContext (contextRuntime context)
    (writeIORef (contextCurrent context)) session text)
  liftIO (reportEntry (contextOptions context) settings result)
  case started of
    Nothing -> pure ()
    Just beginning -> do
      finished <- liftIO getMonotonicTime
      allocEnd <- liftIO Conc.getAllocationCounter
      say (formatMetrics (finished - beginning) (maxBound - allocEnd))
  pure (resultSession result)

formatMetrics :: Double -> Int64 -> Text
formatMetrics dt bytes =
  "[time: " <> formatTime dt <> " | heap: " <> formatBytes bytes <> "]"
 where
  formatTime t
    | t < 0.001 = Text.pack (printf "%.1f µs" (t * 1e6))
    | t < 1.0 = Text.pack (printf "%.2f ms" (t * 1e3))
    | otherwise = Text.pack (printf "%.3f s" t)

  formatBytes b
    | b < 1024 = Text.pack (show b) <> " B"
    | b < 1024 * 1024 = Text.pack (show (b `div` 1024)) <> " KB"
    | otherwise = Text.pack (printf "%.2f MB" (fromIntegral b / (1024 * 1024 :: Double)))

resolveEditPath :: Session -> Maybe Text -> FilePath
resolveEditPath session maybePath = case maybePath of
  Just p | not (Text.null (Text.strip p)) -> Text.unpack (Text.strip p)
  _ -> case sessionLoaded session of
    Just loaded -> loadedPath loaded
    Nothing -> "scratch.pudu"

performEdit :: ReplOptions -> Session -> FilePath -> IO Session
performEdit options session path = do
  visual <- lookupEnv "VISUAL"
  editor <- lookupEnv "EDITOR"
  let prog = case visual of
        Just v | not (null v) -> v
        _ -> case editor of
          Just e | not (null e) -> e
          _ -> "nano"
  result <- try (callProcess prog [path]) :: IO (Either IOException ())
  case result of
    Left err -> do
      TextIO.putStrLn ("editor error (" <> Text.pack prog <> "): " <> Text.pack (show err))
      pure session
    Right () -> performLoad options session path

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
    | otherwise = do
        let combined = Text.intercalate "\n" (reverse gathered)
        trivia <- liftIO (isTriviaOnly combined)
        if trivia
          then pure session
          else runSource context session combined
