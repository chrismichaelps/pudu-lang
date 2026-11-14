{-| @Test.Backend.Word128Spec — executed C11 words against independent Integer answers. -}
module Pudu.Backend.Word128Spec (word128Properties) where

import Data.Bits (shiftL, shiftR)
import Data.List (nub)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Runtime.Integer.Word128 (word128Runtime)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, counterexample, (===))

word128Properties :: [(String, IO Property)]
word128Properties = [("native word128 arithmetic and shifts match Integer", testWords)]

testWords :: IO Property
testWords = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "word128 execution requires a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-word128" $ \root -> do
      let cpath = root </> "words.c"
          binary = root </> "words"
      TextIO.writeFile cpath (Text.unlines (prelude <> word128Runtime <> tables <> checks))
      (built, output, errors) <- readProcessWithExitCode cc
        ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", cpath, "-o", binary] ""
      if built /= ExitSuccess || not (null output && null errors)
        then pure (counterexample (show built <> output <> errors) (False === True))
        else do
          result <- readProcessWithExitCode binary [] ""
          putStrLn ("[word128] executed " <> show (length pairs) <> " arithmetic and " <> show (length shifts) <> " shift rows")
          pure $ counterexample (show result) $ result === (ExitSuccess, "", "")

modulus :: Integer
modulus = 2 ^ (128 :: Int)

edges :: [Integer]
edges = nub ([0, 1, 2, 3, modulus - 1] <> [2 ^ bit + delta | bit <- [31, 32, 63, 64, 65, 95, 96, 127 :: Int], delta <- [-1, 0, 1]])

pairs :: [(Integer, Integer)]
pairs = [(a, b) | a <- edges, b <- edges] <> take 256 (zip samples (drop 19 samples))
  where
    samples = iterate (\value -> (value * 47026247687942121848144207491837523525 + 1442695040888963407) `mod` modulus) 7

shifts :: [(Integer, Maybe Int)]
shifts = [(a, count) | a <- edges, count <- map Just [0 .. 129] <> [Nothing]]

word :: Integer -> Text
word value = "{" <> constant (value `mod` base) <> "," <> constant (value `div` base) <> "}"
  where
    base = 2 ^ (64 :: Int)
    constant number = "UINT64_C(" <> Text.pack (show number) <> ")"

tables :: [Text]
tables =
  [ "static const struct { pudu_word128 a, b, sum, difference, product, quotient, remainder;"
  , "  int carry, overflow, order, zero; } arithmetic[] = {"
  ] <> map arithmeticRow pairs <>
  [ "};", "static const struct { pudu_word128 a, left, right; unsigned count; } shifts[] = {" ]
  <> map shiftRow shifts <> ["};"]
  where
    arithmeticRow (a, b) =
      let summed = a + b
          productValue = a * b
          (quotient, remainder) = if b == 0 then (0, 0) else quotRem a b
          order = case compare a b of LT -> "-1"; EQ -> "0"; GT -> "1"
          flag yes = if yes then "1" else "0"
       in "{" <> Text.intercalate ","
            (map word [a, b, summed `mod` modulus, (a - b) `mod` modulus,
              productValue `mod` modulus, quotient, remainder]
              <> [flag (summed >= modulus), flag (productValue >= modulus), order, flag (b == 0)]) <> "},"
    shiftRow (a, count) =
      let (left, right) = case count of
            Just places -> (shiftL a places `mod` modulus, shiftR a places)
            Nothing -> (0, 0)
       in "{" <> Text.intercalate "," (map word [a, left, right]
            <> [maybe "UINT_MAX" (Text.pack . show) count]) <> "},"

prelude :: [Text]
prelude = ["#include <stdint.h>", "#include <stdio.h>", "#include <limits.h>"]

checks :: [Text]
checks =
  [ "static int same(pudu_word128 a, pudu_word128 b) { return a.low == b.low && a.high == b.high; }"
  , "#define CHECK(test) do { if (!(test)) { fprintf(stderr, \"case %zu: %s\\n\", i, #test); return 1; } } while (0)"
  , "int main(void) {"
  , "  for (size_t i = 0; i < sizeof arithmetic / sizeof arithmetic[0]; ++i) {"
  , "    pudu_word128 a = arithmetic[i].a, b = arithmetic[i].b;"
  , "    pudu_word128_sum sum = pudu_word128_add(a, b);"
  , "    pudu_word128_product product = pudu_word128_multiply(a, b);"
  , "    pudu_word128_division divided = pudu_word128_divide(a, b);"
  , "    CHECK(same(sum.value, arithmetic[i].sum));"
  , "    CHECK(sum.carry == arithmetic[i].carry);"
  , "    CHECK(same(pudu_word128_sub(a, b), arithmetic[i].difference));"
  , "    CHECK(same(product.value, arithmetic[i].product));"
  , "    CHECK(product.overflow == arithmetic[i].overflow);"
  , "    CHECK(pudu_word128_compare(a, b) == arithmetic[i].order);"
  , "    CHECK(pudu_word128_zero(b) == arithmetic[i].zero);"
  , "    CHECK(divided.zero == arithmetic[i].zero);"
  , "    CHECK(same(divided.quotient, arithmetic[i].quotient));"
  , "    CHECK(same(divided.remainder, arithmetic[i].remainder));"
  , "  }"
  , "  for (size_t i = 0; i < sizeof shifts / sizeof shifts[0]; ++i) {"
  , "    CHECK(same(pudu_word128_left(shifts[i].a, shifts[i].count), shifts[i].left));"
  , "    CHECK(same(pudu_word128_right(shifts[i].a, shifts[i].count), shifts[i].right));"
  , "  }"
  , "  return 0;"
  , "}"
  ]
