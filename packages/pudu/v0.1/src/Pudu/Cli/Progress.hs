{-| @Pudu.Cli.Progress — terminal rendering of install progress

    At `Normal` verbosity with a terminal stderr, a ticker redraws one status
    line every 80 ms: spinner, phase, counts, items in flight, and elapsed
    time. `stopDisplay` clears it. `Verbose` writes each event to stderr as a
    timestamped line; `Quiet` writes nothing. `painter` enables ANSI colour
    when stdout is a terminal and `NO_COLOR` is unset or empty. -}
module Pudu.Cli.Progress
  ( Verbosity (..)
  , Display
  , startDisplay
  , displayProgress
  , displayStartedAt
  , stopDisplay
  , Tally (..)
  , elapsed
  , milliseconds
  , Paint (..)
  , painter
  ) where

import Control.Concurrent (ThreadId, forkIO, killThread, threadDelay)
import Control.Concurrent.MVar (MVar, modifyMVar_, newMVar, readMVar, withMVar)
import Control.Monad (when)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime)
import Pudu.Package.Identity (renderPackageId)
import Pudu.Package.Progress (Event (..), Progress (..))
import System.Environment (lookupEnv)
import System.IO (Handle, hFlush, hIsTerminalDevice, stderr, stdout)

data Verbosity = Quiet | Normal | Verbose
  deriving stock (Eq, Show)

{-| Event counts accumulated by a `Display`. -}
data Tally = Tally
  { tallyFetched :: !Int
  , tallyCached :: !Int
  , tallyResolved :: !(Maybe Int)
  , tallyCopied :: !Int
  , tallyUpToDate :: !Int
  , tallyActive :: !(Set.Set Text)
  , tallyResolvedAt :: !(Maybe UTCTime)
  }

emptyTally :: Tally
emptyTally = Tally 0 0 Nothing 0 0 Set.empty Nothing

data Display = Display
  { displayProgress :: !Progress
  , displayState :: !(MVar Tally)
  , displayStartedAt :: !UTCTime
  , displayTicker :: !(Maybe ThreadId)
  , displayLive :: !Bool
  }

{-| Create a display. The status line is drawn only at `Normal` verbosity
    with a terminal stderr. -}
startDisplay :: Verbosity -> IO Display
startDisplay verbosity = do
  started <- getCurrentTime
  state <- newMVar emptyTally
  terminal <- hIsTerminalDevice stderr
  let live = terminal && verbosity == Normal
  let tick n = do
        now <- getCurrentTime
        withMVar state (\tally -> drawLive stderr (spinner n) tally now started)
        threadDelay 80000
        tick (n + 1)
  ticker <-
    if live
      then Just <$> forkIO (tick 0)
      else pure Nothing
  let record event = do
        now <- getCurrentTime
        modifyMVar_ state (pure . count now event)
        when (verbosity == Verbose) $
          withMVar state $ \_ ->
            TextIO.hPutStrLn stderr ("[" <> seconds now started <> "] " <> describe event)
  pure (Display (Progress record) state started ticker live)

{-| Stop the ticker, clear the status line, and return the counts. -}
stopDisplay :: Display -> IO Tally
stopDisplay display = do
  mapM_ killThread (displayTicker display)
  when (displayLive display) $ withMVar (displayState display) $ \_ -> do
    TextIO.hPutStr stderr "\r\ESC[K"
    hFlush stderr
  readMVar (displayState display)

count :: UTCTime -> Event -> Tally -> Tally
count now event tally = case event of
  FetchStarted url -> tally{tallyActive = Set.insert (shortUrl url) (tallyActive tally)}
  FetchFinished url -> tally{tallyFetched = tallyFetched tally + 1, tallyActive = Set.delete (shortUrl url) (tallyActive tally)}
  CacheHit _ -> tally{tallyCached = tallyCached tally + 1}
  CheckoutStarted _ _ -> tally
  Resolved n -> tally{tallyResolved = Just n, tallyResolvedAt = Just now, tallyActive = Set.empty}
  CopyStarted package _ -> tally{tallyActive = Set.insert (renderPackageId package) (tallyActive tally)}
  CopyFinished package -> tally{tallyCopied = tallyCopied tally + 1, tallyActive = Set.delete (renderPackageId package) (tallyActive tally)}
  UpToDate _ -> tally{tallyUpToDate = tallyUpToDate tally + 1}

describe :: Event -> Text
describe event = case event of
  FetchStarted url -> "fetching " <> url
  FetchFinished url -> "fetched " <> url
  CacheHit url -> "from cache " <> url
  CheckoutStarted url commit -> "checking out " <> url <> " at " <> Text.take 12 commit
  Resolved n -> "resolved " <> Text.pack (show n) <> " packages"
  CopyStarted package version -> "copying " <> renderPackageId package <> " " <> version
  CopyFinished package -> "installed " <> renderPackageId package
  UpToDate package -> "up to date " <> renderPackageId package

drawLive :: Handle -> Text -> Tally -> UTCTime -> UTCTime -> IO ()
drawLive handle glyph tally now started = do
  let phase = case tallyResolved tally of
        Nothing ->
          "Resolving" <> counts [(tallyFetched tally, "fetched"), (tallyCached tally, "from cache")]
        Just total ->
          "Installing " <> Text.pack (show (tallyCopied tally + tallyUpToDate tally)) <> "/" <> Text.pack (show total)
            <> counts [(tallyCopied tally, "copied"), (tallyUpToDate tally, "up to date")]
      working = case Set.toList (tallyActive tally) of
        [] -> ""
        [one] -> " · " <> one
        one : more -> " · " <> one <> " and " <> Text.pack (show (length more)) <> " more"
      line = glyph <> " " <> phase <> Text.take (72 - Text.length phase) working <> "  " <> seconds now started
  TextIO.hPutStr handle ("\r\ESC[K" <> line)
  hFlush handle
 where
  counts items = case [Text.pack (show n) <> " " <> label | (n, label) <- items, n > 0] of
    [] -> ""
    shown -> " · " <> Text.intercalate ", " shown

{-| A URL without its scheme and `.git` suffix, truncated to its last 40
    characters. -}
shortUrl :: Text -> Text
shortUrl url =
  let bare = snd (Text.breakOnEnd "://" url)
      trimmed = maybe bare id (Text.stripSuffix ".git" (Text.dropWhileEnd (== '/') bare))
   in if Text.length trimmed <= 40 then trimmed else "…" <> Text.takeEnd 39 trimmed

spinner :: Int -> Text
spinner n = Text.singleton ("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" !! (n `mod` 10))

elapsed :: UTCTime -> UTCTime -> Double
elapsed now started = realToFrac (diffUTCTime now started)

seconds :: UTCTime -> UTCTime -> Text
seconds now started = milliseconds (elapsed now started)

{-| A duration in seconds rendered as `412ms` below one second and `1.3s` above. -}
milliseconds :: Double -> Text
milliseconds value
  | value < 1 = Text.pack (show (round (value * 1000) :: Int)) <> "ms"
  | otherwise = Text.pack (show (fromIntegral (round (value * 10) :: Int) / 10 :: Double)) <> "s"

{-| Colour functions for the summary: added, removed, changed, dim, and bold. -}
data Paint = Paint
  { paintAdded :: Text -> Text
  , paintRemoved :: Text -> Text
  , paintChanged :: Text -> Text
  , paintDim :: Text -> Text
  , paintStrong :: Text -> Text
  }

painter :: IO Paint
painter = do
  terminal <- hIsTerminalDevice stdout
  noColor <- lookupEnv "NO_COLOR"
  let on = terminal && maybe True null noColor
      wrap code text = if on then "\ESC[" <> code <> "m" <> text <> "\ESC[0m" else text
  pure (Paint (wrap "32") (wrap "31") (wrap "33") (wrap "2") (wrap "1"))
