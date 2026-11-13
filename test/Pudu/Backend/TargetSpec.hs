{-| @Test.Backend.TargetSpec — mobile target selection, SDK diagnostics, and
    the entry and architecture of real Apple SDK products. -}
module Pudu.Backend.TargetSpec (backendTargetProperties) where

import Control.Exception (bracket)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (EmittedUnit (..), EntryForm (..), emitUnit)
import Pudu.Backend.Target (NativeTarget, TargetRefusal (..), nativeTargetNamed, nativeTargetNames, targetRefusals)
import Pudu.Backend.Toolchain (ToolchainFailure (..))
import Pudu.Backend.Toolchain.Library (LibraryProducts (..), LibraryRequest (..), compileLibrary)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram, programNativeModules)
import Pudu.Compiler.Program (compileProgram, programDiagnostics, programSources)
import Pudu.Version (versionText)
import System.Directory (findExecutable, getPermissions, listDirectory, setOwnerExecutable, setPermissions)
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Info (arch, os)
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, once, property, (===))

backendTargetProperties :: [(String, IO Property)]
backendTargetProperties =
  [ ("mobile targets select library paths and refuse escapes", pure (once targetPaths))
  , ("mobile entry emits a host function and refuses desktop runtime parts", once <$> entryForms)
  , ("mobile SDK discovery diagnoses absence without publishing", once <$> sdkFailures)
  , ("mobile Apple SDK builds export only the host entry on both slices", once <$> appleArchives)
  ]

targetPaths :: Property
targetPaths = withTarget "ios-simulator-arm64" $ \ios ->
  withTarget "android-arm64" $ \android ->
    conjoin
      [ nativeTargetNames === ["android-arm64", "android-x86_64", "ios-arm64", "ios-simulator-arm64"]
      , nativeTargetNamed "linux-musl-x86_64" === Nothing
      , nativeTargetNamed "ios" === Nothing
      , targetRefusals ios Set.empty (unversioned ["c", "sqlite3", framework, bundled]) === []
      , map refusedConstruct (targetRefusals ios Set.empty [("sqlite3", Just "../../external")]) === [label "sqlite3"]
      , refused ios [outside, outside, traversal] === [label outside, label traversal]
      , refused android ["sqlite3", framework, bundled] === [label framework, label bundled]
      ]
 where
  framework = "/System/Library/Frameworks/Foo.framework/Foo"
  bundled = "@rpath/Foo.framework/Foo"
  outside = "/tmp/libfoo.dylib"
  traversal = "@executable_path/../../libfoo.dylib"
  label library = "the foreign library \"" <> library <> "\""
  unversioned = map (, Nothing)
  refused target = map refusedConstruct . targetRefusals target Set.empty . unversioned

withTarget :: Text -> (NativeTarget -> Property) -> Property
withTarget name test = maybe (counterexample ("missing target " <> show name) False) test (nativeTargetNamed name)

entryForms :: IO Property
entryForms = withSystemTempDirectory "pudu-mobile-entry" $ \root -> do
  let path = root </> "Main.pudu"
  TextIO.writeFile path "module Main\n\nfn main() -> Int {\n  print(\"hello\")\n  0\n}"
  mobile <- emitFile EmbeddedEntry path
  desktop <- emitFile ExecutableEntry path
  TextIO.writeFile path "module Main\n\nfn main() -> Int {\n  print(show(runProgram(\"/bin/sh\", [], \"\")))\n  0\n}"
  child <- emitFile EmbeddedEntry path
  pure $ withTarget "ios-simulator-arm64" $ \target -> case (mobile, desktop, child) of
    (Right library, Right executable, Right children) ->
      conjoin
        [ Text.isInfixOf "int pudu_program_run(" (emittedSource library) === True
        , Text.isInfixOf "int main(" (emittedSource library) === False
        , Text.isInfixOf "int main(" (emittedSource executable) === True
        , targetRefusals target (emittedParts library) (emittedLibraries library) === []
        , map refusedConstruct (targetRefusals target (emittedParts children) (emittedLibraries children)) === ["child programs"]
        ]
    other -> counterexample (show other) False

emitFile :: EntryForm -> FilePath -> IO (Either String EmittedUnit)
emitFile form path = do
  program <- compileProgram path
  pure $ case programNativeModules program of
    Nothing -> Left (show (programDiagnostics program))
    Just modules -> case lowerProgram "main" modules of
      LowerRefused refusals -> Left (show refusals)
      Lowered core ->
        either (Left . show) Right (lowerFrames core >>= emitUnit form versionText (programSources program))

sdkFailures :: IO Property
sdkFailures = withSystemTempDirectory "pudu-mobile-sdk" $ \root ->
  case nativeTargetNamed "ios-simulator-arm64" of
    Nothing -> pure (property False)
    Just target -> do
      let fake = root </> "fake-xcrun"
          request = LibraryRequest "" (root </> "libMain.a") target
      TextIO.writeFile fake "#!/bin/sh\nprintf 'SDK is absent\\n' >&2\nexit 1\n"
      permissions <- getPermissions fake
      setPermissions fake (setOwnerExecutable True permissions)
      missing <- withEnvironment "PATH" (Just root) $
        withEnvironment "PUDU_XCRUN" Nothing (compileLibrary request)
      rejected <- withEnvironment "PUDU_XCRUN" (Just fake) (compileLibrary request)
      collision <- compileLibrary request{libraryOutput = root </> "pudu_program.h"}
      files <- listDirectory root
      pure $ conjoin
        [ missing === Left (ToolchainSdkMissing "ios-simulator-arm64" "xcrun")
        , case rejected of
            Left (ToolchainSdkMissing name detail) ->
              conjoin [name === "ios-simulator-arm64", Text.isInfixOf "SDK is absent" detail === True]
            other -> counterexample (show other) False
        , case collision of
            Left (ToolchainPublishFailed _) -> property True
            other -> counterexample (show other) False
        , files === ["fake-xcrun"]
        ]

appleArchives :: IO Property
appleArchives
  | os /= "darwin" || arch /= "aarch64" = pure (property True)
  | otherwise = do
      xcrun <- findExecutable "xcrun"
      case xcrun of
        Nothing -> pure (property True)
        Just executable -> conjoin <$> traverse (checkAppleArchive executable)
          [("ios-arm64", "iphoneos", "2"), ("ios-simulator-arm64", "iphonesimulator", "7")]

checkAppleArchive :: FilePath -> (Text, String, String) -> IO Property
checkAppleArchive xcrun (name, sdk, platform) = do
  (available, _, _) <- readProcessWithExitCode xcrun ["--sdk", sdk, "--show-sdk-path"] ""
  case (available, nativeTargetNamed name) of
    (ExitSuccess, Just target) -> withSystemTempDirectory "pudu-mobile-archive" $ \root -> do
      let path = root </> "Main.pudu"
          archive = root </> "libMain.a"
      TextIO.writeFile path "module Main\n\nfn main() -> Int {\n  print(\"hello\")\n  0\n}"
      emitted <- emitFile EmbeddedEntry path
      case emitted of
        Left problem -> pure (counterexample problem False)
        Right unit -> do
          built <- compileLibrary (LibraryRequest (emittedSource unit) archive target)
          case built of
            Left problem -> pure (counterexample (show problem) False)
            Right products -> do
              header <- TextIO.readFile (libraryHeader products)
              (nmStatus, symbols, nmError) <- readProcessWithExitCode xcrun ["nm", "-gjU", archive] ""
              (otoolStatus, info, otoolError) <- readProcessWithExitCode xcrun ["otool", "-l", archive] ""
              pure $ conjoin
                [ libraryWarnings products === ""
                , Text.isInfixOf "int pudu_program_run(" header === True
                , counterexample nmError (nmStatus === ExitSuccess)
                , filter ("_" `Text.isPrefixOf`) (Text.lines (Text.pack symbols)) === ["_pudu_program_run"]
                , counterexample otoolError (otoolStatus === ExitSuccess)
                , counterexample info (any ((== ["platform", platform]) . words) (lines info) === True)
                ]
    _ -> putStrLn ("SKIP Apple archive: " <> sdk <> " SDK unavailable") >> pure (property True)

withEnvironment :: String -> Maybe String -> IO a -> IO a
withEnvironment name value action =
  bracket (lookupEnv name) (set name) (const (set name value >> action))
 where
  set key = maybe (unsetEnv key) (setEnv key)
