{-| @Pudu.Cli.Package — the commands that change and show a project's dependencies

    `install`, `uninstall`, `update`, `deps`, and `tree` read their arguments
    here, change `pudu.toml` when they are asked to, and hand the rest to
    `Package.Install`. When installing fails, the manifest is put back exactly
    as it was, so a mistyped name leaves nothing behind.

    While a command works, `Cli.Progress` shows what it is doing; when it is
    done, the report says what was resolved and where it came from, what
    changed, what was installed, and how long each part took. -}
module Pudu.Cli.Package
  ( runPackageCommand
  , packageCommands
  ) where

import Control.Concurrent (getNumCapabilities, setNumCapabilities)
import Control.Monad (forM_, unless, when)
import Data.List (sort, sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Manifest (Dependency (..), DependencySource (..), Manifest (..), parseManifest)
import Data.Time.Clock (getCurrentTime)
import GHC.Conc (getNumProcessors)
import Pudu.Cli.Progress
  ( Display
  , Paint (..)
  , Tally (..)
  , Verbosity (..)
  , displayProgress
  , displayStartedAt
  , elapsed
  , milliseconds
  , painter
  , startDisplay
  , stopDisplay
  )
import Pudu.Package.Git (GitSession, checkoutDirectory, checkoutGit, newGitSession)
import Pudu.Package.Identity
  ( InstallSpec (..)
  , PackageId (..)
  , installDirectory
  , parseInstallSpec
  , parsePackageId
  , renderPackageId
  , validSegment
  )
import Pudu.Package.Install
  ( Change (..)
  , Options (..)
  , Outcome (..)
  , Project (..)
  , defaultOptions
  , openProject
  , sourceDirectoryOf
  , synchronise
  )
import Pudu.Package.Lock (Lock (..), LockEntry (..))
import Pudu.Package.ManifestEdit (removeDependency, setDependency)
import Pudu.Package.Solve (Registry)
import System.Directory (doesDirectoryExist, doesFileExist, listDirectory, makeAbsolute)
import System.Exit (exitFailure)
import System.FilePath (dropExtension, makeRelative, takeExtension, takeFileName, (</>))
import System.IO (hPutStrLn, stderr)

packageCommands :: [String]
packageCommands = ["install", "uninstall", "update", "deps", "tree"]

{-| Run one package command, given how to reach a registry. -}
runPackageCommand :: IO Registry -> String -> [String] -> IO ()
runPackageCommand connect command arguments = do
  let (flags, rest) = splitFlags arguments
      offline = "--offline" `elem` flags
      verbosity
        | "--quiet" `elem` flags = Quiet
        | "--verbose" `elem` flags = Verbose
        | otherwise = Normal
      unknown = filter (`notElem` ["--offline", "--locked", "--quiet", "--verbose"]) flags
  case unknown of
    flag : _ -> failWith command ("unknown option " <> Text.pack flag)
    [] -> pure ()
  opened <- openProject
  project <- either (failWith command) pure opened
  let changing = command `elem` ["install", "uninstall", "update"]
  when changing useProcessors
  display <- startDisplay (if changing then verbosity else Quiet)
  session <- newGitSession offline (displayProgress display)
  let options =
        defaultOptions
          { optionOffline = offline
          , optionLocked = "--locked" `elem` flags
          , optionProgress = displayProgress display
          , optionGit = Just session
          }
      run = Run command display verbosity session
  case command of
    "install" -> do
      registry <- connect
      install run registry options project (map Text.pack rest)
    "uninstall" -> do
      registry <- connect
      when (null rest) (failWith command "name the dependencies to remove, such as pudu uninstall @alice/json")
      uninstall run registry options project (map Text.pack rest)
    "update" -> do
      registry <- connect
      named <- traverse (either (failWith command) pure . parsePackageId . Text.pack) rest
      let refresh package = null named || package `elem` named
      apply run registry options{optionRefresh = refresh} project (projectManifestText project)
    "deps" -> showDependencies project
    "tree" -> showTree project
    _ -> failWith command "unknown package command"

{-| One command's run: its name, its live display, and how much it says. -}
data Run = Run
  { runCommand :: !String
  , runDisplay :: !Display
  , runVerbosity :: !Verbosity
  , runSession :: !GitSession
  }

{-| Hashing and copying run on every core the machine has, up to the number
    of packages worked on at once. -}
useProcessors :: IO ()
useProcessors = do
  current <- getNumCapabilities
  processors <- getNumProcessors
  when (current < processors) (setNumCapabilities (min 8 processors))

splitFlags :: [String] -> ([String], [String])
splitFlags arguments = (filter isFlag arguments, filter (not . isFlag) arguments)
 where
  isFlag argument = take 2 argument == "--"

install :: Run -> Registry -> Options -> Project -> [Text] -> IO ()
install run registry options project [] = apply run registry options project (projectManifestText project)
install run registry options project specs = do
  edited <- foldEdits (projectManifestText project) specs
  apply run registry options project edited
 where
  foldEdits text [] = pure text
  foldEdits text (spec : more) = do
    parsed <- either (failWith "install") pure (parseInstallSpec spec)
    (key, value) <- entryFor parsed
    foldEdits (setDependency key value text) more
  entryFor parsed = case parsed of
    SpecRegistry package wanted ->
      pure (renderPackageId package, quoted (maybe "*" requirementFrom wanted))
    SpecPath path -> do
      absolute <- makeAbsolute path
      named <- nameOfDirectory absolute
      let relative = makeRelative (projectRoot project) absolute
          written = if take 1 relative == "/" then absolute else relative
      pure (named, "{ path = " <> quoted (Text.pack written) <> " }")
    SpecGit url revision -> do
      fetched <- checkoutGit (runSession run) url (maybe "HEAD" id revision)
      checkout <- either (failWith "install") pure fetched
      named <- nameOfDirectoryOr (checkoutDirectory checkout) (repositoryName url)
      pure (named, "{ git = " <> quoted url <> maybe "" (\r -> ", rev = " <> quoted r) revision <> " }")
  requirementFrom wanted
    | Text.any (`elem` ("^~=<>*," :: String)) wanted = wanted
    | otherwise = "=" <> wanted

{-| A registry package asked for with no version gets `*` for the moment it is
    solved, and is then rewritten to be compatible with what was chosen. -}
apply :: Run -> Registry -> Options -> Project -> Text -> IO ()
apply run registry options project manifestText = do
  let root = projectRoot project
      manifestPath = root </> "pudu.toml"
      command = runCommand run
  result <- synchronise registry options root manifestText (projectLock project)
  tally <- stopDisplay (runDisplay run)
  case result of
    Left problem -> failWith command problem
    Right outcome -> do
      let settled = pinWildcards (outcomeLock outcome) manifestText
      when (settled /= projectManifestText project) (TextIO.writeFile manifestPath settled)
      unless (runVerbosity run == Quiet) $
        report run tally (projectRoot project) outcome (settled /= projectManifestText project)



{-| Replace a `*` written by `pudu install @h/n` with `^` of the chosen version. -}
pinWildcards :: Lock -> Text -> Text
pinWildcards (Lock entries) text = foldr pin text (manifestDependencies (parseManifest text))
 where
  pin dependency current = case dependencySource dependency of
    RegistrySource "*" -> case filter (\e -> Right (entryName e) == parsePackageId (dependencyName dependency)) entries of
      entry : _ -> setDependency (dependencyName dependency) (quoted ("^" <> entryVersion entry)) current
      [] -> current
    _ -> current

uninstall :: Run -> Registry -> Options -> Project -> [Text] -> IO ()
uninstall run registry options project names = do
  let go text [] = pure text
      go text (name : more) = case removeDependency name text of
        Just edited -> go edited more
        Nothing -> failWith "uninstall" (name <> " is not a dependency in pudu.toml")
  edited <- go (projectManifestText project) names
  apply run registry options project edited

report :: Run -> Tally -> FilePath -> Outcome -> Bool -> IO ()
report run tally root outcome manifestChanged = do
  paint <- painter
  now <- getCurrentTime
  let added' = paintAdded paint
      removed' = paintRemoved paint
      changed' = paintChanged paint
      dim = paintDim paint
      describe change = case change of
        Added p v -> added' "+ " <> renderPackageId p <> " " <> dim v
        Removed p v -> removed' "- " <> renderPackageId p <> " " <> dim v
        Moved p old new -> changed' "~ " <> renderPackageId p <> " " <> dim (old <> " → " <> new)
      changes = outcomeChanges outcome
      started = displayStartedOf run
      took from = dim ("in " <> milliseconds (elapsed now from))
      sources = [Text.pack (show n) <> " " <> label | (n, label) <- [(tallyFetched tally, "fetched"), (tallyCached tally, "from cache")], n > 0]
      resolvedLine total =
        "Resolved " <> plural total "package" <> " "
          <> maybe "" (\at -> dim ("in " <> milliseconds (elapsed at started)) <> " ") (tallyResolvedAt tally)
          <> (if null sources then "" else dim ("· " <> Text.intercalate ", " sources))
  forM_ (tallyResolved tally) (TextIO.putStrLn . Text.stripEnd . resolvedLine)
  unless (null changes) $ do
    let added = length [() | Added{} <- changes]
        removed = length [() | Removed{} <- changes]
        moved = length [() | Moved{} <- changes]
        counts = [added' ("+" <> Text.pack (show added)) | added > 0] <> [removed' ("-" <> Text.pack (show removed)) | removed > 0] <> [changed' ("~" <> Text.pack (show moved)) | moved > 0]
    TextIO.putStrLn ("Packages: " <> Text.unwords counts)
    forM_ (sortOn changeName changes) (TextIO.putStrLn . ("  " <>) . describe)
  let installed = outcomeInstalled outcome
      current = tallyUpToDate tally
  if installed > 0
    then
      TextIO.putStrLn
        ( (if null changes then "Restored " <> plural installed "package" <> " in deps/ from pudu.lock " else "Installed " <> plural installed "package" <> " into deps/ ")
            <> maybe "" took (tallyResolvedAt tally)
            <> (if current > 0 then dim (" · " <> Text.pack (show current) <> " up to date") else "")
        )
    else when (null changes) (TextIO.putStrLn "Already up to date")
  let written = [f | (f, True) <- [("pudu.toml", manifestChanged), ("pudu.lock", outcomeLockWritten outcome)]]
  unless (null written) (TextIO.putStrLn ("Wrote " <> Text.intercalate ", " written))
  when (runCommand run == "install") $ do
    let added = [p | Added p _ <- changes]
        roots = [(p, r) | (p, r) <- outcomeRoots outcome, p `elem` added]
    forM_ roots $ \(package, moduleRoot) -> do
      example <- exampleModule (installDirectory root package) moduleRoot
      TextIO.putStrLn ("\n" <> paintStrong paint (renderPackageId package) <> " provides the modules under " <> moduleRoot <> ", such as:\n  import " <> example)
  TextIO.putStrLn ("\nDone " <> took started)
 where
  displayStartedOf = displayStartedAt . runDisplay
  changeName change = case change of
    Added p _ -> renderPackageId p
    Removed p _ -> renderPackageId p
    Moved p _ _ -> renderPackageId p

showDependencies :: Project -> IO ()
showDependencies project = do
  let dependencies = manifestDependencies (projectManifest project)
      Lock entries = projectLock project
  when (null dependencies) (TextIO.putStrLn "no dependencies; add one with pudu install")
  forM_ dependencies $ \dependency -> do
    let key = dependencyName dependency
        locked = [e | e <- entries, Right (entryName e) == parsePackageId key]
        asked = case dependencySource dependency of
          RegistrySource requirement -> requirement
          PathSource path -> "path " <> Text.pack path
          GitSource url revision -> "git " <> url <> maybe "" (" @ " <>) revision
          UnreadableSource reason -> "unreadable: " <> reason
        chosen = case locked of
          e : _ -> "locked " <> entryVersion e
          [] -> case dependencySource dependency of
            PathSource _ -> "used in place"
            _ -> "not installed; run pudu install"
    TextIO.putStrLn (key <> "  " <> asked <> "  (" <> chosen <> ")")

showTree :: Project -> IO ()
showTree project = do
  let Lock entries = projectLock project
      manifest = projectManifest project
      top = [p | d <- manifestDependencies manifest, Right p <- [parsePackageId (dependencyName d)]]
      entryOf package = case filter ((== package) . entryName) entries of
        e : _ -> Just e
        [] -> Nothing
      name = maybe "this project" id (manifestName manifest)
      walk depth seen package = do
        let indent = Text.replicate depth "  "
        case entryOf package of
          Nothing -> TextIO.putStrLn (indent <> renderPackageId package <> " (in place)")
          Just entry -> do
            TextIO.putStrLn (indent <> renderPackageId package <> " " <> entryVersion entry <> (if package `elem` seen then " (above)" else ""))
            unless (package `elem` seen) $
              forM_ (entryDependencies entry) $ \dependency ->
                case parsePackageId dependency of
                  Right child -> walk (depth + 1) (package : seen) child
                  Left _ -> pure ()
  TextIO.putStrLn name
  forM_ top (walk 1 [])

{-| A module a package really has under its root, to show how it is imported:
    the root module itself when there is one, or the first module beneath it. -}
exampleModule :: FilePath -> Text -> IO Text
exampleModule directory moduleRoot = do
  source <- sourceDirectoryOf directory
  let rootFile = source </> Text.unpack moduleRoot <> ".pudu"
      rootDirectory = source </> Text.unpack moduleRoot
  hasRootFile <- doesFileExist rootFile
  hasDirectory <- doesDirectoryExist rootDirectory
  if hasRootFile
    then pure moduleRoot
    else
      if not hasDirectory
        then pure moduleRoot
        else do
          names <- sort <$> listDirectory rootDirectory
          pure $ case [n | n <- names, takeExtension n == ".pudu"] of
            first : _ -> moduleRoot <> "." <> Text.pack (dropExtension first)
            [] -> moduleRoot

nameOfDirectory :: FilePath -> IO Text
nameOfDirectory directory = nameOfDirectoryOr directory (normalised (Text.pack (takeFileName directory)))

nameOfDirectoryOr :: FilePath -> Text -> IO Text
nameOfDirectoryOr directory fallback = do
  hasManifest <- doesFileExist (directory </> "pudu.toml")
  if not hasManifest
    then pure fallback
    else do
      manifest <- parseManifest <$> TextIO.readFile (directory </> "pudu.toml")
      pure $ case manifestName manifest >>= either (const Nothing) Just . parsePackageId of
        Just (Registered _ name) -> name
        Just (LocalName name) -> name
        Nothing -> fallback

repositoryName :: Text -> Text
repositoryName url =
  let lastPart = last ("" : Text.splitOn "/" (Text.dropWhileEnd (== '/') url))
   in normalised (maybe lastPart id (Text.stripSuffix ".git" lastPart))

normalised :: Text -> Text
normalised raw =
  let lowered = Text.map (\c -> if c `elem` ['A' .. 'Z'] then toEnum (fromEnum c + 32) else c) raw
      mapped = Text.map (\c -> if c `elem` ['a' .. 'z'] || c `elem` ['0' .. '9'] then c else '-') lowered
      collapsed = Text.intercalate "-" (filter (not . Text.null) (Text.splitOn "-" mapped))
   in if validSegment collapsed then collapsed else "dependency"

quoted :: Text -> Text
quoted t = "\"" <> t <> "\""

plural :: Int -> Text -> Text
plural 1 word = "1 " <> word
plural n word = Text.pack (show n) <> " " <> word <> "s"

failWith :: String -> Text -> IO a
failWith command message = do
  hPutStrLn stderr ("pudu " <> command <> ": " <> Text.unpack message)
  exitFailure
