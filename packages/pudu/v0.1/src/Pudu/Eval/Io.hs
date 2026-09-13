{-| @Eval.Io.Module — the effects a program may perform -}
module Pudu.Eval.Io
  ( IoOutcome (..)
  , appendTextFile
  , canonicalPathAt
  , createDirectoryExclusiveAt
  , createSymbolicLinkAt
  , createTemporaryFileIn
  , createDirectoryAt
  , environmentPairs
  , exitWith
  , fileSizeAt
  , homeDirectoryPath
  , isSymbolicLinkAt
  , listDirectoryAt
  , monotonicMilliseconds
  , pathSeparators
  , permissionsMaskAt
  , programArguments
  , readStandardLine
  , readTextFile
  , removeEmptyDirectoryAt
  , removeFileAt
  , renamePathAt
  , searchPathSeparatorText
  , setPermissionsMaskAt
  , temporaryDirectoryPath
  , testDirectoryExists
  , testFileExists
  , trySynchronous
  , writeStandardError
  , writeStandardErrorPart
  , writeStandardOutput
  , writeStandardOutputPart
  , writeTextFile
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( IOException
  , SomeAsyncException
  , SomeException
  , fromException
  , try
  , tryJust
  )
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import GHC.Clock (getMonotonicTime)
import System.Directory
  ( canonicalizePath
  , createDirectory
  , createDirectoryIfMissing
  , createFileLink
  , doesDirectoryExist
  , doesFileExist
  , emptyPermissions
  , executable
  , getFileSize
  , getPermissions
  , getTemporaryDirectory
  , listDirectory
  , pathIsSymbolicLink
  , readable
  , removeDirectory
  , removeFile
  , renamePath
  , searchable
  , setOwnerExecutable
  , setOwnerReadable
  , setOwnerSearchable
  , setOwnerWritable
  , setPermissions
  , writable
  )
import System.Environment (getArgs, getEnvironment, lookupEnv)
import qualified System.FilePath as FilePath
import System.Exit (ExitCode (ExitFailure), exitSuccess)
import qualified System.Exit
import System.IO (hClose, hFlush, hIsEOF, hPutStrLn, openBinaryTempFile, stderr, stdin, stdout)
import System.IO.Error (doesNotExistErrorType, mkIOError)

{-| An action's failure as a value, for every failure the action itself raised.

    An asynchronous exception — an interrupt, a thread being killed, a timeout
    firing — is re-raised instead. It did not come from the action, and turning
    it into a value is how Ctrl-C became an ordinary failure a server loop
    retried: a process blocked in accept answered `user interrupt` as though a
    connection had failed, and kept running. -}
trySynchronous :: IO a -> IO (Either SomeException a)
trySynchronous = tryJust synchronousOnly
 where
  synchronousOnly problem = case fromException problem :: Maybe SomeAsyncException of
    Just _ -> Nothing
    Nothing -> Just problem

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

{-| Write text and leave the line open, so a prompt, a progress report, or a
    line assembled from several writes is possible at all. Flushed for the same
    reason the line-ending writers are: text still sitting in a buffer has not
    been shown, and a prompt nobody can see is a program that appears to have
    stopped. -}
writeStandardOutputPart :: Text -> IO (IoOutcome ())
writeStandardOutputPart text = attempt $ do
  TextIO.hPutStr stdout text
  hFlush stdout

writeStandardErrorPart :: Text -> IO (IoOutcome ())
writeStandardErrorPart text = attempt $ do
  TextIO.hPutStr stderr text
  hFlush stderr

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

{-| Whether a path names a directory, following a link to one. -}
testDirectoryExists :: FilePath -> IO Bool
testDirectoryExists = doesDirectoryExist

{-| A path renamed, replacing the destination.

    Within one filesystem the destination names the old contents or the new and
    never a mixture, which is the one step an atomic replacement is built on. -}
renamePathAt :: FilePath -> FilePath -> IO (IoOutcome ())
renamePathAt from to = attempt (renamePath from to)

{-| A new empty file in a directory, named and created in one step.

    The operating system chooses the name and creates the file exclusively, so
    no other process can claim the name between its choice and its creation. The
    name is the prefix, random digits, and `.tmp`: the digits are placed before
    a template's extension, so giving the template its own extension is what
    keeps the prefix intact when the prefix itself contains a dot. -}
createTemporaryFileIn :: FilePath -> FilePath -> IO (IoOutcome Text)
createTemporaryFileIn directory prefix = attempt $ do
  (path, handle) <- openBinaryTempFile directory (prefix <> ".tmp")
  hClose handle
  pure (Text.pack path)

{-| A directory created only if nothing has the name, without its parents.

    Failing on an existing name is the point: the attempt is what claims it. -}
createDirectoryExclusiveAt :: FilePath -> IO (IoOutcome ())
createDirectoryExclusiveAt path = attempt (createDirectory path)

{-| An empty directory removed; one with contents is refused. -}
removeEmptyDirectoryAt :: FilePath -> IO (IoOutcome ())
removeEmptyDirectoryAt path = attempt (removeDirectory path)

{-| What a path permits, as a mask: readable 1, writable 2, executable 4,
    searchable 8. -}
permissionsMaskAt :: FilePath -> IO (IoOutcome Integer)
permissionsMaskAt path = attempt $ do
  granted <- getPermissions path
  pure
    ( weight readable 1 granted
        + weight writable 2 granted
        + weight executable 4 granted
        + weight searchable 8 granted
    )
 where
  weight test amount value = if test value then amount else 0

{-| A path's permissions set from the same mask `permissionsMaskAt` answers. -}
setPermissionsMaskAt :: FilePath -> Integer -> IO (IoOutcome ())
setPermissionsMaskAt path mask =
  attempt
    ( setPermissions path
        ( setOwnerReadable (flag 1)
            . setOwnerWritable (flag 2)
            . setOwnerExecutable (flag 4)
            . setOwnerSearchable (flag 8)
            $ emptyPermissions
        )
    )
 where
  flag amount = (mask `div` amount) `mod` 2 == 1

{-| Whether a path is itself a symbolic link, without following it. -}
isSymbolicLinkAt :: FilePath -> IO (IoOutcome Bool)
isSymbolicLinkAt path = attempt (pathIsSymbolicLink path)

{-| A symbolic link at `link` naming `target`. -}
createSymbolicLinkAt :: FilePath -> FilePath -> IO (IoOutcome ())
createSymbolicLinkAt target link = attempt (createFileLink target link)

{-| A path with every link and relative step resolved.

    Refused when the path does not exist, because a location that does not
    exist has no links to resolve and a containment check made on its spelling
    would trust exactly what it exists to distrust. -}
canonicalPathAt :: FilePath -> IO (IoOutcome Text)
canonicalPathAt path = attempt $ do
  present <- testFileExists path
  if present
    then Text.pack <$> canonicalizePath path
    else ioError (mkIOError doesNotExistErrorType "canonicalPath" Nothing (Just path))

{-| A file's size in bytes. -}
fileSizeAt :: FilePath -> IO (IoOutcome Integer)
fileSizeAt path = attempt (getFileSize path)

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
