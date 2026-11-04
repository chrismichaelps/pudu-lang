{-| @Test.Backend.WideValueSpec — exact wide carriers and minimal C11 selections. -}
module Pudu.Backend.WideValueSpec (wideValueProperties) where

import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Backend.Runtime.Integer.Word128 (word128RuntimeParts, word128RuntimeDependencies)
import Pudu.Backend.Runtime.Integer.Wide.Value (wideValueRuntimeParts, wideValueRuntimeDependencies)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

wideValueProperties :: [(String, IO Property)]
wideValueProperties =
  [ ("native wide values preserve exact signs and magnitudes", withCompiler testValues)
  , ("native wide helpers compile independently with exact prerequisites", withCompiler testSelections)
  ]

withCompiler :: (FilePath -> FilePath -> IO Property) -> IO Property
withCompiler action = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "wide value checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-wide-values" (action cc)

execute :: FilePath -> FilePath -> [Text] -> IO Property
execute cc root linesOfC = do
  let source = root </> "values.c"
      binary = root </> "values"
  TextIO.writeFile source (Text.unlines (["#include <stdint.h>", "#include <stdio.h>"] <> linesOfC))
  (status, output, errors) <- readProcessWithExitCode cc
    ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", source, "-o", binary] ""
  if status /= ExitSuccess || not (null output && null errors)
    then pure (counterexample (show status <> output <> errors) (False === True))
    else do
      result <- readProcessWithExitCode binary [] ""
      pure (counterexample (show result) (result === (ExitSuccess, "", "")))

parts :: [(Text, [Text])]
parts = word128RuntimeParts <> wideValueRuntimeParts

selected :: [Text] -> [Text]
selected roots = concat [body | (name, body) <- parts, Set.member name closure]
  where
    closure = foldl' visit Set.empty roots
    visit found name
      | Set.member name found = found
      | otherwise = foldl' visit (Set.insert name found)
          (word128RuntimeDependencies name <> wideValueRuntimeDependencies name)

testSelections :: FilePath -> FilePath -> IO Property
testSelections cc root = do
  results <- traverse check selections
  pure $ conjoin
    ([ counterexample "uncovered or duplicate helper" (map fst parts === map fst selections)
     , counterexample "unknown helper dependency" (all (`elem` map fst parts)
         (concatMap (\name -> word128RuntimeDependencies name <> wideValueRuntimeDependencies name) (map fst parts)))
     ] <> results)
  where
    check (name, expression) = counterexample (Text.unpack name) <$>
      execute cc root (selected [name] <> ["int main(void) { " <> expression <> " return 0; }"])
    word = "(pudu_word128){3, 0}"
    value = "(pudu_wide_int){{3, 0}, 0}"
    selections =
      [ ("word128_value", ""), ("word128_zero", "(void)pudu_word128_zero(" <> word <> ");")
      , ("word128_compare", "(void)pudu_word128_compare(" <> word <> ", " <> word <> ");")
      , ("word128_add", "(void)pudu_word128_add(" <> word <> ", " <> word <> ");")
      , ("word128_sub", "(void)pudu_word128_sub(" <> word <> ", " <> word <> ");")
      , ("word128_left", "(void)pudu_word128_left(" <> word <> ", 64);")
      , ("word128_right", "(void)pudu_word128_right(" <> word <> ", 64);")
      , ("word128_multiply", "(void)pudu_word128_multiply(" <> word <> ", " <> word <> ");")
      , ("word128_divide", "(void)pudu_word128_divide(" <> word <> ", " <> word <> ");")
      , ("wide_value", ""), ("wide_magnitude", "(void)pudu_wide_magnitude(" <> value <> ");")
      , ("wide_make", "(void)pudu_wide_make(" <> word <> ", 1);")
      , ("wide_normal", "(void)pudu_wide_normal(" <> value <> ");")
      , ("wide_from_bits", "(void)pudu_wide_from_bits(" <> word <> ", (pudu_wide_kind){1});")
      , ("wide_compare", "(void)pudu_wide_compare(" <> value <> ", " <> value <> ");")
      , ("wide_limit", "(void)pudu_wide_limit((pudu_wide_kind){1}, 1);")
      ]

modulus :: Integer
modulus = 2 ^ (128 :: Int)

values :: [Integer]
values = [-modulus + 1, -half, -half + 1, -(2 ^ (64 :: Int)), -1, 0, 1, 2 ^ (64 :: Int), half - 1, half, modulus - 1]
  <> samples <> map negate samples
  where
    half = modulus `div` 2
    samples = take 32 (iterate (\value -> (value * 47026247687942121848144207491837523525 + 1442695040888963407) `mod` modulus) 7)

wordText :: Integer -> Text
wordText value = "{UINT64_C(" <> number (bits `mod` base) <> "),UINT64_C(" <> number (bits `div` base) <> ")}"
  where
    base = 2 ^ (64 :: Int)
    bits = value `mod` modulus

number :: Show a => a -> Text
number = Text.pack . show

wideText :: Integer -> Text
wideText value = "{" <> wordText value <> "," <> (if value < 0 then "1" else "0") <> "}"

testValues :: FilePath -> FilePath -> IO Property
testValues cc root = do
  result <- execute cc root (selected (map fst wideValueRuntimeParts) <> tables <> checks)
  putStrLn ("[wide values] executed " <> show (length values) <> " values and " <> show (length values ^ (2 :: Int)) <> " comparisons")
  pure result
  where
    signed value = (value + modulus `div` 2) `mod` modulus - modulus `div` 2
    tables = ["static const struct { pudu_wide_int value; pudu_word128 magnitude; pudu_wide_int decoded; } values[] = {"]
      <> ["{" <> wideText value <> "," <> wordText (abs value) <> "," <> wideText (signed value) <> "}," | value <- values]
      <> ["};", "static const int comparisons[] = {"]
      <> [Text.intercalate "," [case compare a b of LT -> "-1"; EQ -> "0"; GT -> "1" | b <- values] <> "," | a <- values]
      <> ["};"]

checks :: [Text]
checks =
  [ "static int same(pudu_word128 a, pudu_word128 b) { return a.low == b.low && a.high == b.high; }"
  , "#define CHECK(test) do { if (!(test)) { fprintf(stderr, \"line %d: %s\\n\", __LINE__, #test); return 1; } } while (0)"
  , "int main(void) {"
  , "  const size_t count = sizeof values / sizeof values[0];"
  , "  for (size_t i = 0; i < count; ++i) {"
  , "    pudu_wide_int a = values[i].value;"
  , "    pudu_wide_int made = pudu_wide_make(values[i].magnitude, a.negative);"
  , "    pudu_wide_int normal = pudu_wide_normal(a);"
  , "    pudu_wide_int decoded = pudu_wide_from_bits(a.bits, (pudu_wide_kind){1});"
  , "    pudu_wide_int unsigned_value = pudu_wide_from_bits(a.bits, (pudu_wide_kind){0});"
  , "    CHECK(same(made.bits, a.bits) && made.negative == a.negative);"
  , "    CHECK(same(pudu_wide_magnitude(a), values[i].magnitude));"
  , "    CHECK(same(normal.bits, a.bits) && normal.negative == a.negative);"
  , "    CHECK(same(decoded.bits, values[i].decoded.bits) && decoded.negative == values[i].decoded.negative);"
  , "    CHECK(same(unsigned_value.bits, a.bits) && unsigned_value.negative == 0);"
  , "    for (size_t j = 0; j < count; ++j) CHECK(pudu_wide_compare(a, values[j].value) == comparisons[i * count + j]);"
  , "  }"
  , "  pudu_wide_int zero = pudu_wide_make((pudu_word128){0, 0}, 1);"
  , "  CHECK(zero.negative == 1 && same(zero.bits, (pudu_word128){0, 0}));"
  , "  CHECK(pudu_wide_normal(zero).negative == 0);"
  , "  CHECK(pudu_wide_compare(zero, (pudu_wide_int){{0, 0}, 0}) == 0);"
  , "  CHECK(pudu_wide_compare((pudu_wide_int){{0, 0}, 0}, zero) == 0);"
  , "  CHECK(same(pudu_wide_limit((pudu_wide_kind){1}, 0), (pudu_word128)" <> wordText (modulus `div` 2 - 1) <> "));"
  , "  CHECK(same(pudu_wide_limit((pudu_wide_kind){1}, 1), (pudu_word128)" <> wordText (modulus `div` 2) <> "));"
  , "  CHECK(same(pudu_wide_limit((pudu_wide_kind){0}, 0), (pudu_word128)" <> wordText (modulus - 1) <> "));"
  , "  CHECK(same(pudu_wide_limit((pudu_wide_kind){0}, 1), (pudu_word128)" <> wordText 0 <> "));"
  , "  return 0;"
  , "}"
  ]
