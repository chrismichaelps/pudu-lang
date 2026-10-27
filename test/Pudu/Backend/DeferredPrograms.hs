{-| @Test.Backend.DeferredPrograms — accepted integer intermediates beyond Int's result bounds. -}
module Pudu.Backend.DeferredPrograms (deferredSuccessPrograms, deferredRefusalPrograms) where

import Data.Bits ((.&.), (.|.), xor, complement, shiftL, shiftR)
import Data.Text (Text)
import qualified Data.Text as Text

low, high, boundary :: Integer
boundary = 2 ^ (63 :: Int)
low = negate boundary
high = boundary - 1

wrap :: Integer -> Integer
wrap value = (value - low) `mod` (2 * boundary) + low

clamp :: Integer -> Integer
clamp = max low . min high

fits :: Integer -> Maybe Integer
fits value | value >= low && value <= high = Just value
           | otherwise = Nothing

operators :: [(Text, Integer -> Integer -> Maybe Integer)]
operators =
  [ ("+", \a b -> fits (a + b)), ("-", \a b -> fits (a - b)), ("*", \a b -> fits (a * b))
  , ("/", \a b -> if b == 0 then Nothing else fits (quot a b))
  , ("%", \a b -> if b == 0 then Nothing else Just (rem a b))
  , ("&+", \a b -> Just (wrap (a + b))), ("&-", \a b -> Just (wrap (a - b)))
  , ("&*", \a b -> Just (wrap (a * b)))
  , ("+|", \a b -> Just (clamp (a + b))), ("-|", \a b -> Just (clamp (a - b)))
  , ("*|", \a b -> Just (clamp (a * b)))
  , ("&", \a b -> Just (wrap (a .&. b))), ("|", \a b -> Just (wrap (a .|. b)))
  , ("^", \a b -> Just (wrap (xor a b)))
  ]

deferredSuccessPrograms :: [(String, Text, Text)]
deferredSuccessPrograms = map matrix operators <> map comparison comparisons
  <> map shifts [("<<", shiftL), (">>", shiftR)] <>
  [ ("deferred block and local literal values", mainWith ["fn negate(a: Int) -> Int { -a }"]
      [ "print(display(value))", "print(display(minimum))"
      , "print(display(-{ 9223372036854775808 }))"
      , "print(display(~value))", "print(display(negate(value)))"
      ], Text.unlines (map decimal [boundary, low, low, complement low, low]))
  , ("deferred values retain calls, branches and loop slots", mainWith
      ["fn echo(a: Int) -> Int { a }"]
      [ "print(display(echo(value)))"
      , "let result = if value > 9223372036854775807 { value } else { 0 }"
      , "print(display(result))"
      , "let held = loop { break value }"
      , "print(display(held))"
      , "var index = 0"
      , "while index < 2 { print(display(echo(value)))"
      , "  index = index + 1 }"
      ], Text.unlines (replicate 5 (decimal boundary)))
  , ("deferred mutable values freeze before later operands", program
      [ "fn main() -> Int {"
      , "  var value = 9223372036854775808"
      , "  let minimum: Int = -value"
      , "  print(display(value &+ { value = 7"
      , "    value }))"
      , "  print(display(value))"
      , "  return 0"
      , "}"
      ], Text.unlines (map decimal [low + 7, 7]))
  , ("deferred values retain checked arithmetic in pure loops", mainWith []
      [ "var index = 0", "var total = 0"
      , "while index < 4 { total = value - 1"
      , "  index = index + 1 }"
      , "print(display(total))"
      ], decimal high <> "\n")
  , ("Never arguments preserve transfers without a dummy integer payload", program
      [ "fn choose(a: Int, b: Int) -> Int { print(\"called\")"
      , "  return a + b }"
      , "fn transfer() -> Int { return choose({ print(\"argument\")"
      , "  return 7 }, { print(\"skipped\")"
      , "  1 }) }"
      , "fn main() -> Int { print(display(transfer()))"
      , "  return 0 }"
      ], "argument\n7\n")
  ]
 where
  comparisons = [("<", (<)), ("<=", (<=)), (">", (>)), (">=", (>=)), ("==", (==)), ("!=", (/=))]

matrix :: (Text, Integer -> Integer -> Maybe Integer) -> (String, Text, Text)
matrix (operator, operation) =
  ( "deferred magnitude operator " <> Text.unpack operator
  , mainWith ["fn op(a: Int, b: Int) -> Int { a " <> operator <> " b }"]
      ["print(display(op(" <> argument a <> ", " <> argument b <> ")))" | (a, b, _) <- cases]
  , Text.unlines [decimal answer | (_, _, answer) <- cases]
  )
 where
  cases = [(a, b, answer) | a <- values, b <- values, Just answer <- [operation a b]]

comparison :: (Text, Integer -> Integer -> Bool) -> (String, Text, Text)
comparison (operator, operation) =
  ( "deferred magnitude comparison " <> Text.unpack operator
  , mainWith ["fn op(a: Int, b: Int) -> Bool { a " <> operator <> " b }"]
      ["print(display(op(" <> argument a <> ", " <> argument b <> ")))" | a <- values, b <- values]
  , Text.unlines [if operation a b then "true" else "false" | a <- values, b <- values]
  )

shifts :: (Text, Integer -> Int -> Integer) -> (String, Text, Text)
shifts (operator, operation) =
  ( "deferred magnitude shift " <> Text.unpack operator
  , mainWith ["fn op(a: Int, b: Int) -> Int { a " <> operator <> " b }"]
      ["print(display(op(" <> argument a <> ", " <> decimal (toInteger n) <> ")))" | a <- values, n <- counts]
  , Text.unlines [decimal (wrap (operation a n)) | a <- values, n <- counts]
  )
 where
  counts = [0, 1, 31, 32, 62, 63]

deferredRefusalPrograms :: [(String, Text)]
deferredRefusalPrograms =
  [ ("deferred checked result " <> Text.unpack expression, mainWith []
      ["print(display(value))", "let result = " <> expression, "print(display(result))"])
  | expression <- ["value + 0", "value - 0", "value * 1", "value / 1", "minimum / -1", "-minimum"]
  ] <>
  [ ("deferred shift count " <> Text.unpack expression, mainWith []
      ["print(display(value))", "let result = " <> expression, "print(display(result))"])
  | expression <- ["1 << value", "1 >> value", "1 << minimum", "1 >> minimum"]
  ] <>
  [ ("deferred division by zero", mainWith [] ["print(display(value))", "let result = value / 0", "print(display(result))"])
  , ("deferred remainder by zero", mainWith [] ["print(display(value))", "let result = value % 0", "print(display(result))"])
  ]

values :: [Integer]
values = [low, -1, 0, 1, high, boundary]

argument :: Integer -> Text
argument value | value == boundary = "value"
               | value == low = "minimum"
               | otherwise = decimal value

mainWith :: [Text] -> [Text] -> Text
mainWith helpers body = program (helpers <>
  ["fn main() -> Int {", "  let value = 9223372036854775808", "  let minimum: Int = -value"]
  <> map ("  " <>) body <> ["  return 0", "}"])

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

decimal :: Integer -> Text
decimal = Text.pack . show
