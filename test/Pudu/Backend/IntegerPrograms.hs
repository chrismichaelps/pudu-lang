{-| @Test.Backend.IntegerPrograms — fixed-width boundaries with independent mathematical answers. -}
module Pudu.Backend.IntegerPrograms (integerSuccessPrograms, integerRefusalPrograms) where

import Data.Bits ((.&.), (.|.), xor, complement, shiftL, shiftR)
import Pudu.Backend.DeferredPrograms (deferredSuccessPrograms, deferredRefusalPrograms)
import Data.Text (Text)
import qualified Data.Text as Text

integerSuccessPrograms :: [(String, Text, Text)]
integerSuccessPrograms = deferredSuccessPrograms <> map binaryMatrix operators <> map isolatedBinary operators <> [complementMatrix]
  <> [("isolated complement", program ["fn main() -> Int { print(display(~0))", "  return 0 }"], "-1\n")]
  <> map shiftMatrix [("<<", shiftL), (">>", shiftR)]
  <> [("integer operands freeze before mutation", program
      [ "fn main() -> Int {"
      , "  var n = 8"
      , "  print(display(n >> { n = 2"
      , "    n }))"
      , "  print(display(n &+ { n = 7"
      , "    n }))"
      , "  print(display(n *| { n = 3"
      , "    n }))"
      , "  print(display(~{ print(\"complement\")"
      , "    n }))"
      , "  print(display(false && (1 << -1) == 0))"
      , "  print(display(true || (1 >> 64) == 0))"
      , "  return 0"
      , "}"
      ], "2\n9\n21\ncomplement\n-4\nfalse\ntrue\n")
     , ("integer Never operands preserve transfers", program
      [ "fn early() -> Int { 3 &+ { return 7 } }"
      , "fn shifted() -> Int { { return 9 } >> { print(\"skipped\")"
      , "    -1 } }"
      , "fn unary() -> Int { ~{ return 11 } }"
      , "fn main() -> Int {"
      , "  print(display(early()))"
      , "  print(display(shifted()))"
      , "  print(display(unary()))"
      , "  return 0"
      , "}"
      ], "7\n9\n11\n")]

operators :: [(Text, Integer -> Integer -> Integer)]
operators =
  [ ("&", (.&.)), ("|", (.|.)), ("^", xor)
  , ("&+", \a b -> wrap (a + b)), ("&-", \a b -> wrap (a - b)), ("&*", \a b -> wrap (a * b))
  , ("+|", \a b -> clamp (a + b)), ("-|", \a b -> clamp (a - b)), ("*|", \a b -> clamp (a * b))
  ]

low, high, modulus :: Integer
modulus = 2 ^ (64 :: Int)
low = negate (2 ^ (63 :: Int))
high = 2 ^ (63 :: Int) - 1

wrap :: Integer -> Integer
wrap n = (n - low) `mod` modulus + low

clamp :: Integer -> Integer
clamp = max low . min high

numbers :: [Integer]
numbers = [low, low + 1, -3037000500, -2, -1, 0, 1, 2, 3037000500, high - 1, high]

samples :: [(Integer, Integer)]
samples = zip words64 (drop 1 words64)
 where
  words64 = map wrap (take 33 (iterate (\n -> (6364136223846793005 * n + 1442695040888963407) `mod` modulus) 495))

binaryMatrix :: (Text, Integer -> Integer -> Integer) -> (String, Text, Text)
binaryMatrix (operator, operation) =
  ( "platform Int matrix " <> Text.unpack operator
  , program (["fn op(a: Int, b: Int) -> Int { a " <> operator <> " b }", "fn main() -> Int {"]
      <> ["  print(display(op(" <> decimal a <> ", " <> decimal b <> ")))" | (a, b) <- pairs]
      <> ["  return 0", "}"])
  , Text.unlines [decimal (operation a b) | (a, b) <- pairs]
  )
 where
  pairs = [(a, b) | a <- numbers, b <- numbers] <> samples

isolatedBinary :: (Text, Integer -> Integer -> Integer) -> (String, Text, Text)
isolatedBinary (operator, operation) =
  ( "isolated integer helper " <> Text.unpack operator
  , program ["fn main() -> Int { print(display(-7 " <> operator <> " 3))", "  return 0 }"]
  , decimal (operation (-7) 3) <> "\n"
  )

complementMatrix :: (String, Text, Text)
complementMatrix =
  ( "platform Int complement matrix"
  , program (["fn op(a: Int) -> Int { ~a }", "fn main() -> Int {"]
      <> ["  print(display(op(" <> decimal a <> ")))" | a <- values]
      <> ["  return 0", "}"])
  , Text.unlines [decimal (complement a) | a <- values]
  )
 where
  values = numbers <> map fst samples

shiftMatrix :: (Text, Integer -> Int -> Integer) -> (String, Text, Text)
shiftMatrix (operator, operation) =
  ( "platform Int shift matrix " <> Text.unpack operator
  , program (["fn op(a: Int, b: Int) -> Int { a " <> operator <> " b }", "fn main() -> Int {"]
      <> ["  print(display(op(" <> decimal a <> ", " <> decimal (toInteger count) <> ")))" | (a, count) <- pairs]
      <> ["  return 0", "}"])
  , Text.unlines [decimal (wrap (operation a count)) | (a, count) <- pairs]
  )
 where
  pairs = [(a, count) | a <- numbers <> map fst samples, count <- [0, 1, 31, 32, 62, 63]]

integerRefusalPrograms :: [(String, Text)]
integerRefusalPrograms = deferredRefusalPrograms <>
  [ ("invalid shift " <> Text.unpack operator <> " " <> show count, program
      [ "fn op(a: Int, b: Int) -> Int { a " <> operator <> " b }"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  return op(-1, " <> decimal count <> ")"
      , "}"
      ])
  | operator <- ["<<", ">>"], count <- [-1, low, 64, high]
  ] <>
  [ ("shift operand effects before refusal", program
      [ "fn first() -> Int { print(\"left\")"
      , "  return -1 }"
      , "fn second() -> Int { print(\"right\")"
      , "  return 64 }"
      , "fn main() -> Int { return first() >> second() }"
      ])
  , ("operand failure precedes invalid shift count", program
      [ "fn first() -> Int { print(\"left\")"
      , "  return 1 / 0 }"
      , "fn main() -> Int { return first() << -1 }"
      ])
  , ("literal minimum still overflows when negated through a parameter", program
      [ "fn negate(value: Int) -> Int { -value }"
      , "fn main() -> Int { return negate(-9223372036854775808) }"
      ])
  , ("macro shift span", program
      [ "macro invalid() = 1 << -1"
      , "fn main() -> Int { return invalid!() }"
      ])
  , ("Unicode and tabbed shift span", program
      [ "fn λ() -> Int {"
      , "\treturn 1 >> 64"
      , "}"
      , "fn main() -> Int { return λ() }"
      ])
  ]

decimal :: Integer -> Text
decimal = Text.pack . show

program :: [Text] -> Text
program linesValue = Text.unlines (["module Main", ""] <> linesValue)
