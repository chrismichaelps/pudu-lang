{-| @Test.Backend.WideRuntimeSpec — actual selected wide runtime output and refusals. -}
module Pudu.Backend.WideRuntimeSpec (wideRuntimeProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Runtime (RuntimePart (..), runtimeParts)
import Pudu.Backend.Runtime.Integer (integerRuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Operations (wideOperationRuntimeParts)
import Pudu.Backend.Runtime.Integer.Wide.Display (wideDisplayRuntimeParts)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

wideRuntimeProperties :: [(String, IO Property)]
wideRuntimeProperties =
  [ ("native wide production runtime prints full values and clamps statuses", withCompiler testOutput)
  , ("native wide production helper closures and real refusals execute", withCompiler testHelpers)
  ]

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "wide runtime checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-wide-runtime" (action cc)

execute :: FilePath -> FilePath -> [Text] -> [Text] -> (ExitCode, String, String) -> IO Property
execute cc root roots body expected = do
  let source = root </> "runtime.c"
      binary = root </> "runtime"
  TextIO.writeFile source (Text.unlines (selected ("prelude":roots) <> body))
  (status, output, errors) <- readProcessWithExitCode cc
    ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", source, "-o", binary] ""
  if status /= ExitSuccess || not (null output && null errors)
    then pure (counterexample (show status <> output <> errors) (False === True))
    else do
      actual <- readProcessWithExitCode binary [] ""
      pure (counterexample (show actual) (actual === expected))

selected :: [Text] -> [Text]
selected roots = concat [runtimePartLines part | part <- runtimeParts, Set.member (runtimePartName part) closure]
  where
    closure = foldl' visit Set.empty roots
    visit found name | Set.member name found = found
                     | otherwise = foldl' visit (Set.insert name found) (integerRuntimeDependencies name)

modulus :: Integer
modulus = 2^(128::Int)

values :: [Integer]
values = [-modulus+1, -(modulus `div` 2), -1, 0, 1, 255, 256, 2^(64::Int), modulus `div` 2-1, modulus `div` 2, modulus-1]
  <> samples <> map negate samples
  where samples = take 32 (iterate (\n -> (n*47026247687942121848144207491837523525+1442695040888963407) `mod` modulus) 7)

number :: Show a => a -> Text
number = Text.pack . show

literal :: Integer -> Text
literal integer = "{{UINT64_C(" <> number (bits `mod` base) <> "),UINT64_C(" <> number (bits `div` base) <> ")}," <> (if integer<0 then "1" else "0") <> "}"
  where base = 2^(64::Int); bits = integer `mod` modulus

testOutput :: FilePath -> FilePath -> IO Property
testOutput cc root = execute cc root ["wide_print_int","wide_status"]
  (["static const struct { pudu_wide_int value; int status; } cases[] = {"]
   <> ["{" <> literal integer <> "," <> number (if integer==0 then 0 else max 1 (min 255 integer)) <> "}," | integer <- values]
   <> ["};", "int main(void) {"
      , "  for(size_t i=0;i<sizeof cases/sizeof cases[0];++i) {"
      , "    if(pudu_wide_status(cases[i].value)!=cases[i].status) return 99;"
      , "    pudu_wide_print_int(cases[i].value);", "  }"
      , "  pudu_wide_int zero={{0,0},1}; if(pudu_wide_status(zero)!=0) return 98;"
      , "  pudu_wide_print_int(zero); return 0; }"])
  (ExitSuccess, concatMap ((<> "\n") . show) values <> "0\n", "")

testHelpers :: FilePath -> FilePath -> IO Property
testHelpers cc root = do
  results <- traverse check calls
  refusal <- execute cc root ["wide_add","print_str"]
    ["static const pudu_site probe={\"probe.pudu\",1,1,\"E7005\",\"overflow probe\",NULL,\"wide\",0,1,0,1};"
    ,"int main(void) { pudu_print_str(\"before\",6);"
    ,"  (void)pudu_wide_add((pudu_wide_int)" <> literal (modulus `div` 2-1) <> ",(pudu_wide_int){{1,0},0},(pudu_wide_kind){1},&probe); return 0; }"]
    (ExitFailure 1,"before\n","error[E7005]: overflow probe\n  --> probe.pudu:1:1\n   |\n 1 | wide\n   | ^\n")
  pure $ conjoin (refusal : (Set.fromList (map (\(name,_,_) -> name) calls) === Set.fromList (map fst (wideOperationRuntimeParts <> wideDisplayRuntimeParts))) : results)
  where
    check (name,call,output) = counterexample (Text.unpack name) <$> execute cc root [name,"site"]
      ["int main(void) { const pudu_site site={\"runtime.pudu\",1,1,\"E7005\",\"unexpected failure\",NULL,\"\",0,0,0,0}; pudu_wide_int a={{1,0},0},b={{1,0},0}; pudu_wide_kind kind={1};"
      ,"  (void)site; (void)a; (void)b; (void)kind; (void)" <> call <> "; return 0; }"] (ExitSuccess,output,"")
    calls =
      [("wide_add_math","pudu_wide_add_math(a,b)","")
      ,("wide_multiply_math","pudu_wide_multiply_math(a,b)","")
      ,("wide_checked_result","pudu_wide_checked_result((pudu_wide_calculation){a,0},kind,&site)","")
      ,("wide_saturate_result","pudu_wide_saturate_result((pudu_wide_calculation){a,0},kind)","")]
      <> [("wide_"<>name,"pudu_wide_"<>name<>"(a,b,kind,&site)","") | name <- ["add","sub","mul"]]
      <> [("wide_div","pudu_wide_div(a,b,kind,&site,&site)","")
         ,("wide_rem","pudu_wide_rem(a,b,&site)","")
         ,("wide_neg","pudu_wide_neg(a,kind,&site)","")]
      <> [("wide_"<>name,"pudu_wide_"<>name<>"(a,b,kind)","") | name <- ["sat_add","sat_sub","sat_mul","wrap_add","wrap_sub","wrap_mul","bit_and","bit_or","bit_xor"]]
      <> [("wide_bit_not","pudu_wide_bit_not(a,kind)","")]
      <> [("wide_shift_"<>name,"pudu_wide_shift_"<>name<>"(a,(pudu_int){64,0},kind,&site,&site)","") | name <- ["left","right"]]
      <> [("wide_print_int","pudu_wide_print_int(a)","1\n"),("wide_status","pudu_wide_status(a)","")]
