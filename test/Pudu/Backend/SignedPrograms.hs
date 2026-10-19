{-| @Test.Backend.SignedPrograms — declared widths with independent Integer answers. -}
module Pudu.Backend.SignedPrograms (signedSuccessPrograms, signedRefusalPrograms) where

import Data.Bits ((.&.), (.|.), xor, complement, shiftL, shiftR)
import Data.Text (Text)
import qualified Data.Text as Text

signedSuccessPrograms :: [(String, Text, Text)]
signedSuccessPrograms = concatMap successes [8, 16, 32, 64, 128]

signedRefusalPrograms :: [(String, Text)]
signedRefusalPrograms = concatMap failures [8, 16, 32, 64, 128]

successes :: Int -> [(String, Text, Text)]
successes width =
  [ ("signed matrix " <> show width, source declarations output, Text.unlines answers)
  , ("signed transfers and aliases " <> show width, program
      [ "type Tiny = " <> kind
      , "fn identity(value: Tiny) -> Tiny { value }"
      , "fn inferred(value: Tiny) { value }"
      , "fn early() -> Tiny { " <> literal width 3 <> " &+ { return 7 } }"
      , "fn main() -> Int {"
      , "  var value: Tiny = 1"
      , "  let held = loop { break identity(value) }"
      , "  print(display(inferred(held)))"
      , "  var count = 0"
      , "  while count < 3 { value = value &+ 1\n count = count + 1 }"
      , "  print(display(value))"
      , "  print(display(value + { value = 2\n value }))"
      , "  print(display(early()))"
      , "  print(display(0x1" <> suffix width <> "))"
      , "  print(display(0o2" <> suffix width <> "))"
      , "  print(display(0b11" <> suffix width <> "))"
      , "  return 0", "}"
      ], "1\n4\n6\n7\n1\n2\n3\n")
  , ("signed deferred boundary " <> show width, program
      [ "fn identity(value: " <> kind <> ") -> " <> kind <> " { value }"
      , "fn negative(value: " <> kind <> ") -> " <> kind <> " { -value }"
      , "fn before(value: " <> kind <> ") -> " <> kind <> " { value - 1 }"
      , "fn wrapped(value: " <> kind <> ") -> " <> kind <> " { value &+ 0 }"
      , "fn saturated(value: " <> kind <> ") -> " <> kind <> " { value +| 0 }"
      , "fn shifted(value: " <> kind <> ") -> " <> kind <> " { value >> 1 }"
      , "fn normalized(value: " <> kind <> ") -> " <> kind <> " { value >> 0 }"
      , "fn main() -> Int {"
      , "  let value = " <> number (negate low)
      , "  let minimum: " <> kind <> " = -value"
      , "  print(display(value))", "  print(display(minimum))"
      , "  print(display(identity(value)))"
      , "  print(display(if true { value } else { " <> literal width 0 <> " }))"
      , "  print(display(loop { break value }))"
      , "  print(display(negative(value)))"
      , "  print(display(before(value)))", "  print(display(wrapped(value)))"
      , "  print(display(saturated(value)))", "  print(display(shifted(value)))"
      , "  print(display(normalized(value)))", "  return 0", "}"
      ], Text.unlines (map number [negate low, low, negate low, negate low, negate low, low,
           high, low, high, negate low `quot` 2, low]))
  ]
  <> if width /= 128 then [] else
    [ ("signed wide mixed recursion and snapshots", program
        [ "type Wide = Int128"
        , "fn held(value: Wide, marker: ()) -> Wide { value }"
        , "fn recur(value: Wide, depth: Int) -> Wide {"
        , "  if depth == 0 { return value }", "  recur(value, depth - 1)", "}"
        , "fn unsigned(value: UInt128) -> UInt128 { value }"
        , "fn main() -> Int {", "  var value: Wide = " <> number low
        , "  let old = held(value, { value = " <> number high <> "\n print(\"mark\")\n () })"
        , "  print(display(old))", "  print(display(value))"
        , "  let selected = loop { if value > 0 { break recur(old, 40) }\n continue }"
        , "  print(display(selected))"
        , "  print(display(if false { return 0 } else { selected }))"
        , "  print(display(if true { selected }))"
        , "  print(display(unsigned(340282366920938463463374607431768211455u128)))"
        , "  return 0", "}"
        ], Text.unlines ["mark", number low, number high, number low, number low, "()", number (2^(128::Int)-1)])
    , ("signed wide deferred cross-word policies", program
        [ "fn pass(value: Int128) -> Int128 { value }", "fn main() -> Int {"
        , "  var value = " <> number (negate low), "  let minimum: Int128 = -value"
        , "  print(display(pass(value)))", "  print(display(minimum))"
        , "  print(display(value >> 0))", "  print(display(value >> 64))"
        , "  print(display(minimum >> 64))", "  print(display(minimum % -1i128))"
        , "  print(display(minimum &- 1i128))", "  print(display(minimum -| 1i128))"
        , "  print(display(340282366920938463463374607431768211455u128 >> 127))"
        , "  print(display(value - value))", "  print(display(value / -1i128))"
        , "  print(display(value % " <> literal width high <> "))"
        , "  print(display(value * 0))", "  print(display(~value))"
        , "  print(display(value > minimum))", "  print(display(value == minimum))"
        , "  return 0", "}"
        ], Text.unlines (map number [negate low, low, low, negate low `quot` 2^(64::Int), low `quot` 2^(64::Int),
              0, high, low, 1, 0, low, 1, 0, high] <> ["true", "false"]))
    , ("signed wide discarded local in unit entry", program
        [ "fn main() -> () {", "  let value: Int128 = " <> number high, "  ()", "}" ], "")
    ]
  where
    kind = typeName width
    (low, high) = bounds width
    values = [low, low + 1, -2, -1, 0, 1, 2, high - 1, high]
      <> map (wrap width . (\seed -> seed * 6364136223846793005 + 1442695040888963407)) [1 .. 8]
    pairs = [(low, low), (high, high), (low, -1), (high, 1), (low, high)]
      <> zip values (drop 7 (cycle values))
    operations =
      [ ("+", checked (+)), ("-", checked (-)), ("*", checked (*))
      , ("/", \a b -> if b == 0 then Nothing else within (quot a b))
      , ("%", \a b -> if b == 0 then Nothing else Just (rem a b))
      , ("&+", wrapped (+)), ("&-", wrapped (-)), ("&*", wrapped (*))
      , ("+|", saturated (+)), ("-|", saturated (-)), ("*|", saturated (*))
      , ("&", wrapped (.&.)), ("|", wrapped (.|.)), ("^", wrapped xor)
      ]
    checked operation a b = within (operation a b)
    within answer | answer >= low && answer <= high = Just answer
                  | otherwise = Nothing
    wrapped operation a b = Just (wrap width (operation a b))
    saturated operation a b = Just (max low (min high (operation a b)))
    names = ["op" <> number index | index <- [0 :: Integer ..]]
    binaries = zip names operations
    declarations =
      ["fn " <> name <> "(a: " <> kind <> ", b: " <> kind <> ") -> " <> kind <> " { a " <> operator <> " b }"
      | (name, (operator, _)) <- binaries]
      <> [ "fn left(a: " <> kind <> ", count: Int) -> " <> kind <> " { a << count }"
         , "fn right(a: " <> kind <> ", count: Int) -> " <> kind <> " { a >> count }"
         , "fn invert(a: " <> kind <> ") -> " <> kind <> " { ~a }"
         , "fn negative(a: " <> kind <> ") -> " <> kind <> " { -a }"
         , "fn less(a: " <> kind <> ", b: " <> kind <> ") -> Bool { a < b }"
         , "fn equal(a: " <> kind <> ", b: " <> kind <> ") -> Bool { a == b }"
         ]
    cases =
      [(name <> "(" <> literal width a <> ", " <> literal width b <> ")", number answer)
      | (name, (_, operation)) <- binaries, (a, b) <- pairs, Just answer <- [operation a b]]
      <> [("invert(" <> literal width a <> ")", number (wrap width (complement a))) | a <- values]
      <> [("negative(" <> literal width a <> ")", number (negate a)) | a <- values, a /= low]
      <> [(name <> "(" <> literal width a <> ", " <> number (toInteger count) <> ")", number (wrap width (operation a count)))
         | (name, operation) <- [("left", shiftL), ("right", shiftR)], a <- values, count <- [0, 1, width - 1]]
      <> [(name <> "(" <> literal width a <> ", " <> literal width b <> ")", if answer a b then "true" else "false")
         | (name, answer) <- [("less", (<)), ("equal", (==))], (a, b) <- pairs]
    (output, answers) = unzip cases

failures :: Int -> [(String, Text)]
failures width =
  [ ("signed failure " <> show width <> " " <> label, program
      [ "fn apply(a: " <> kind <> ", b: " <> kind <> ") -> " <> kind <> " { a " <> operator <> " b }"
      , "fn main() -> Int { print(\"before\")\n print(display(apply(" <> literal width a <> ", " <> literal width b <> ")))\n return 0 }"
      ])
  | (label, operator, a, b) <-
      [("add", "+", high, 1), ("subtract", "-", low, 1), ("multiply", "*", high, 2)
      , ("divide overflow", "/", low, -1), ("divide zero", "/", 1, 0), ("remainder zero", "%", 1, 0)]
  ]
  <> [("signed shift failure " <> show width <> " " <> Text.unpack operator <> " " <> show count, program
      [ "fn apply(a: " <> kind <> ", count: Int) -> " <> kind <> " { a " <> operator <> " count }"
      , "fn main() -> Int { print(\"before\")\n print(display(apply(" <> literal width (-1) <> ", " <> number (toInteger count) <> ")))\n return 0 }"
      ]) | operator <- ["<<", ">>"], count <- [-1, width]]
  <> [("signed negation overflow " <> show width, program
      [ "fn negative(a: " <> kind <> ") -> " <> kind <> " { -a }"
      , "fn main() -> Int { print(\"before\")\n print(display(negative(" <> literal width low <> ")))\n return 0 }"
      ])]
  <> [("signed deferred overflow " <> show width, program
      [ "fn checked(value: " <> kind <> ") -> " <> kind <> " { value + 0 }"
      , "fn main() -> Int {"
      , "  let value = " <> number (negate low)
      , "  let minimum: " <> kind <> " = -value"
      , "  print(display(minimum))", "  print(\"before\")"
      , "  print(display(checked(value)))", "  return 0", "}"
      ])]
  <> if width /= 128 then [] else
    [("signed wide recursion depth", program
      [ "fn recurse(value: Int128) -> Int128 { recurse(value) }"
      , "fn main() -> Int { print(\"before\")\n print(display(recurse(" <> literal width high <> ")))\n return 0 }"
      ])]
  where
    kind = typeName width
    (low, high) = bounds width

source :: [Text] -> [Text] -> Text
source declarations expressions = program (declarations <> ["fn main() -> Int {"]
  <> ["  print(display(" <> expression <> "))" | expression <- expressions] <> ["  return 0", "}"])

program :: [Text] -> Text
program linesOfSource = Text.unlines ("module Main" : linesOfSource)

typeName :: Int -> Text
typeName width = "Int" <> number (toInteger width)

suffix :: Int -> Text
suffix width = "i" <> number (toInteger width)

literal :: Int -> Integer -> Text
literal width value = "(" <> number value <> suffix width <> ")"

number :: Integer -> Text
number = Text.pack . show

bounds :: Int -> (Integer, Integer)
bounds width = (negate (2 ^ (width - 1)), 2 ^ (width - 1) - 1)

wrap :: Int -> Integer -> Integer
wrap width value = let (low, _) = bounds width in (value - low) `mod` (2 ^ width) + low
