{-| @Test.Backend.WideOperationsSpec — executed wide policies and refusal routing. -}
module Pudu.Backend.WideOperationsSpec (wideOperationProperties) where

import Data.Bits ((.&.), (.|.), xor, complement, shiftL, shiftR)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Runtime.Integer.Value (valueRuntimeParts)
import Pudu.Backend.Runtime.Integer.Word128 (word128RuntimeParts, word128RuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Value (wideValueRuntimeParts, wideValueRuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Operations (wideOperationRuntimeParts, wideOperationRuntimeDependencies)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

type Operation = (Text, Text, Bool -> Integer -> Integer -> Either Int Integer)

wideOperationProperties :: [(String, IO Property)]
wideOperationProperties =
  [ ("native wide operations match Integer and exact refusal sites", withCompiler testMatrix)
  , ("native wide operations select complete minimal helper closures", withCompiler testSelections)
  ]

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "wide operations require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-wide-operations" (action cc)

execute :: FilePath -> FilePath -> [Text] -> IO Property
execute cc root body = do
  let source = root </> "operations.c"
      binary = root </> "operations"
  TextIO.writeFile source (Text.unlines (["#include <stdint.h>", "#include <stdio.h>", "#include <setjmp.h>", "static jmp_buf test_jump;", "static int test_failure;"] <> body))
  (status, output, errors) <- readProcessWithExitCode cc
    ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", source, "-o", binary] ""
  if status /= ExitSuccess || not (null output && null errors)
    then pure (counterexample (show status <> output <> errors) (False === True))
    else do
      result <- readProcessWithExitCode binary [] ""
      pure (counterexample (show result) (result === (ExitSuccess, "", "")))

parts :: [(Text, [Text])]
parts = [(name, body) | (name, body) <- valueRuntimeParts, name == "integer_value"]
  <> [("site", ["typedef struct { int identity; } pudu_site;"])
     , ("fail", ["static void pudu_fail(const pudu_site *site) { test_failure = site->identity; longjmp(test_jump, 1); }"])]
  <> word128RuntimeParts <> wideValueRuntimeParts <> wideOperationRuntimeParts

dependencies :: Text -> [Text]
dependencies name = word128RuntimeDependencies name <> wideValueRuntimeDependencies name <> wideOperationRuntimeDependencies name

selected :: [Text] -> [Text]
selected roots = concat [body | (name, body) <- parts, Set.member name closure]
  where
    closure = foldl' visit Set.empty roots
    visit found name | Set.member name found = found
                     | otherwise = foldl' visit (Set.insert name found) (dependencies name)

modulus :: Integer
modulus = 2 ^ (128 :: Int)

bounds :: Bool -> (Integer, Integer)
bounds signed = if signed then (negate (modulus `div` 2), modulus `div` 2 - 1) else (0, modulus - 1)

wrap :: Bool -> Integer -> Integer
wrap signed value = let (low, _) = bounds signed in (value - low) `mod` modulus + low

checked :: Bool -> Integer -> Either Int Integer
checked signed value = let (low, high) = bounds signed in if value < low || value > high then Left 5 else Right value

operations :: [Operation]
operations =
  [ ("add", "pudu_wide_add(a,b,kind,&overflow)", \k a b -> checked k (a+b))
  , ("sub", "pudu_wide_sub(a,b,kind,&overflow)", \k a b -> checked k (a-b))
  , ("mul", "pudu_wide_mul(a,b,kind,&overflow)", \k a b -> checked k (a*b))
  , ("div", "pudu_wide_div(a,b,kind,&zero,&overflow)", \k a b -> if b == 0 then Left 4 else checked k (quot a b))
  , ("rem", "pudu_wide_rem(a,b,&zero)", \_ a b -> if b == 0 then Left 4 else Right (rem a b))
  , ("neg", "pudu_wide_neg(a,kind,&overflow)", \k a _ -> checked k (negate a))
  ] <> [("sat_" <> name, "pudu_wide_sat_" <> name <> "(a,b,kind)", \k a b -> let (low,high) = bounds k in Right (max low (min high (operation a b))))
       | (name, operation) <- arithmetic]
    <> [("wrap_" <> name, "pudu_wide_wrap_" <> name <> "(a,b,kind)", \k a b -> Right (wrap k (operation a b))) | (name, operation) <- arithmetic]
    <> [("bit_" <> name, "pudu_wide_bit_" <> name <> "(a,b,kind)", \k a b -> Right (wrap k (operation a b))) | (name, operation) <- [("and", (.&.)), ("or", (.|.)), ("xor", xor)]]
    <> [("bit_not", "pudu_wide_bit_not(a,kind)", \k a _ -> Right (wrap k (complement a)))]
    <> [("shift_" <> name, "pudu_wide_shift_" <> name <> "(a,(pudu_int){b.bits.low,b.negative},kind,&negative,&wide)",
          \k a b -> if b < 0 then Left 6 else if b >= 128 then Left 7 else Right (wrap k (operation a (fromInteger b))))
       | (name, operation) <- [("left", shiftL), ("right", shiftR)]]
  where
    arithmetic = [("add", (+)), ("sub", (-)), ("mul", (*))]

rows :: [(Int, Bool, Integer, Integer, Either Int Integer)]
rows = [(index, signed, a, b, oracle signed a b) | signed <- [False, True], (index,(name,_,oracle)) <- zip [0..] operations
       , (a,b) <- inputs signed name]
  where
    samples signed = map (wrap signed) (take 32 (iterate (\value -> (value * 47026247687942121848144207491837523525 + 1442695040888963407) `mod` modulus) 7))
    edges signed = let (low,high) = bounds signed in if signed
      then [low,low+1,-(2^(64::Int)),-1,0,1,2,2^(64::Int),high-1,high,high+1]
      else [0,1,2,2^(63::Int),2^(64::Int)-1,2^(64::Int),2^(127::Int),high-1,high]
    inputs signed name
      | "shift_" `Text.isPrefixOf` name = [(a,b) | a <- edges signed <> samples signed, b <- [-2^(63::Int),-1,0,1,31,32,63,64,65,95,96,126,127,128,2^(63::Int)]]
      | name `elem` ["neg","bit_not"] = [(a,0) | a <- edges signed <> samples signed]
      | otherwise = [(a,b) | a <- edges signed,b <- edges signed] <> zip (samples signed) (drop 7 (cycle (samples signed)))

number :: Show a => a -> Text
number = Text.pack . show

word :: Integer -> Text
word value = "{UINT64_C(" <> number (bits `mod` base) <> "),UINT64_C(" <> number (bits `div` base) <> ")}"
  where base = 2^(64::Int); bits = value `mod` modulus

wideText :: Integer -> Text
wideText integer = "{" <> word integer <> "," <> (if integer < 0 then "1" else "0") <> "}"

sites :: Text
sites = "const pudu_site overflow={5}, zero={4}, negative={6}, wide={7};"

testMatrix :: FilePath -> FilePath -> IO Property
testMatrix cc root = do
  result <- execute cc root (selected (map fst wideOperationRuntimeParts) <> table <> checks)
  putStrLn ("[wide operations] executed " <> show (length rows) <> " rows (" <> show (length [() | (_,_,_,_,Left _) <- rows]) <> " refusals)")
  pure result
  where
    table = ["static const struct { int operation, signed_kind; pudu_wide_int a,b,expected; int failure; } cases[] = {"]
      <> ["{" <> Text.intercalate "," [number index, if signed then "1" else "0", wideText a, wideText b,
            wideText (either (const 0) id answer), number (either id (const 0) answer)] <> "}," | (index,signed,a,b,answer) <- rows] <> ["};"]
    checks =
      ["static int test_case(size_t i) {", "  " <> sites
      , "  pudu_wide_int a=cases[i].a, b=cases[i].b; pudu_wide_kind kind={cases[i].signed_kind};"
      , "  test_failure=0;"
      , "  if (setjmp(test_jump) == 0) {", "    pudu_wide_int result;", "    switch(cases[i].operation) {"]
      <> ["    case " <> number index <> ": result=" <> call <> "; break;" | (index,(_,call,_)) <- zip [0::Int ..] operations]
      <> ["    default: return 1;", "    }"
         , "    if(cases[i].failure || result.bits.low!=cases[i].expected.bits.low || result.bits.high!=cases[i].expected.bits.high || result.negative!=cases[i].expected.negative) return 1;"
         , "  } else if(test_failure!=cases[i].failure) return 1;", "  return 0;", "}"
         , "int main(void) { for(size_t i=0; i<sizeof cases/sizeof cases[0]; ++i) {"
         , "  if(test_case(i)) { fprintf(stderr,\"wide case %zu failed\\n\",i); return 1; } } return 0; }"]

testSelections :: FilePath -> FilePath -> IO Property
testSelections cc root = do
  results <- traverse check calls
  pure $ conjoin ([Set.fromList (map fst calls) === Set.fromList (map fst wideOperationRuntimeParts),
    length calls === length wideOperationRuntimeParts,
    counterexample "unknown dependency" (all (`elem` map fst parts) (concatMap (dependencies . fst) parts))] <> results)
  where
    calls =
      [("wide_add_math", "pudu_wide_add_math(a,b)")
      , ("wide_multiply_math", "pudu_wide_multiply_math(a,b)")
      , ("wide_checked_result", "pudu_wide_checked_result((pudu_wide_calculation){a,0},kind,&overflow)")
      , ("wide_saturate_result", "pudu_wide_saturate_result((pudu_wide_calculation){a,0},kind)")]
      <> [("wide_" <> name,call) | (name,call,_) <- operations]
    check (name,call) = counterexample (Text.unpack name) <$> execute cc root (selected [name] <>
      ["int main(void) { " <> (if "&" `Text.isInfixOf` call then sites <> " (void)overflow; (void)zero; (void)negative; (void)wide;" else "")
      , "  pudu_wide_int a={{1,0},0},b={{1,0},0}; pudu_wide_kind kind={1};"
      , "  (void)a; (void)b; (void)kind;"
      , "  (void)test_failure; if(setjmp(test_jump)) return 1;"
      , "  (void)" <> call <> "; return 0; }"])
