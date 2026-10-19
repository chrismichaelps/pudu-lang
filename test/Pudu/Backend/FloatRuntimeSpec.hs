{-| @Test.Backend.FloatRuntimeSpec — selected floating runtime and observable IO. -}
module Pudu.Backend.FloatRuntimeSpec (floatRuntimeProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Word (Word64)
import GHC.Float (castWord64ToDouble)
import Numeric (showHex)
import Pudu.Backend.Runtime (RuntimePart (..), runtimeParts)
import Pudu.Backend.Runtime.Dependencies (runtimeDependencies)
import Pudu.Backend.Runtime.Text (textRuntimeParts)
import Pudu.Backend.Runtime.Text.Methods (textMethodRuntimeParts)
import Pudu.Backend.Runtime.Float (floatRuntimeParts)
import Pudu.Backend.Runtime.Integer (integerRuntimeDependencies)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.Info (os)
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

floatRuntimeProperties :: [(String, IO Property)]
floatRuntimeProperties =
  [ ("native floating runtime prints exact bytes through production selection", withCompiler testOutput)
  , ("native floating runtime executes minimal production roots", withCompiler testRoots)
  , ("native floating runtime preserves one-line IO failure continuation", withCompiler testWrites)
  , ("native floating runtime preserves closed-pipe and later diagnostic policy", testPipes)
  ]

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "floating runtime tests require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-float-runtime" (action cc)

closure :: [Text] -> Set.Set Text
closure = foldl' visit Set.empty
 where
  visit seen name | Set.member name seen = seen
                  | otherwise = foldl' visit (Set.insert name seen) (runtimeDependencies name)

selected :: [Text] -> [Text]
selected roots = concat [runtimePartLines part | part <- runtimeParts, Set.member (runtimePartName part) (closure roots)]

compileText :: FilePath -> FilePath -> String -> Text -> IO (Either String FilePath)
compileText cc root name contents = do
  let source=root </> name<>".c"; binary=root </> name
  TextIO.writeFile source contents
  (status,output,errors) <- readProcessWithExitCode cc
    ["-std=c11","-pedantic","-O2","-Wall","-Wextra","-Werror",source,"-o",binary] ""
  pure $ if status==ExitSuccess && null output && null errors then Right binary else Left (show status<>output<>errors)

compileRuntime :: FilePath -> FilePath -> String -> [Text] -> [Text] -> [Text] -> IO (Either String FilePath)
compileRuntime cc root name prefix roots body = compileText cc root name
  (Text.unlines (selected ["prelude"] <> prefix <> selected roots <> body))

execute :: FilePath -> FilePath -> [Text] -> [Text] -> [Text] -> (ExitCode,String,String) -> IO Property
execute cc root prefix roots body expected = do
  built <- compileRuntime cc root "runtime" prefix roots body
  case built of
    Left failure -> pure (counterexample failure (False === True))
    Right binary -> do
      actual <- readProcessWithExitCode binary [] ""
      pure (counterexample (show actual) (actual === expected))

literal :: Word64 -> Text
literal bits = "UINT64_C(0x"<>Text.pack (showHex bits "")<>")"

values :: [Word64]
values = Set.toAscList (Set.fromList
  ([0,1,0x000fffffffffffff,0x0010000000000000,0x3fb999999999999a,0x3fb99999a0000000
   ,0x416312cfe0000000,0x416312d000000000,0x44b52d02c7e14af6,0x36a0000000000000,0x47efffffe0000000
   ,0x7fefffffffffffff,0x7ff0000000000000,0x7ff0000000000001,0x7ff8000000000000
   ,0x8000000000000000,0xfff0000000000000,0xfff8000000000001]
   <> take 1024 (iterate (\n -> n*6364136223846793005+1442695040888963407) 511)))

testOutput :: FilePath -> FilePath -> IO Property
testOutput cc root = do
  output <- execute cc root [] ["print_float","process_io"]
    (["static const uint64_t values[]={"]<>map (<> ",") (map literal values)<>
     ["};","int main(void) { pudu_prepare_io();"
     ,"  for(size_t i=0;i<sizeof values/sizeof values[0];++i) pudu_print_float(values[i]);"
     ,"  return 0; }"])
    (ExitSuccess,concatMap ((<> "\n") . show . castWord64ToDouble) values,"")
  notice <- TextIO.readFile "packages/pudu/v0.1/THIRD_PARTY_NOTICES"
  putStrLn ("[floating runtime] printed "<>show (length values)<>" raw encodings")
  let names=map runtimePartName runtimeParts; known=Set.fromList names
      floating=map fst floatRuntimeParts
      textual=map fst (textRuntimeParts <> textMethodRuntimeParts)
      before name dependency = case (lookup dependency (zip names [0::Int ..]),lookup name (zip names [0::Int ..])) of
        (Just a,Just b) -> a<b
        _ -> False
  pure $ conjoin ([output,length names === Set.size known
    ,counterexample "selected output lost its notice" (notice `Text.isInfixOf` Text.unlines (selected ["print_float"]) === True)
    ,counterexample "bit-only output selected host arithmetic" (Set.member "float_target" (closure ["print_float"]) === False)]
    <> [counterexample (Text.unpack name) (Set.member name known === True) | name <- floating]
    <> [counterexample (show (name,dependency)) (before name dependency === True) | name <- floating, dependency <- runtimeDependencies name]
    <> [counterexample (Text.unpack name) (runtimeDependencies name === integerRuntimeDependencies name) | name <- names, name `notElem` floating, name `notElem` textual])

testRoots :: FilePath -> FilePath -> IO Property
testRoots cc root = conjoin <$> traverse check roots
 where
  one=literal 0x3ff0000000000000; two=literal 0x4000000000000000
  roots = [("float_target","return 0;","")
    ,("float_decode","return pudu_float_decode("<>one<>")==1.0 ? 0 : 99;","")
    ,("float_encode","return pudu_float_encode(1.0)=="<>one<>" ? 0 : 99;","")
    ,("float_normalize","return pudu_float_normalize(1.0,1)=="<>one<>" ? 0 : 99;","")
    ,("float_neg","return pudu_float_neg(0)=="<>literal 0x8000000000000000<>" ? 0 : 99;","")
    ,("float_require","pudu_float_require(1); return 0;","")
    ,("float_decimal","pudu_float_digits d=pudu_float_decimal("<>one<>"); return d.length==1 && d.digits[0]=='1' && d.exponent==1 ? 0 : 99;","")
    ,("float_format","char out[32]; return pudu_format_float64("<>one<>",out)==3 && memcmp(out,\"1.0\",3)==0 ? 0 : 99;","")
    ,("print_float","pudu_print_float("<>one<>"); return 0;","1.0\n")]
    <> [(name,"return pudu_"<>name<>"("<>one<>","<>one<>",1)=="<>answer<>" ? 0 : 99;","")
      | (name,answer) <- [("float_add",two),("float_sub","0"),("float_mul",one),("float_div",one)]]
    <> [(name,"return pudu_"<>name<>"("<>one<>","<>two<>")=="<>answer<>" ? 0 : 99;","")
      | (name,answer) <- [("float_eq","0"),("float_ne","1"),("float_lt","1"),("float_le","1"),("float_gt","0"),("float_ge","0")]]
  check (name,body,output) = counterexample (Text.unpack name) <$> execute cc root [] [name]
    ["int main(void) { "<>body<>" }"] (ExitSuccess,output,"")

testWrites :: FilePath -> FilePath -> IO Property
testWrites cc root = execute cc root
  ["static int write_mode,flush_failure,writes,flushes,invalid; static size_t submitted; static char captured[32];"
  ,"static size_t probe_write(const void *bytes,size_t size,size_t count,FILE *stream) {"
  ,"  ++writes; if(size!=1 || count>sizeof captured || stream!=stdout) { invalid=1; return 0; }"
  ,"  memcpy(captured,bytes,count); submitted=count;"
  ,"  return write_mode==0 ? count : (write_mode==1 ? 0 : count-1);", "}"
  ,"static int probe_flush(FILE *stream) { ++flushes; if(stream!=stdout) invalid=1; return flush_failure ? EOF : 0; }"
  ,"#define fwrite probe_write", "#define fflush probe_flush"] ["print_float"]
  ["int main(void) { const char expected[]=\"9.999999999999999e22\\n\";"
  ,"  for(write_mode=0;write_mode<3;++write_mode) for(flush_failure=0;flush_failure<2;++flush_failure) {"
  ,"    writes=flushes=invalid=0; submitted=0; memset(captured,'~',sizeof captured);"
  ,"    pudu_print_float(UINT64_C(0x44b52d02c7e14af6));"
  ,"    if(writes!=1 || flushes!=1 || invalid || submitted!=sizeof expected-1 || memcmp(captured,expected,submitted)!=0) return 99;"
  ,"  }", "  return 7;", "}"] (ExitFailure 7,"","")

testPipes :: IO Property
testPipes
  | os=="mingw32" = putStrLn "[skip] POSIX floating pipe launcher; Windows pipe evidence pending" >> pure (True === True)
  | otherwise = withCompiler $ \cc root -> do
      launched <- compileText cc root "launcher" launcher
      case launched of
        Left failure -> pure (counterexample failure (False === True))
        Right runner -> conjoin <$> traverse (check cc root runner) [False,True]
 where
  normalOutput="0.10000000149011612\n-0.0\n"
  diagnostic="error[E7004]: float probe\n  --> runtime.pudu:1:1\n"
  check cc root runner fatal = do
    built <- compileRuntime cc root "pipes" [] (["print_float","process_io"]<>["fail" | fatal])
      (["static const pudu_site probe={\"runtime.pudu\",1,1,\"E7004\",\"float probe\",NULL,\"\",0,0,0,0};" | fatal]<>
       ["int main(void) { pudu_prepare_io(); pudu_print_float(UINT64_C(0x3fb99999a0000000));"
       ,"  pudu_print_float(UINT64_C(0x8000000000000000));"
       ,if fatal then "  pudu_fail(&probe); return 0; }" else "  return 7; }"])
    case built of
      Left failure -> pure (counterexample failure (False === True))
      Right binary -> do
        ordinary <- readProcessWithExitCode binary [] ""
        outcomes <- traverse (\(channel,inherited) -> do
          actual <- readProcessWithExitCode runner [binary,channel,inherited] ""
          let status | fatal && channel/="1" && inherited/="blocked" = ExitFailure (-13)
                     | fatal = ExitFailure 1
                     | otherwise = ExitFailure 7
              output = if channel=="2" then normalOutput else ""
              errors = if fatal && channel=="1" then diagnostic else ""
          pure (counterexample (show (fatal,channel,inherited,actual)) (actual === (status,output,errors))))
          [(channel,inherited) | channel <- ["1","2","3"], inherited <- ["default","ignored","blocked"]]
        pure (conjoin ((ordinary === (if fatal then ExitFailure 1 else ExitFailure 7,normalOutput,if fatal then diagnostic else "")):outcomes))

launcher :: Text
launcher = Text.unlines
  ["#define _POSIX_C_SOURCE 200809L", "#include <signal.h>", "#include <unistd.h>"
  ,"int main(int argc,char **argv) { int descriptors[2]; char *arguments[2];"
  ,"  if(argc!=4 || pipe(descriptors)!=0) return 99;"
  ,"  if(close(descriptors[0])!=0) return 98;"
  ,"  if(argv[2][0]!='2' && dup2(descriptors[1],1)<0) return 98;"
  ,"  if(argv[2][0]!='1' && dup2(descriptors[1],2)<0) return 98;"
  ,"  if(close(descriptors[1])!=0 || signal(SIGPIPE,argv[3][0]=='i' ? SIG_IGN : SIG_DFL)==SIG_ERR) return 97;"
  ,"  if(argv[3][0]=='b') { sigset_t mask; if(sigemptyset(&mask) || sigaddset(&mask,SIGPIPE) || sigprocmask(SIG_BLOCK,&mask,0)) return 96; }"
  ,"  arguments[0]=argv[1]; arguments[1]=0; execv(argv[1],arguments); return 95;", "}"]
