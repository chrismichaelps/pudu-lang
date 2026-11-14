{-| @Test.Backend.FloatNaturalSpec — bounded C naturals against exact Integer answers. -}
module Pudu.Backend.FloatNaturalSpec (floatNaturalProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Numeric (showHex)
import Pudu.Backend.Runtime.Float.Natural (floatNaturalRuntimeParts, floatNaturalRuntimeDependencies)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

floatNaturalProperties :: [(String, IO Property)]
floatNaturalProperties =
  [ ("native floating naturals match bounded Integer arithmetic", withCompiler testArithmetic)
  , ("native floating natural roots compile with exact prerequisites", withCompiler testRoots)
  ]

data NatCase = NatCase Char Integer Integer Integer Int deriving stock Show

modulus :: Integer
modulus = 2^(1280::Int)

cases :: [NatCase]
cases = constructors <> binaries <> small <> scaling <> digits
  where
    values = endpoints <> samples
    endpoints = [0,1,2,2^(31::Int),2^(32::Int)-1,2^(32::Int),2^(53::Int),2^(64::Int)-1,
      2^(64::Int),2^(1075::Int)-1,2^(1075::Int),2^(1127::Int),2^(1279::Int),modulus-1]
    samples = take 32 (drop 1 (iterate (\n -> (n*(2^(640::Int)+6364136223846793005)+2^(1278::Int)+1442695040888963407) `mod` modulus) 7))
    pairs = [(a,b) | a <- endpoints, b <- endpoints] <> zip samples (drop 9 (cycle samples)) <> [(a,b) | a <- values, b <- [1,10]]
    constructors = [NatCase 'w' a 0 shift alias | a <- [0,1,2,2^(31::Int),2^(32::Int)-1,2^(32::Int),2^(53::Int),2^(64::Int)-1]
      , shift <- [0,1,31,32,63,64,971,1023,1074,1075,1127,1215,1216,1217,1227,1228,1279,1280,2^(32::Int)-1], alias <- [0,1,2]]
    binaries = [NatCase op a b 0 alias | op <- "acs", (a,b) <- pairs, alias <- [0,1,2]]
    small = [NatCase 'm' a 0 factor alias | a <- values, factor <- [0,1,2,10,65535,2^(32::Int)-1], alias <- [0,1,2]]
    scaling = [NatCase 't' a 0 places alias | a <- values, places <- [0,1,10,308,323,385,386,2^(32::Int)-1], alias <- [0,1,2]]
    digits = [NatCase 'd' a b 0 alias | b <- values, quotient <- [0..10], remainder <- if b==0 then [0,1] else [0,b-1]
      , let a=quotient*b+remainder, a < modulus, alias <- [0,1,2]]

expected :: NatCase -> String
expected (NatCase op a b scalar alias) = unwords [show flag, show digit, show (limbs result), hex result]
  where
    before = case alias of 1 -> a; 2 -> b; _ -> 17
    bounded n | n >= 0 && n < modulus = Just n
              | otherwise = Nothing
    answer = case op of
      'w' | a == 0 -> Just 0
          | scalar >= 1280 -> Nothing
          | otherwise -> bounded (a*2^scalar)
      'a' -> bounded (a+b)
      's' -> bounded (a-b)
      'm' -> bounded (a*scalar)
      't' | a == 0 -> Just 0
          | scalar >= 386 -> Nothing
          | otherwise -> bounded (a*10^scalar)
      'd' | b == 0 || a `quot` b >= 10 -> Nothing
          | otherwise -> Just (a `rem` b)
      _ -> Nothing
    flag :: Int
    flag | op == 'c' = case compare a b of LT -> -1; EQ -> 0; GT -> 1
         | Just _ <- answer = 1
         | otherwise = 0
    result = maybe before id answer
    digit = if op == 'd' && flag == 1 then a `quot` b else 77
    limbs :: Integer -> Int
    limbs 0 = 0
    limbs n = 1 + limbs (n `quot` 2^(32::Int))

hex :: Integer -> String
hex value = let digits = showHex value "" in replicate (320-length digits) '0' <> digits

input :: NatCase -> String
input (NatCase op a b scalar alias) = unwords [[op],show scalar,show alias,hex a,hex b]

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "floating natural tests require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-float-naturals" (action cc)

execute :: FilePath -> FilePath -> [Text] -> [Text] -> String -> IO (Either String (ExitCode,String,String))
execute cc root roots body stdinText = do
  let closure = foldl' visit Set.empty roots
      runtime = concat [code | (name,code) <- floatNaturalRuntimeParts, Set.member name closure]
      path = root </> "natural.c"
      binary = root </> "natural"
  TextIO.writeFile path (Text.unlines (headers <> runtime <> body))
  (built, output, errors) <- readProcessWithExitCode cc
    ["-std=c11","-pedantic","-O2","-Wall","-Wextra","-Werror",path,"-o",binary] ""
  if built /= ExitSuccess || not (null output && null errors)
    then pure (Left (show built <> output <> errors))
    else Right <$> readProcessWithExitCode binary [] stdinText
  where
    visit found name | Set.member name found = found
                     | otherwise = foldl' visit (Set.insert name found) (floatNaturalRuntimeDependencies name)

headers :: [Text]
headers = ["#include <stddef.h>","#include <stdint.h>","#include <inttypes.h>","#include <stdio.h>"]

testArithmetic :: FilePath -> FilePath -> IO Property
testArithmetic cc root = do
  result <- execute cc root (map fst (drop 1 floatNaturalRuntimeParts)) arithmeticMain (unlines (map input cases))
  putStrLn ("[floating naturals] executed " <> show (length cases) <> " exact/alias/failure rows")
  pure $ case result of
    Left failure -> counterexample failure (False === True)
    Right (status,output,errors) -> conjoin
      ([status === ExitSuccess, errors === "", length (lines output) === length cases]
        <> zipWith (\(index,row) actual -> counterexample (show index <> ": " <> show row) (actual === expected row)) (zip [0::Int ..] cases) (lines output))

arithmeticMain :: [Text]
arithmeticMain =
  [ "static int read_nat(pudu_float_nat *out) {"
  , "  for(size_t i=PUDU_FLOAT_NAT_WORDS;i!=0;) { --i; if(scanf(\"%8\" SCNx32,&out->words[i])!=1) return 0; }"
  , "  out->length=PUDU_FLOAT_NAT_WORDS;"
  , "  while(out->length!=0 && out->words[out->length-1]==0) --out->length;", "  return 1;", "}"
  , "int main(void) { char op; uint32_t scalar; unsigned alias; int read;"
  , "  while((read=scanf(\" %c %\" SCNu32 \" %u\",&op,&scalar,&alias))==3) {"
  , "    pudu_float_nat a={0},b={0},saved={1,{17}}; unsigned digit=77; int flag;"
  , "    if(!read_nat(&a) || !read_nat(&b)) return 98;"
  , "    pudu_float_nat *out=alias==1 ? &a : alias==2 ? &b : &saved;"
  , "    switch(op) {"
  , "    case 'w': flag=pudu_float_nat_from_shift(out,(uint64_t)a.words[0]|((uint64_t)a.words[1]<<32),scalar); break;"
  , "    case 'c': flag=pudu_float_nat_compare(&a,&b); break;"
  , "    case 'a': flag=pudu_float_nat_add(out,&a,&b); break;"
  , "    case 's': flag=pudu_float_nat_sub(out,&a,&b); break;"
  , "    case 'm': flag=pudu_float_nat_multiply_small(out,&a,scalar); break;"
  , "    case 't': flag=pudu_float_nat_scale10(out,&a,scalar); break;"
  , "    case 'd': flag=pudu_float_nat_digit(out,&digit,&a,&b); break;"
  , "    default: return 97;", "    }"
  , "    printf(\"%d %u %zu \",flag,digit,out->length);"
  , "    for(size_t i=PUDU_FLOAT_NAT_WORDS;i!=0;) { --i; printf(\"%08\" PRIx32,i<out->length ? out->words[i] : UINT32_C(0)); }"
  , "    putchar('\\n');", "  }", "  return read==EOF ? 0 : 96;", "}" ]

testRoots :: FilePath -> FilePath -> IO Property
testRoots cc root = conjoin <$> traverse check
  [("float_nat_from_shift","pudu_float_nat_from_shift(&out,1,32) && out.length==2 && out.words[1]==1")
  ,("float_nat_compare","pudu_float_nat_compare(&a,&b)==1")
  ,("float_nat_add","pudu_float_nat_add(&out,&a,&b) && out.words[0]==9")
  ,("float_nat_sub","pudu_float_nat_sub(&out,&a,&b) && out.words[0]==5")
  ,("float_nat_multiply_small","pudu_float_nat_multiply_small(&out,&a,10) && out.words[0]==70")
  ,("float_nat_scale10","pudu_float_nat_scale10(&out,&a,3) && out.words[0]==7000")
  ,("float_nat_digit","pudu_float_nat_digit(&out,&digit,&a,&b) && out.words[0]==1 && digit==3")]
  where
    check (name,expression) = do
      result <- execute cc root [name]
        ["int main(void) { pudu_float_nat a={1,{7}},b={1,{2}},out={0}; unsigned digit=77;"
        ,"  (void)a; (void)b; (void)out; (void)digit;"
        ,"  return (" <> expression <> ") ? 0 : 99; }"] ""
      pure (counterexample (Text.unpack name <> ": " <> show result) (result === Right (ExitSuccess,"","")))
