{-| @Test.Backend.TextCaseSpec — native case mapping and trim over every scalar. -}
module Pudu.Backend.TextCaseSpec (textCaseProperties) where

import qualified Data.ByteString as ByteString
import Data.Char (chr, isSpace, ord)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Encoding
import qualified Data.Text.IO as TextIO
import Numeric (showHex)
import Pudu.Backend.Runtime (RuntimePart (..), runtimeParts)
import Pudu.Backend.Runtime.Dependencies (runtimeDependencies)
import System.Directory (findExecutable)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import System.Process (readProcessWithExitCode)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

textCaseProperties :: [(String, IO Property)]
textCaseProperties =
  [ ("native case mapping and trim agree with Data.Text on every scalar", testScalars)
  , ("the linked Data.Text maps case one scalar at a time", testContextFree)
  ]

{-| The native tables model conversion scalar by scalar, which only holds while
    the linked text library has no contextual rules such as a final sigma. -}
testContextFree :: IO Property
testContextFree = pure $ conjoin
  [ counterexample (Text.unpack label) (convert sample === Text.concatMap (convert . Text.singleton) sample)
  | (label, convert) <- [("toUpper", Text.toUpper), ("toLower", Text.toLower)]
  , sample <- [everything, Text.pack "\x3a3\x3a3 x\x3a3 \x3a3.", Text.pack "I\x307 \x130 i\x307" ] ]
 where
  everything = Text.pack scalars

testScalars :: IO Property
testScalars = do
  configured <- lookupEnv "PUDU_CC"
  compiler <- findExecutable (maybe "cc" id configured)
  case compiler of
    Nothing -> pure (counterexample "case checks require a C11 compiler" (False === True))
    Just cc -> withSystemTempDirectory "pudu-text-case" $ \root -> do
      let source = root </> "case.c"
          binary = root </> "case"
      TextIO.writeFile source (Text.unlines (selected ["prelude", "text_literal", "text_to_upper", "text_to_lower", "text_trim"] <> driver))
      (built, output, errors) <- readProcessWithExitCode cc
        ["-std=c11", "-pedantic", "-O2", "-Wall", "-Wextra", "-Werror", source, "-o", binary] ""
      if built /= ExitSuccess || not (null output && null errors)
        then pure (counterexample (show built <> output <> errors) (False === True))
        else do
          (status, out, err) <- readProcessWithExitCode binary [] ""
          let actual = lines out
              wanted = map Text.unpack expected
              missing = take 5 (Set.toList (Set.difference (Set.fromList wanted) (Set.fromList actual)))
              extra = take 5 (Set.toList (Set.difference (Set.fromList actual) (Set.fromList wanted)))
          putStrLn ("[text case] compared " <> show (length wanted) <> " differing scalars and spaces")
          pure $ counterexample (show (missing, extra, err)) $ conjoin
            [status === ExitSuccess, err === "", actual === wanted]

{-| What the driver prints: one line per scalar that changes under a
    conversion, with the replacement's UTF-8 bytes, and one per scalar trim
    removes. -}
expected :: [Text]
expected = concat
  [ [tagged "U" scalar upper | (scalar, upper) <- changed Text.toUpper]
  , [tagged "L" scalar lower | (scalar, lower) <- changed Text.toLower]
  , ["S " <> hex (ord scalar) | scalar <- scalars, isSpace scalar] ]
 where
  changed convert = [(scalar, into) | scalar <- scalars, let into = convert (Text.singleton scalar), into /= Text.singleton scalar]
  tagged mark scalar into = mark <> " " <> hex (ord scalar) <> " "
    <> Text.concat [byte value | value <- ByteString.unpack (Encoding.encodeUtf8 into)]
  byte value = Text.pack (let digits = showHex value "" in if length digits == 1 then '0' : digits else digits)

hex :: Int -> Text
hex value = Text.pack (showHex value "")

scalars :: [Char]
scalars = [chr code | code <- [0 .. 0x10FFFF], code < 0xD800 || code > 0xDFFF]

driver :: [Text]
driver =
  [ "static void test_report(const char *mark, uint32_t scalar, pudu_text from, pudu_text into) {"
  , "  if (into.length == from.length && memcmp(into.bytes, from.bytes, from.length) == 0) return;"
  , "  printf(\"%s %\" PRIx32 \" \", mark, scalar);"
  , "  for (size_t i = 0; i < into.length; ++i) printf(\"%02x\", into.bytes[i]);"
  , "  putchar('\\n');"
  , "}"
  , "int main(void) {"
  , "  unsigned char bytes[4];"
  , "  uint32_t scalar;"
  , "  for (int pass = 0; pass < 3; ++pass) {"
  , "    for (scalar = 0; scalar <= 0x10FFFF; ++scalar) {"
  , "      pudu_text text, mapped;"
  , "      if (scalar >= 0xD800 && scalar <= 0xDFFF) continue;"
  , "      text = pudu_text_literal((const char *)bytes, pudu_text_encode(scalar, bytes));"
  , "      if (pass == 2) {"
  , "        mapped = pudu_text_trim(text);"
  , "        if (mapped.length == 0) printf(\"S %\" PRIx32 \"\\n\", scalar);"
  , "      } else {"
  , "        mapped = pass == 0 ? pudu_text_to_upper(text) : pudu_text_to_lower(text);"
  , "        test_report(pass == 0 ? \"U\" : \"L\", scalar, text, mapped);"
  , "      }"
  , "      pudu_text_release(mapped);"
  , "    }"
  , "  }"
  , "  return 0;"
  , "}"
  ]

selected :: [Text] -> [Text]
selected roots = concat [runtimePartLines part | part <- runtimeParts, Set.member (runtimePartName part) closure]
 where
  closure = foldl' visit Set.empty roots
  visit seen name
    | Set.member name seen = seen
    | otherwise = foldl' visit (Set.insert name seen) (runtimeDependencies name)
