{-| @Test.Backend.FloatFormatSpec — raw binary64 text held to locked GHC spellings. -}
module Pudu.Backend.FloatFormatSpec (floatFormatProperties) where

import Data.Bits ((.|.), shiftL)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Word (Word32, Word64)
import GHC.Float (castDoubleToWord64, castWord32ToFloat, castWord64ToDouble, float2Double)
import Numeric (showHex)
import Pudu.Backend.Runtime.Float.Format (floatFormatRuntimeParts, floatFormatRuntimeDependencies)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

floatFormatProperties :: [(String, IO Property)]
floatFormatProperties =
  [ ("native binary64 formatting matches GHC byte for byte", withCompiler testFormatting)
  , ("native binary64 formatter roots retain notices and exact prerequisites", withCompiler testRoots)
  ]

goldens :: [(Word64,String)]
goldens = [(0,"0.0"),(0x8000000000000000,"-0.0"),(0x3fb999999999999a,"0.1")
  ,(0x3f847ae147ae147b,"1.0e-2"),(0x416312cfe0000000,"9999999.0"),(0x416312d000000000,"1.0e7")
  ,(0x44b52d02c7e14af6,"9.999999999999999e22"),(0x7ff0000000000000,"Infinity")
  ,(0xfff0000000000000,"-Infinity"),(0x7ff8000000000000,"NaN"),(0xfff8000000000001,"NaN")
  ,(0x3fb99999a0000000,"0.10000000149011612")]

patterns :: [Word64]
patterns = Set.toAscList (Set.fromList (map fst goldens <> boundaries <> decimalPowers <> narrow <> samples))
  where
    boundaries = [sign .|. shiftL field 52 .|. fraction | sign <- [0,0x8000000000000000], field <- [0..2047]
      , fraction <- [0,1,2^(51::Int)-1,2^(51::Int),2^(52::Int)-2,2^(52::Int)-1]]
    decimalPowers = [sign .|. (bits+delta) | places <- [-324::Int ..309]
      , let bits=castDoubleToWord64 (read ("1e"<>show places) :: Double)
      , delta <- [0,1,2,maxBound,maxBound-1], sign <- [0,0x8000000000000000]]
    narrow = map (castDoubleToWord64 . float2Double . castWord32ToFloat)
      ([0,1,0x007fffff,0x00800000,0x3dcccccd,0x3f800001,0x7f7fffff,0x7f800000,0x7fc00000,0x80000000,0xff7fffff] :: [Word32])
    samples = take 32768 (iterate (\n -> n*6364136223846793005+1442695040888963407) 7)

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "binary64 formatter tests require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-float-format" (action cc)

selected :: [Text] -> [Text]
selected roots = concat [code | (name,code) <- floatFormatRuntimeParts, Set.member name closure]
  where
    closure = foldl' visit Set.empty roots
    visit found name | Set.member name found = found
                     | otherwise = foldl' visit (Set.insert name found) (floatFormatRuntimeDependencies name)

execute :: FilePath -> FilePath -> [Text] -> [Text] -> String -> IO (Either String (ExitCode,String,String))
execute cc root roots body stdinText = do
  let path=root </> "format.c"; binary=root </> "format"
  TextIO.writeFile path (Text.unlines (headers <> selected roots <> body))
  (status,output,errors) <- readProcessWithExitCode cc
    ["-std=c11","-pedantic","-O2","-Wall","-Wextra","-Werror",path,"-o",binary] ""
  if status /= ExitSuccess || not (null output && null errors)
    then pure (Left (show status<>output<>errors))
    else Right <$> readProcessWithExitCode binary [] stdinText

headers :: [Text]
headers = ["#include <stddef.h>","#include <stdint.h>","#include <inttypes.h>","#include <stdio.h>","#include <stdlib.h>","#include <string.h>"]

testFormatting :: FilePath -> FilePath -> IO Property
testFormatting cc root = do
  result <- execute cc root ["float_format"]
    ["int main(void) { uint64_t bits; int read;"
    ,"  while((read=scanf(\"%\" SCNx64,&bits))==1) {"
    ,"    char guarded[34]; memset(guarded,'~',sizeof guarded);"
    ,"    size_t length=pudu_format_float64(bits,guarded+1);"
    ,"    if(length==0 || length>31 || guarded[0]!='~' || guarded[33]!='~') return 99;"
    ,"    if(fwrite(guarded+1,1,length,stdout)!=length || putchar('\\n')==EOF || fflush(stdout)!=0) return 98;"
    ,"  }", "  return read==EOF ? 0 : 97;", "}"] (unlines [showHex bits "" | bits <- patterns])
  putStrLn ("[binary64 format] executed "<>show (length patterns)<>" unique encodings")
  pure $ case result of
    Left failure -> counterexample failure (False === True)
    Right (status,output,errors) -> conjoin
      ([status === ExitSuccess, errors === "", length (lines output) === length patterns]
       <> [counterexample (showHex bits "") (show (castWord64ToDouble bits) === text) | (bits,text) <- goldens]
       <> zipWith (\bits actual -> counterexample (showHex bits "") (actual === show (castWord64ToDouble bits))) patterns (lines output))

testRoots :: FilePath -> FilePath -> IO Property
testRoots cc root = do
  notice <- TextIO.readFile "packages/pudu/v0.1/THIRD_PARTY_NOTICES"
  outcomes <- traverse check
    [("float_require","pudu_float_require(1); return 0;")
    ,("float_decimal","pudu_float_digits value=pudu_float_decimal(UINT64_C(0x3ff0000000000000)); return value.length==1 && value.digits[0]=='1' && value.exponent==1 ? 0 : 99;")
    ,("float_format","char output[32]; size_t length=pudu_format_float64(UINT64_C(0x3ff0000000000000),output); return length==3 && memcmp(output,\"1.0\",3)==0 ? 0 : 99;")]
  pure $ conjoin (outcomes <> [counterexample "adapted decimal code lost its notice" (notice `Text.isInfixOf` Text.unlines (selected [name])) | name <- ["float_decimal","float_format"]])
  where
    check (name,body) = do
      result <- execute cc root [name] ["int main(void) { "<>body<>" }"] ""
      pure (counterexample (Text.unpack name<>": "<>show result) (result === Right (ExitSuccess,"","")))
