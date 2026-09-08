{-| @Eval.Clock.Module — calendar time and subprocesses -}
module Pudu.Eval.Clock
  ( ProcessOutcome (..)
  , currentInstant
  , formatInstant
  , parseInstant
  , runProcess
  , timeZoneOffset
  ) where

import Control.Exception (IOException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (UTCTime, getCurrentTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime, utcTimeToPOSIXSeconds)
import Data.Time.Format
  ( defaultTimeLocale
  , formatTime
  , parseTimeM
  )
import Data.Time.LocalTime (getCurrentTimeZone, timeZoneMinutes)
import System.Exit (ExitCode (ExitFailure, ExitSuccess))
import System.Process (readProcessWithExitCode)

{-| Milliseconds since the start of 1970, on the system clock.

    Milliseconds rather than seconds because a program measuring anything
    shorter than a second would otherwise have to reach for a second clock, and
    rather than nanoseconds because the language's integers are the ones a
    reader writes and a nanosecond count is not one of those.

    This clock can move backwards when the system's is adjusted. That is what
    makes it the wrong one for measuring a duration, which is why the monotonic
    clock exists beside it. -}
currentInstant :: IO Integer
currentInstant = do
  now <- getCurrentTime
  pure (round (utcTimeToPOSIXSeconds now * 1000))

{-| An instant rendered with a pattern.

    The pattern vocabulary is the platform's, not one invented here: a reader
    who knows `%Y-%m-%d` should not have to learn a second spelling of it. -}
formatInstant :: Text -> Integer -> Text -> IO (Either Text Text)
formatInstant pattern milliseconds zone = do
  offset <- offsetFor zone
  let shifted = posixSecondsToUTCTime (fromIntegral (milliseconds + offset * 60000) / 1000)
  pure (Right (Text.pack (formatTime defaultTimeLocale (Text.unpack pattern) shifted)))

{-| Text read as an instant with a pattern, or a report that it did not fit.

    The failure says the pattern rather than the text, because a caller with a
    thousand lines to read wants to know which of the two is wrong and only the
    pattern is theirs. -}
parseInstant :: Text -> Text -> Either Text Integer
parseInstant pattern text =
  case parseTimeM True defaultTimeLocale (Text.unpack pattern) (Text.unpack text) of
    Nothing -> Left ("the text does not fit the pattern " <> pattern)
    Just parsed -> Right (round (utcTimeToPOSIXSeconds (parsed :: UTCTime) * 1000))

{-| The offset a zone name asks for, in minutes east of UTC.

    Only `utc` and `local` are named. A full zone database is a data
    dependency this compiler does not carry, and answering for `Europe/Madrid`
    without one would be answering wrongly. -}
offsetFor :: Text -> IO Integer
offsetFor zone
  | zone == "local" = do
      here <- getCurrentTimeZone
      pure (fromIntegral (timeZoneMinutes here))
  | otherwise = pure 0

{-| The local zone's offset from UTC, in minutes. -}
timeZoneOffset :: IO Integer
timeZoneOffset = fromIntegral . timeZoneMinutes <$> getCurrentTimeZone

{-| @Eval.Clock.ProcessOutcome — what running a program produced. -}
data ProcessOutcome = ProcessOutcome
  { processStatus :: !Integer
  , processOutput :: !Text
  , processErrors :: !Text
  }
  deriving stock (Eq, Show)

{-| Run a program to completion and collect what it produced.

    Both streams are captured rather than inherited, because a caller that
    wanted them inherited would not be asking for them back, and one that gets
    them can print them itself. A non-zero status is not a failure of this
    call: the program ran, and what it decided is the answer. Only being unable
    to run it at all is a failure. -}
runProcess :: FilePath -> [Text] -> Text -> IO (Either Text ProcessOutcome)
runProcess program arguments standardInput = do
  outcome <-
    try
      ( readProcessWithExitCode
          program
          (map Text.unpack arguments)
          (Text.unpack standardInput)
      )
  pure $ case outcome of
    Left problem -> Left (Text.pack (show (problem :: IOException)))
    Right (code, out, errors) ->
      Right
        ProcessOutcome
          { processStatus = case code of
              ExitSuccess -> 0
              ExitFailure status -> fromIntegral status
          , processOutput = Text.pack out
          , processErrors = Text.pack errors
          }
