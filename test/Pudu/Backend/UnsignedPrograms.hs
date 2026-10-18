{-| @Test.Backend.UnsignedPrograms — full unsigned domains with Integer reference answers. -}
module Pudu.Backend.UnsignedPrograms (unsignedSuccessPrograms, unsignedRefusalPrograms) where

import Data.Bits ((.&.), (.|.), xor, shiftL, shiftR)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex, showOct)

type Family = (Text, Int, Text)

families :: [Family]
families = ("UInt", 64, "") : [("UInt" <> number width, fromInteger width, "u" <> number width) | width <- [8, 16, 32, 64]]

unsignedSuccessPrograms :: [(String, Text, Text)]
unsignedSuccessPrograms = concatMap successes families

unsignedRefusalPrograms :: [(String, Text)]
unsignedRefusalPrograms = concatMap failures families

successes :: Family -> [(String, Text, Text)]
successes family@(kind, width, suffix) =
  [ ("unsigned matrix " <> Text.unpack kind, program (declarations <> ["fn main() -> Int {"]
      <> ["  print(display(" <> expression <> "))" | (expression, _) <- cases] <> ["  return 0", "}"]),
      Text.unlines (map snd cases))
  , ("unsigned transfers " <> Text.unpack kind, program
      [ "type Word = " <> kind
      , "fn identity(value: Word) -> Word { value }"
      , "fn inferred(value: Word) { value }"
      , "fn held(value: Word, marker: ()) -> Word { value }"
      , "fn early() -> Word { " <> literal family 3 <> " &+ { return 7 } }"
      , "fn main() -> Int {"
      , "  var value: Word = " <> number high
      , "  print(display(identity(value)))"
      , "  print(display(held(value, { value = 1\n print(\"mark\")\n () })))"
      , "  print(display(value))", "  var index = 0"
      , "  while index < 2 { value = value &- 1\n index = index + 1 }"
      , "  print(display(value))", "  print(display(loop { break inferred(value) }))"
      , "  print(display(value >> " <> number (toInteger (width - 1)) <> "))"
      , "  print(display(early()))"
      , "  print(display(identity(0x" <> Text.pack (showHex high "") <> suffix <> ")))"
      , "  print(display(identity(0o" <> Text.pack (showOct high "") <> suffix <> ")))"
      , "  print(display(identity(0b" <> Text.replicate width "1" <> suffix <> ")))"
      , "  return 0", "}"
      ], Text.unlines [number high, "mark", number high, "1", number high, number high,
           "1", "7", number high, number high, number high])
  ]
  where
    modulus = 2 ^ width
    high = modulus - 1
    half = 2 ^ (width - 1)
    values = [0, 1, 2, 3, half - 1, half, half + 1, high - 1, high]
      <> [(seed * 6364136223846793005 + 1442695040888963407) `mod` modulus | seed <- [1 .. 8]]
    pairs = [(0, high), (high, 1), (high, high), (0, 1), (high, 0), (half, half)]
      <> zip values (drop 5 (cycle values))
    within value | value >= 0 && value <= high = Just value
                 | otherwise = Nothing
    checked operation a b = within (operation a b)
    wrapped operation a b = Just (operation a b `mod` modulus)
    saturated operation a b = Just (max 0 (min high (operation a b)))
    operations =
      [ ("+", checked (+)), ("-", checked (-)), ("*", checked (*))
      , ("/", \a b -> if b == 0 then Nothing else Just (quot a b))
      , ("%", \a b -> if b == 0 then Nothing else Just (rem a b))
      , ("&+", wrapped (+)), ("&-", wrapped (-)), ("&*", wrapped (*))
      , ("+|", saturated (+)), ("-|", saturated (-)), ("*|", saturated (*))
      , ("&", wrapped (.&.)), ("|", wrapped (.|.)), ("^", wrapped xor)
      ]
    binaries = zip ["op" <> number index | index <- [0 ..]] operations
    declarations =
      ["fn " <> name <> "(a: " <> kind <> ", b: " <> kind <> ") -> " <> kind <> " { a " <> operator <> " b }"
      | (name, (operator, _)) <- binaries]
      <> [ "fn left(a: " <> kind <> ", count: Int) -> " <> kind <> " { a << count }"
         , "fn right(a: " <> kind <> ", count: Int) -> " <> kind <> " { a >> count }"
         , "fn invert(a: " <> kind <> ") -> " <> kind <> " { ~a }"
         , "fn negative(a: " <> kind <> ") -> " <> kind <> " { -a }"
         , "fn less(a: " <> kind <> ", b: " <> kind <> ") -> Bool { a < b }"
         , "fn equal(a: " <> kind <> ", b: " <> kind <> ") -> Bool { a == b }" ]
    cases =
      [(name <> "(" <> literal family a <> ", " <> literal family b <> ")", number answer)
      | (name, (_, operation)) <- binaries, (a, b) <- pairs, Just answer <- [operation a b]]
      <> [("invert(" <> literal family a <> ")", number (high - a)) | a <- values]
      <> [("negative(" <> literal family 0 <> ")", "0")]
      <> [(name <> "(" <> literal family a <> ", " <> number (toInteger count) <> ")", number (operation a count `mod` modulus))
         | (name, operation) <- [("left", shiftL), ("right", shiftR)], a <- values, count <- [0, 1, width - 1]]
      <> [(name <> "(" <> literal family a <> ", " <> literal family b <> ")", if answer a b then "true" else "false")
         | (name, answer) <- [("less", (<)), ("equal", (==))], (a, b) <- pairs]

failures :: Family -> [(String, Text)]
failures family@(kind, width, _) =
  [("unsigned failure " <> Text.unpack kind <> " " <> label, program
      [ "fn apply(a: " <> kind <> ", b: " <> kind <> ") -> " <> kind <> " { a " <> operator <> " b }"
      , "fn main() -> Int { print(\"before\")\n print(display(apply(" <> literal family a <> ", " <> literal family b <> ")))\n return 0 }"
      ]) | (label, operator, a, b) <-
       [("add", "+", high, 1), ("subtract", "-", 0, 1), ("multiply", "*", high, 2)
       , ("divide zero", "/", high, 0), ("remainder zero", "%", high, 0)]]
  <> [("unsigned shift failure " <> Text.unpack kind <> " " <> Text.unpack operator <> " " <> show count, program
      [ "fn apply(a: " <> kind <> ", count: Int) -> " <> kind <> " { a " <> operator <> " count }"
      , "fn main() -> Int { print(\"before\")\n print(display(apply(" <> literal family high <> ", " <> number (toInteger count) <> ")))\n return 0 }"
      ]) | operator <- ["<<", ">>"], count <- [-1, width]]
  <> [("unsigned negation failure " <> Text.unpack kind <> " " <> show value, program
      [ "fn negative(a: " <> kind <> ") -> " <> kind <> " { -a }"
      , "fn main() -> Int { print(\"before\")\n print(display(negative(" <> literal family value <> ")))\n return 0 }"
      ]) | value <- [1, high]]
  where
    high = 2 ^ width - 1

literal :: Family -> Integer -> Text
literal (_, _, suffix) value = "(" <> number value <> suffix <> ")"

number :: Integer -> Text
number = Text.pack . show

program :: [Text] -> Text
program linesOfSource = Text.unlines ("module Main" : linesOfSource)
