{-| @Test.Backend.ToolchainSpec — bounded compiler lifetime, including hostile
    descendants and asynchronous cancellation, without a real C compiler. -}
module Pudu.Backend.ToolchainSpec (backendToolchainProperties) where

import Control.Concurrent (forkFinally, killThread, newEmptyMVar, putMVar, takeMVar, threadDelay)
import Control.Exception (AsyncException (ThreadKilled), bracket, finally, fromException)
import Control.Monad (unless)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Toolchain (ToolchainFailure (..), ToolchainRequest (..), compileNative)
import System.Directory
  ( doesFileExist
  , getPermissions
  , listDirectory
  , setOwnerExecutable
  , setPermissions
  )
import System.Environment (lookupEnv, setEnv, unsetEnv)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Timeout (timeout)
import Test.QuickCheck (Property, conjoin, counterexample, property, (===))

backendToolchainProperties :: [(String, IO Property)]
backendToolchainProperties =
  [ ("native timeout kills a compiler that ignores TERM", testIgnoresTerm)
  , ("native timeout includes pipes retained after compiler exit", testInheritedPipes)
  , ("native cancellation cleans up and preserves the target", testCancellation)
  ]

testIgnoresTerm :: IO Property
testIgnoresTerm = testDeadline "trap '' TERM\nwhile :; do sleep 1; done\n"

testInheritedPipes :: IO Property
testInheritedPipes = testDeadline "sleep 30 &\nexit 0\n"

testDeadline :: Text -> IO Property
testDeadline body = withCompiler body $ \root request -> do
  completed <- timeout watchdogMicros (compileNative request)
  intact <- preservedTarget root
  clean <- cleanedTemporaries root
  pure $ conjoin
    [ counterexample ("deadline result: " <> show completed)
        (completed === Just (Left (ToolchainTimedOut 1)))
    , intact
    , clean
    ]

testCancellation :: IO Property
testCancellation = withCompiler
  "trap '' TERM\nprintf ready > \"$PUDU_TOOLCHAIN_READY\"\nwhile :; do sleep 1; done\n" $
  \root request -> do
    done <- newEmptyMVar
    worker <- forkFinally (compileNative request) (putMVar done)
    let cancel = killThread worker
        run = do
          ready <- timeout watchdogMicros (waitForFile (root </> "ready"))
          cancelled <- timeout watchdogMicros (cancel >> takeMVar done)
          intact <- preservedTarget root
          clean <- cleanedTemporaries root
          let propagated = case cancelled of
                Just (Left exception) -> fromException exception == Just ThreadKilled
                _ -> False
          pure $ conjoin
            [ counterexample "compiler never reached its readiness marker" (ready === Just ())
            , counterexample ("cancellation result: " <> show cancelled) (property propagated)
            , intact
            , clean
            ]
    run `finally` cancel

-- The watchdog covers the configured deadline plus every bounded cleanup step.
watchdogMicros :: Int
watchdogMicros = 8000000

waitForFile :: FilePath -> IO ()
waitForFile path = do
  found <- doesFileExist path
  unless found (threadDelay 10000 >> waitForFile path)

withCompiler :: Text -> (FilePath -> ToolchainRequest -> IO Property) -> IO Property
withCompiler body action = do
  shellAvailable <- doesFileExist "/bin/sh"
  if not shellAvailable
    then do
      putStrLn "[skip] /bin/sh unavailable; adversarial native toolchain checks skipped"
      pure (property True)
    else withSystemTempDirectory "pudu-toolchain-lifetime" $ \root -> do
      let script = root </> "compiler"
          output = root </> "out"
          request = ToolchainRequest "int main(void) { return 0; }" output
      TextIO.writeFile script (scriptPrefix <> body)
      permissions <- getPermissions script
      setPermissions script (setOwnerExecutable True permissions)
      TextIO.writeFile output "previous executable"
      withEnvironment
        [ ("PUDU_CC", script)
        , ("PUDU_CC_TIMEOUT", "1")
        , ("PUDU_TOOLCHAIN_READY", root </> "ready")
        ]
        (action root request)

-- Stage a partial artifact before failing, exercising atomic publication too.
scriptPrefix :: Text
scriptPrefix = Text.unlines
  [ "#!/bin/sh"
  , "while [ \"$#\" -gt 0 ]; do"
  , "  if [ \"$1\" = -o ]; then"
  , "    shift"
  , "    printf partial > \"$1\""
  , "    break"
  , "  fi"
  , "  shift"
  , "done"
  ]

preservedTarget :: FilePath -> IO Property
preservedTarget root = do
  contents <- TextIO.readFile (root </> "out")
  pure (counterexample "existing target was replaced" (contents === "previous executable"))

cleanedTemporaries :: FilePath -> IO Property
cleanedTemporaries root = do
  files <- listDirectory root
  let leaked = filter (Text.isInfixOf ".pudu-tmp" . Text.pack) files
  pure (counterexample ("toolchain temporaries leaked: " <> show leaked) (leaked === []))

withEnvironment :: [(String, String)] -> IO a -> IO a
withEnvironment changes action = bracket acquire release (const action)
 where
  acquire = do
    saved <- mapM (\(name, _) -> (,) name <$> lookupEnv name) changes
    mapM_ (uncurry setEnv) changes
    pure saved
  release = mapM_ (\(name, value) -> maybe (unsetEnv name) (setEnv name) value)
