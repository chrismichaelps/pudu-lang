{-| @Eval.Io.Module — the effects a program may perform -}
module Pudu.Eval.Io
  ( IoOutcome (..)
  , appendTextFile
  , createDirectoryAt
  , environmentPairs
  , exitWith
  , listDirectoryAt
  , monotonicMilliseconds
  , programArguments
  , readStandardLine
  , readTextFile
  , removeFileAt
  , testFileExists
  , writeStandardError
  , writeStandardOutput
  , writeTextFile
  ) where

import Control.Exception (IOException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.Clock (getMonotonicTime)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  , removeFile
  )
import System.Environment (getArgs, getEnvironment)
import System.Exit (ExitCode (ExitFailure), exitSuccess)
import qualified System.Exit
import System.IO (hFlush, hIsEOF, hPutStrLn, stderr, stdin, stdout)

{-| @Eval.Io.Outcome — what an effect produced, or why it did not.

    Every effect answers this rather than raising, because the language has no
    exceptions: a program that reads a missing file gets a `Result` and decides
    what to do, and the runtime never unwinds past a boundary the program cannot
    see. The message is what the operating system said, unchanged — a program
    reporting a failure to its own user is better served by the real reason than
    by one this module invented. -}
data IoOutcome a
  = IoDone !a
  | IoFailed !Text
  deriving stock (Eq, Show, Functor)

{-| Text written to the program's output, followed by a newline.

    The handle is flushed, so a program that prints and then blocks on input has
    already shown what it printed. Buffering that hid a prompt would be a
    correctness problem, not a performance one. -}
writeStandardOutput :: Text -> IO (IoOutcome ())
writeStandardOutput text = attempt $ do
  TextIO.hPutStrLn stdout text
  hFlush stdout

writeStandardError :: Text -> IO (IoOutcome ())
writeStandardError text = attempt (hPutStrLn stderr (Text.unpack text))

{-| One line of the program's input, or nothing at the end of it.

    End of input is not a failure: a program reading until there is no more is
    doing the ordinary thing, and reporting it as an error would make every such
    loop handle a failure that is not one. -}
readStandardLine :: IO (IoOutcome (Maybe Text))
readStandardLine = attempt $ do
  ended <- hIsEOF stdin
  if ended then pure Nothing else Just <$> TextIO.hGetLine stdin

readTextFile :: FilePath -> IO (IoOutcome Text)
readTextFile path = attempt (TextIO.readFile path)

writeTextFile :: FilePath -> Text -> IO (IoOutcome ())
writeTextFile path contents = attempt (TextIO.writeFile path contents)

appendTextFile :: FilePath -> Text -> IO (IoOutcome ())
appendTextFile path contents = attempt (TextIO.appendFile path contents)

{-| Whether a path names a file or a directory that exists.

    A question about the world is not a failure even when the answer is no, so
    this answers a plain truth value rather than a result. A caller that wants
    to know *why* a path is unusable should try to use it. -}
testFileExists :: FilePath -> IO Bool
testFileExists path = do
  asFile <- doesFileExist path
  if asFile then pure True else doesDirectoryExist path

removeFileAt :: FilePath -> IO (IoOutcome ())
removeFileAt path = attempt (removeFile path)

listDirectoryAt :: FilePath -> IO (IoOutcome [Text])
listDirectoryAt path = attempt (map Text.pack <$> listDirectory path)

{-| A directory and every parent it needs.

    Creating one that already exists succeeds: a caller writing into a directory
    wants it to be there, and had it check first there would be a race between
    the check and the write. -}
createDirectoryAt :: FilePath -> IO (IoOutcome ())
createDirectoryAt path = attempt (createDirectoryIfMissing True path)

programArguments :: IO [Text]
programArguments = map Text.pack <$> getArgs

environmentPairs :: IO [(Text, Text)]
environmentPairs = map (\(name, value) -> (Text.pack name, Text.pack value)) <$> getEnvironment

{-| Milliseconds on a clock that only moves forward.

    A monotonic clock rather than the calendar, because the one thing a program
    can honestly do with a bare number is subtract two of them, and a calendar
    clock can move backwards between the two reads. -}
monotonicMilliseconds :: IO Integer
monotonicMilliseconds = round . (* 1000) <$> getMonotonicTime

{-| Stop the program with a status.

    The only effect that does not answer with an outcome, because a program that
    asked to stop has nothing left to decide. A status outside the range an
    operating system carries is clamped rather than refused: the program meant
    to stop, and refusing would leave it running. -}
exitWith :: Integer -> IO ()
exitWith code
  | code == 0 = exitSuccess
  | otherwise = exitWithStatus (fromInteger (max 1 (min 255 code)))

exitWithStatus :: Int -> IO ()
exitWithStatus status = exitWith' (ExitFailure status)
 where
  exitWith' = System.Exit.exitWith

{-| Run an effect, turning the operating system's refusal into an outcome. -}
attempt :: IO a -> IO (IoOutcome a)
attempt action = do
  outcome <- try action
  pure $ case outcome of
    Right value -> IoDone value
    Left problem -> IoFailed (Text.pack (show (problem :: IOException)))
