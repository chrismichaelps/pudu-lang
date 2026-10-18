{-| @Test.Backend.BrokenPipeSpec — native continuation after a closed output pipe. -}
module Pudu.Backend.BrokenPipeSpec (brokenPipeProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Emit (emitProgram)
import Pudu.Compiler (CompileResult (..), runCompile)
import Pudu.Compiler.Frame (lowerFrames)
import Pudu.Compiler.Lower (LowerResult (..), lowerProgram)
import Pudu.Compiler.Lower.Types (nativeTypes)
import Pudu.Diagnostic (hasErrors)
import Pudu.Source (SourceName (..), newSource)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Info (os)
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

brokenPipeProperties :: [(String, IO Property)]
brokenPipeProperties = [("native closed pipes preserve continuation and diagnostic termination", testPipe)]

testPipe :: IO Property
testPipe
  | os == "mingw32" = putStrLn "[skip] closed-pipe launcher requires POSIX SIGPIPE; Windows evidence remains pending" >> pure (True === True)
  | otherwise = do
      configured <- lookupEnv "PUDU_CC"
      compiler <- findExecutable (maybe "cc" id configured)
      case compiler of
        Nothing -> pure (counterexample "closed-pipe regression requires a C11 compiler" (False === True))
        Just cc -> withSystemTempDirectory "pudu-closed-pipe" $ \root -> do
          launched <- compileC cc root "launcher" launcher
          case launched of
            Left failure -> pure (counterexample failure (False === True))
            Right runner -> conjoin <$> traverse (check cc root runner) cases
  where
    cases =
      [("continuation", "fn main() -> Int { print(\"x\")\n print(display(42))\n print(display(true))\n print(display(()))\n return 7 }", ExitFailure 7, "x\n42\ntrue\n()\n")
      ,("later failure", "fn main() -> Int { print(\"x\")\n return 1 / 0 }", ExitFailure 1, "x\n")
      ,("unit entry", "fn main() -> () { print(\"x\")\n () }", ExitSuccess, "x\n")]
    check cc root runner (label, body, expectedStatus, expectedOutput) = do
      source <- newSource (SourceName "Main.pudu") ("module Main\n" <> body <> "\n")
      checked <- runCompile source
      case (hasErrors (compileDiagnostics checked), compileModule checked) of
        (False, Just parsed) -> case lowerProgram "main" (nativeTypes (compileTypes checked) (compileSchemes checked)) parsed of
          Lowered core -> case lowerFrames core >>= emitProgram "pipe-test" [source] of
            Left failure -> pure (counterexample (show failure) (False === True))
            Right emitted -> do
              compiled <- compileC cc root "program" emitted
              case compiled of
                Left failure -> pure (counterexample failure (False === True))
                Right binary -> do
                  ordinary@(status, output, errors) <- readProcessWithExitCode binary [] ""
                  outcomes <- traverse (\(channel, inherited) -> do
                    closed <- readProcessWithExitCode runner [binary, channel, inherited] ""
                    let failedReport = not (null errors) && channel /= "1"
                        pipeStatus = if failedReport && inherited /= "blocked" then ExitFailure (-13) else expectedStatus
                        pipeOutput = if channel == "2" then expectedOutput else ""
                        pipeErrors = if channel == "1" then errors else ""
                    pure (counterexample (label <> ": " <> channel <> "/" <> inherited <> ": normal=" <> show ordinary <> "; closed=" <> show closed)
                      (closed === (pipeStatus, pipeOutput, pipeErrors))))
                    [(channel, inherited) | channel <- ["1", "2", "3"], inherited <- ["default", "ignored", "blocked"]]
                  pure $ conjoin
                    ([ status === expectedStatus, output === expectedOutput
                     , if expectedStatus == ExitFailure 1 then counterexample "later E7004 was lost" ("error[E7004]" `Text.isInfixOf` Text.pack errors) else errors === ""
                     ] <> outcomes)
          other -> pure (counterexample (show other) (False === True))
        _ -> pure (counterexample (show (compileDiagnostics checked)) (False === True))

compileC :: FilePath -> FilePath -> String -> Text -> IO (Either String FilePath)
compileC cc root name sourceText = do
  let source = root </> name <> ".c"
      binary = root </> name
  TextIO.writeFile source sourceText
  (status, output, errors) <- readProcessWithExitCode cc
    ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", source, "-o", binary] ""
  pure $ if status == ExitSuccess && null output && null errors
    then Right binary else Left (show status <> output <> errors)

launcher :: Text
launcher = Text.unlines
  [ "#define _POSIX_C_SOURCE 200809L"
  , "#include <signal.h>", "#include <unistd.h>"
  , "int main(int argc, char **argv) {"
  , "  int descriptors[2]; char *arguments[2];"
  , "  if(argc != 4 || pipe(descriptors) != 0) return 99;"
  , "  if(close(descriptors[0]) != 0) return 98;"
  , "  if(argv[2][0] != '2' && dup2(descriptors[1],1) < 0) return 98;"
  , "  if(argv[2][0] != '1' && dup2(descriptors[1],2) < 0) return 98;"
  , "  if(close(descriptors[1]) != 0 || signal(SIGPIPE,argv[3][0] == 'i' ? SIG_IGN : SIG_DFL) == SIG_ERR) return 97;"
  , "  if(argv[3][0] == 'b') {"
  , "    sigset_t mask; if(sigemptyset(&mask) || sigaddset(&mask,SIGPIPE) || sigprocmask(SIG_BLOCK,&mask,0)) return 95;"
  , "  }"
  , "  arguments[0]=argv[1]; arguments[1]=0; execv(argv[1], arguments); return 96;"
  , "}"
  ]
