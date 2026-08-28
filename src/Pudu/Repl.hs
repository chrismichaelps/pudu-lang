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
import Pudu.Frontend.Token (Token (..), TokenKind (..))
import Pudu.Repl.Input (continuationPrompt, readContinuation, readEntry)
import Pudu.Repl.Options
  ( ReplOptions (..)
  , ReplSettings (..)
  , defaultReplOptions
  , defaultReplSettings
  )
import Pudu.Repl.Answer
  ( emptyAs
  , performLoad
  , prompt
  , reportEntry
  , showAst
  , showHelp
  , showState
  , showTokens
  , showType
  )
import Pudu.Repl.Command (Command (..), Entry (..), commandHelp, parseEntry)
import Pudu.Repl.Complete
  ( CompletionSource (..)
  , completionsFor
  , isNameCharacter
  , memberContext
  , wantsFilename
  )
import Pudu.Eval.Operator (builtinMethodNamesFor)
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
  , typeOfEntry
  )
import Pudu.Source (SourceName (SourceName), newSource)
import Data.List (sort)
import Pudu.Type (Type (..), renderType)
import Pudu.Type.Value (nominalName)
import System.Directory (doesFileExist)
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
  }


banner :: Text
banner = "puduci, version " <> versionText <> ": the Pudu interactive session  :? for help"

versionText :: Text
versionText = "0.1.0.0"

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
  let context =
        ReplContext
          { contextOptions = options
          , contextVisible = visible
          , contextSettings = chosen
          , contextCurrent = current
          }
  runInputT settings (withInterrupt (loop context session))

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

settingFor :: Text -> Maybe (Bool -> ReplSettings -> ReplSettings)
settingFor key = case Text.dropWhile (== '+') key of
  "t" -> Just (\wanted settings -> settings{settingShowTypes = wanted})
  "s" -> Just (\wanted settings -> settings{settingShowTiming = wanted})
  _ -> Nothing

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
