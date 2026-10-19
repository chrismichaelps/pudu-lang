{-| @Test.Backend.FloatValueSpec — raw floating results held to the evaluator. -}
module Pudu.Backend.FloatValueSpec (floatValueProperties) where

import Data.Bits ((.|.), shiftL)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Word (Word32, Word64)
import GHC.Float (castDoubleToWord64, castWord64ToDouble, castWord32ToFloat, float2Double)
import Numeric (showHex)
import Pudu.Backend.Runtime.Float.Value (floatValueRuntimeParts, floatValueRuntimeDependencies)
import Pudu.FloatLiteral (FloatWidth (..), normalizeFloat)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

floatValueProperties :: [(String, IO Property)]
floatValueProperties =
  [ ("native floating values match evaluator bits and predicates", withCompiler testValues)
  , ("native floating values compile every exact helper closure", withCompiler testRoots)
  , ("native floating values refuse unsafe arithmetic policies", withCompiler testPolicies)
  ]

edges :: [Word64]
edges = [sign .|. bits | sign <- [0,0x8000000000000000]
  , bits <- [0,1,0x000fffffffffffff,0x0010000000000000,0x3ff0000000000000
    ,0x3ff0000002000000,0x3feffffffc000000,0x7fefffffffffffff
    ,0x7ff0000000000000,0x7ff0000000000001,0x7ff8000000000000,0x7fffffffffffffff]]

patterns :: [Word64]
patterns = Set.toAscList (Set.fromList (edges <> fields <> midpoints <> samples))
 where
  fields = [sign .|. shiftL field 52 .|. fraction | sign <- [0,0x8000000000000000]
    , field <- [0..2047], fraction <- [0,1,2^(51::Int),2^(52::Int)-1]]
  midpoints = [sign .|. (bits+delta) | field <- [0..254::Word32], fraction <- [0,1,0x3fffff,0x7ffffe]
    , let lower=shiftL field 23 .|. fraction
          widen = float2Double . castWord32ToFloat
          bits=castDoubleToWord64 ((widen lower+widen (lower+1))/2)
    , delta <- [0,1,maxBound], sign <- [0,0x8000000000000000]]

samples :: [Word64]
samples = take 4096 (iterate (\n -> n*6364136223846793005+1442695040888963407) 510)

rows :: [(FloatWidth, Word64, Word64)]
rows = [(width,a,b) | width <- [Float32Width,Float64Width]
  , (a,b) <- [(x,y) | x <- edges, y <- edges] <> zip patterns (cycle samples)]

hex :: Word64 -> String
hex value = showHex value ""

expected :: (FloatWidth, Word64, Word64) -> String
expected (width,a,b) = unwords (map hex numbers <> map (\flag -> if flag then "1" else "0") flags)
 where
  norm = oracleNormalize width
  x = norm (castWord64ToDouble a); y = norm (castWord64ToDouble b)
  encode = castDoubleToWord64
  numbers = [a,encode (norm (castWord64ToDouble a))]
    <> map (encode . norm) [x+y,x-y,x*y,x/y]
    <> [encode (negate x),encode (norm (norm (x*y)-1))]
  flags = [x==y,x/=y,x<y,x<=y,x>y,x>=y]

-- GHC 9.14.1 folds constant Float32 conversions differently from runtime values.
{-# NOINLINE oracleNormalize #-}
oracleNormalize :: FloatWidth -> Double -> Double
oracleNormalize = normalizeFloat

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "floating value tests require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-float-values" (action cc)

selected :: [Text] -> [Text]
selected roots = concat [code | (name,code) <- floatValueRuntimeParts, Set.member name closure]
 where
  closure = foldl' visit Set.empty roots
  visit found name | Set.member name found = found
                   | otherwise = foldl' visit (Set.insert name found) (floatValueRuntimeDependencies name)

build :: FilePath -> FilePath -> [String] -> [Text] -> [Text] -> IO (ExitCode,String,String)
build cc root options roots body = do
  let path=root </> "values.c"
  TextIO.writeFile path (Text.unlines (headers <> selected roots <> body))
  readProcessWithExitCode cc (["-std=c11","-pedantic","-O2","-Wall","-Wextra","-Werror"]
    <> options <> [path,"-o",root </> "values"]) ""

headers :: [Text]
headers = ["#include <float.h>","#include <limits.h>","#include <stdint.h>","#include <inttypes.h>"
  ,"#include <stdio.h>","#include <string.h>"]

testValues :: FilePath -> FilePath -> IO Property
testValues cc root = do
  compiled <- build cc root [] (map fst floatValueRuntimeParts)
    ["int main(void) { unsigned width; uint64_t a,b;"
    ,"  while(scanf(\"%u %\" SCNx64 \" %\" SCNx64,&width,&a,&b)==3) {"
    ,"    int narrow=width==32;"
    ,"    uint64_t x=pudu_float_normalize(pudu_float_decode(a),narrow),y=pudu_float_normalize(pudu_float_decode(b),narrow);"
    ,"    uint64_t results[]={pudu_float_encode(pudu_float_decode(a)),pudu_float_normalize(pudu_float_decode(a),narrow),"
    ,"      pudu_float_add(x,y,narrow),pudu_float_sub(x,y,narrow),pudu_float_mul(x,y,narrow),pudu_float_div(x,y,narrow),"
    ,"      pudu_float_neg(x),pudu_float_sub(pudu_float_mul(x,y,narrow),UINT64_C(0x3ff0000000000000),narrow)};"
    ,"    for(size_t i=0;i<sizeof results/sizeof results[0];++i) printf(\"%\" PRIx64 \" \",results[i]);"
    ,"    printf(\"%d %d %d %d %d %d\\n\",pudu_float_eq(x,y),pudu_float_ne(x,y),pudu_float_lt(x,y),pudu_float_le(x,y),pudu_float_gt(x,y),pudu_float_ge(x,y));"
    ,"    if(fflush(stdout)!=0) return 98;"
    ,"  }", "  return feof(stdin) ? 0 : 99;", "}"]
  if compiled /= (ExitSuccess,"","") then pure (counterexample (show compiled) (False === True))
  else do
    result <- readProcessWithExitCode (root </> "values") []
      (unlines [unwords [if width==Float32Width then "32" else "64",hex a,hex b] | (width,a,b) <- rows])
    putStrLn ("[floating values] executed "<>show (length rows)<>" operand/width rows")
    let (status,output,errors)=result
        locked=[(0x3fb999999999999a,0x3fb99999a0000000),(0x3ff0000010000000,0x3ff0000000000000)
          ,(0x3ff0000010000001,0x3ff0000020000000),(0x3690000000000000,0),(0x3690000000000001,0x36a0000000000000)
          ,(0xb690000000000000,0x8000000000000000),(0x47effffff0000000,0x7ff0000000000000)]
    pure $ conjoin ([status === ExitSuccess,errors === "",length (lines output) === length rows]
      <> [counterexample (hex a) (castDoubleToWord64 (oracleNormalize Float32Width (castWord64ToDouble a)) === b) | (a,b) <- locked]
      <> zipWith (\row actual -> counterexample (show row) (actual === expected row)) rows (lines output))

testRoots :: FilePath -> FilePath -> IO Property
testRoots cc root = conjoin <$> traverse check roots
 where
  one="UINT64_C(0x3ff0000000000000)"; two="UINT64_C(0x4000000000000000)"
  roots = [("float_target","return 0;"),("float_decode","return pudu_float_decode("<>one<>")==1.0 ? 0 : 99;")
    ,("float_encode","return pudu_float_encode(1.0)=="<>one<>" ? 0 : 99;")
    ,("float_normalize","return pudu_float_normalize(1.0,1)=="<>one<>" ? 0 : 99;")
    ,("float_neg","return pudu_float_neg(0)==UINT64_C(0x8000000000000000) ? 0 : 99;")]
    <> [(name,"return pudu_"<>name<>"("<>one<>","<>one<>",1)=="<>answer<>" ? 0 : 99;")
      | (name,answer) <- [("float_add",two),("float_sub","0"),("float_mul",one),("float_div",one)]]
    <> [(name,"return pudu_"<>name<>"("<>one<>","<>two<>")=="<>answer<>" ? 0 : 99;")
      | (name,answer) <- [("float_eq","0"),("float_ne","1"),("float_lt","1"),("float_le","1"),("float_gt","0"),("float_ge","0")]]
  check (name,body) = do
    compiled <- build cc root [] [name] ["int main(void) { "<>body<>" }"]
    if compiled /= (ExitSuccess,"","") then pure (counterexample (show (name,compiled)) (False === True))
    else do
      result <- readProcessWithExitCode (root </> "values") [] ""
      pure (counterexample (Text.unpack name) (result === (ExitSuccess,"","")))

testPolicies :: FilePath -> FilePath -> IO Property
testPolicies cc root = do
  unsafe <- traverse (\option -> build cc root [option] ["float_target"] ["int main(void) { return 0; }"])
    ["-ffast-math","-ffinite-math-only"]
  let wrong=headers<>["#undef DBL_MANT_DIG","#define DBL_MANT_DIG 52"]<>selected ["float_target"]<>["int main(void) { return 0; }"]
      path=root </> "wrong.c"
  TextIO.writeFile path (Text.unlines wrong)
  dimension <- readProcessWithExitCode cc ["-std=c11","-pedantic","-Werror",path,"-o",root </> "wrong"] ""
  pure $ conjoin (map (refuses "Pudu floating runtime requires precise IEEE arithmetic") unsafe
    <> [refuses "Pudu floating runtime requires binary64 arithmetic" dimension])
 where
  refuses message (status,_,errors) = counterexample errors (conjoin
    [counterexample "unsafe floating policy compiled" ((status /= ExitSuccess) === True)
    ,Text.pack message `Text.isInfixOf` Text.pack errors === True])
