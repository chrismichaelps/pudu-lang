{-| @Eval.Io.Module — the effects a program may perform -}
module Pudu.Eval.Io
  ( IoOutcome (..)
  , appendTextFile
  , createDirectoryAt
  , environmentPairs
  , exitWith
  , homeDirectoryPath
  , listDirectoryAt
  , monotonicMilliseconds
  , pathSeparators
  , programArguments
  , readStandardLine
  , readTextFile
  , removeFileAt
  , searchPathSeparatorText
  , temporaryDirectoryPath
  , testFileExists
  , writeStandardError
  , writeStandardOutput
  , writeTextFile
  ) where

import Control.Applicative ((<|>))
import Control.Exception (IOException, try)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.Clock (getMonotonicTime)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getTemporaryDirectory
  , listDirectory
  , removeFile
  )
import System.Environment (getArgs, getEnvironment, lookupEnv)
import qualified System.FilePath as FilePath
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

{-| Where this machine says a program may put a file it does not intend to keep.

    Asked of the operating system rather than spelled out, because the answer is
    not the same everywhere and is not the program's to decide: it honours
    `TMPDIR` where that is set, and answers with the system's own directory on a
    machine that has no such variable and no `/tmp` at all. A program that wrote
    `/tmp` directly would be stating one machine's answer as though it were
    every machine's. -}
temporaryDirectoryPath :: IO Text
temporaryDirectoryPath = Text.pack <$> getTemporaryDirectory

{-| The directory this machine calls the reader's own.

    `HOME` where it is set, and `USERPROFILE` where it is not, which is the pair
    of names the two families of operating system use. Asking for only the first
    answers `None` on a machine that has a home directory and a different word
    for it. -}
homeDirectoryPath :: IO (Maybe Text)
homeDirectoryPath = do
  home <- lookupEnv "HOME"
  profile <- lookupEnv "USERPROFILE"
  pure (Text.pack <$> (home <|> profile))

{-| The characters this machine accepts between the pieces of a path.

    The first is the one to write when joining; the rest are ones to recognise
    when taking a path apart. They differ because one family of operating system
    reads both its own separator and the other's, so a path arriving from
    elsewhere still has to come apart correctly even though it is not the shape
    this machine would have written. -}
pathSeparators :: [Text]
pathSeparators = map Text.singleton (written : filter (/= written) FilePath.pathSeparators)
 where
  written = FilePath.pathSeparator

{-| The character this machine puts between the entries of a search path.

    A colon on one family of operating system and a semicolon on the other,
    which is why `PATH` cannot be split on a written-down character. -}
searchPathSeparatorText :: Text
searchPathSeparatorText = Text.singleton FilePath.searchPathSeparator

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
