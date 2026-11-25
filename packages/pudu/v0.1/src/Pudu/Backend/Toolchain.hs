{-| @Pudu.Backend.Toolchain — the host executable path of the native
    toolchain.

    It finds a C11 compiler, invokes it on generated source with a fixed flag
    policy through the shared bounded runner, and publishes the resulting
    executable with a same-filesystem rename. Every failure mode is a value the
    caller translates into an `E600x` diagnostic; nothing here throws for an
    expected condition.
-}
module Pudu.Backend.Toolchain
  ( ToolchainFailure (..)
  , ToolchainRequest (..)
  , compileNative
  , compilerFlags
  ) where

import Control.Concurrent (forkFinally)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (finally, mask)
import Control.Monad (void)
import qualified Data.ByteString as ByteString
import Data.List (isPrefixOf)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import Pudu.Backend.Runtime.Host.Compress (compressLibraryMarker)
import Pudu.Backend.Runtime.Host.Foreign (foreignLoaderMarker)
import Pudu.Backend.Runtime.Host.Tls (tlsLibraryMarker)
import Pudu.Backend.Toolchain.Cache (nativeKey, restoreNative, storeNative)
import Pudu.Backend.Toolchain.HostSources (withHostSourceArguments)
import Pudu.Backend.Toolchain.Process (ToolchainFailure (..), cleanup, problemText, runTool, timeoutSeconds, tryIO)
import Pudu.Backend.Toolchain.Split (SplitUnits (..), splitUnits)
import GHC.Conc (getNumProcessors)
import System.Directory (createDirectory, findExecutable, removeDirectoryRecursive, renameFile)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath (takeDirectory, takeFileName, (</>))
import Text.Read (readMaybe)
import System.IO (hClose, openTempFile)
import System.Info (os)
import System.Process (readProcessWithExitCode)

{-| @Backend.Toolchain.Request — the generated translation unit and where the
    executable must end up. -}
data ToolchainRequest = ToolchainRequest
  { toolchainSource :: !Text
  , toolchainOutput :: !FilePath
  }
  deriving stock (Eq, Show)

{-| Compile the generated C and publish the executable atomically. On success
    the captured compiler output is returned — empty when silent, the warnings
    when there are any — so a caller can assert the generated C is
    warning-free under the fixed policy. -}
compileNative :: ToolchainRequest -> IO (Either ToolchainFailure Text)
compileNative request = do
  compiler <- discoverCompiler
  case compiler of
    Left failure -> pure (Left failure)
    Right executable -> do
      libraries <- sourceLibraries (toolchainSource request)
      key <- nativeKey executable (compilerFlags <> linkerFlags <> libraries) (toolchainSource request)
      restored <- maybe (pure Nothing) (`restoreNative` output) key
      case restored of
        Just warnings -> pure (Right warnings)
        Nothing -> withTemporary executable libraries key

 where
  output = toolchainOutput request

  withTemporary executable libraries key = mask $ \restore -> do
    created <- tryIO (openTempFile (takeDirectory output) (takeFileName output <> ".pudu-tmp.c"))
    case created of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right (sourcePath, sourceHandle) -> do
        let executablePath = sourcePath <> ".out"
        outcome <-
          restore (do
             compiled <- runCompile executable libraries sourcePath sourceHandle executablePath
             case compiled of
               Left failure -> pure (Left failure)
               Right captured -> do
                 mapM_ (\found -> storeNative found executablePath captured) key
                 published <- tryIO (renameFile executablePath output)
                 pure $ case published of
                   Left problem -> Left (ToolchainPublishFailed (problemText problem))
                   Right () -> Right captured
          )
            `finally` (void (tryIO (hClose sourceHandle)) >> cleanup [sourcePath, executablePath])
        pure outcome

  runCompile executable libraries sourcePath sourceHandle executablePath = do
    written <- tryIO (do
      ByteString.hPut sourceHandle (Encoding.encodeUtf8 (toolchainSource request))
      hClose sourceHandle)
    case written of
      Left problem -> pure (Left (ToolchainPublishFailed (problemText problem)))
      Right () -> do
        seconds <- timeoutSeconds
        plan <- unitPlan executable (toolchainSource request)
        invoked <- tryIO $ withHostSourceArguments (toolchainSource request) $ \hostArguments -> case plan of
          Just (count, optimizing) | null hostArguments ->
            compileUnits executable libraries seconds count optimizing sourcePath executablePath
          _ -> runTool executable (compilerFlags <> ["-o", executablePath, sourcePath] <> linkerFlags <> libraries <> hostArguments) seconds
        pure $ case invoked of
          Left problem -> Left (ToolchainInvocation (problemText problem))
          Right result -> result

  -- The units compile at the same time beside the source, then link; the
  -- compilers' output is returned in unit order.
  compileUnits executable libraries seconds count optimizing sourcePath executablePath = do
    let directory = sourcePath <> ".units"
        units = splitUnits count (toolchainSource request)
        sources = ("unit_data.c", splitData units) : zip ["unit_" <> show index <> ".c" | index <- [0 :: Int ..]] (splitFunctions units)
        objects = [directory </> name <> ".o" | (name, _) <- sources]
        -- A library's header search flags reach every unit; its link flags
        -- reach only the link.
        searched = [flag | flag <- libraries, any (`isPrefixOf` flag) ["-I", "-D", "-isystem"]]
    (do
       createDirectory directory
       ByteString.writeFile (directory </> "unit.h") (Encoding.encodeUtf8 (splitHeader units))
       mapM_ (\(name, text) -> ByteString.writeFile (directory </> name) (Encoding.encodeUtf8 text)) sources
       compiled <- concurrently
         [ either (Left . ToolchainInvocation . problemText) id <$> tryIO
             (runTool executable (compilerFlags <> optimizing <> searched <> ["-c", directory </> name, "-o", object]) seconds)
         | ((name, _), object) <- zip sources objects ]
       case sequence compiled of
         Left failure -> pure (Left failure)
         Right outputs -> do
           linked <- runTool executable (["-O2"] <> optimizing <> ["-o", executablePath] <> objects <> linkerFlags <> libraries) seconds
           pure (fmap (Text.concat outputs <>) linked))
      `finally` void (tryIO (removeDirectoryRecursive directory))

{-| How many units a source compiles as, and the flags that let the link
    optimize across them; nothing for one unit. `PUDU_C_UNITS` sets the count
    for any source; otherwise a source past `splitThreshold` bytes splits one
    unit per processor when the compiler is one whose link optimizes across
    units, and a smaller source stays whole, where a split costs more than it
    saves. -}
unitPlan :: FilePath -> Text -> IO (Maybe (Int, [String]))
unitPlan executable source = do
  configured <- lookupEnv "PUDU_C_UNITS"
  -- A program that looks its own symbols up as it runs keeps one unit: the
  -- link would drop a function only such a lookup reaches.
  case configured >>= readMaybe of
    _ | foreignLoaderMarker `Text.isInfixOf` source -> pure Nothing
    Just count | count > 1 -> (\across -> Just (count, ["-flto=thin" | across])) <$> linkOptimizes executable
    Just _ -> pure Nothing
    Nothing
      | os == "mingw32" || Text.length source < splitThreshold -> pure Nothing
      | otherwise -> do
          across <- linkOptimizes executable
          processors <- getNumProcessors
          pure (if across && processors > 1 then Just (min 8 processors, ["-flto=thin"]) else Nothing)

{-| The source size, in characters, past which a compile splits. -}
splitThreshold :: Int
splitThreshold = 4000000

{-| Whether the compiler reports itself as clang, whose link optimizes across
    units with `-flto=thin`. -}
linkOptimizes :: FilePath -> IO Bool
linkOptimizes executable = do
  described <- tryIO (runTool executable ["--version"] 5)
  pure $ case described of
    Right (Right banner) -> "clang" `Text.isInfixOf` Text.toLower banner
    _ -> False

{-| Every compile at once, each answer in its place; a compile that stops
    with an exception answers it as a failed invocation. -}
concurrently :: [IO (Either ToolchainFailure Text)] -> IO [Either ToolchainFailure Text]
concurrently actions = do
  slots <- mapM (\action -> do
    slot <- newEmptyMVar
    _ <- forkFinally action (putMVar slot . either (Left . ToolchainInvocation . Text.pack . show) id)
    pure slot) actions
  mapM takeMVar slots

{-| `PUDU_CC` used as given when set, otherwise `cc` found on `PATH`. -}
discoverCompiler :: IO (Either ToolchainFailure FilePath)
discoverCompiler = do
  override <- lookupEnv "PUDU_CC"
  case override of
    Just value | not (null value) -> pure (Right value)
    _ -> do
      found <- findExecutable "cc"
      pure $ case found of
        Just path -> Right path
        Nothing -> Left (ToolchainNotFound "cc")

{-| The fixed flag policy every native compile uses, mobile targets included. -}
compilerFlags :: [String]
compilerFlags = ["-std=c11", "-O2", "-Wall", "-Wextra"]

{-| After the source, where a linker that reads left to right needs them: the
    math library and the thread library the host parts call. -}
linkerFlags :: [String]
linkerFlags
  | os == "mingw32" = []
  | otherwise = ["-lm", "-pthread"]

{-| The system libraries a program's own C asks for, each named by the line
    that includes its header. A program that never includes one links none.
    The TLS library's flags are the ones the machine's own package
    description gives, since its headers sit outside the default search path
    on some systems; a machine without that description gets the plain names. -}
sourceLibraries :: Text -> IO [String]
sourceLibraries source = do
  secured <- if tlsLibraryMarker `Text.isInfixOf` source then tlsLibraryFlags else pure []
  pure (["-lz" | compressLibraryMarker `Text.isInfixOf` source] <> secured
    -- A foreign block naming the C library reaches the program's own
    -- symbols; Linux exports them only when asked.
    <> concat [["-ldl", "-rdynamic"] | os == "linux", foreignLoaderMarker `Text.isInfixOf` source])

tlsLibraryFlags :: IO [String]
tlsLibraryFlags = do
  described <- tryIO (readProcessWithExitCode "pkg-config" ["--cflags", "--libs", "openssl"] "")
  pure $ case described of
    Right (ExitSuccess, flags, _) | not (null (words flags)) -> words flags
    _ -> ["-lssl", "-lcrypto"]
