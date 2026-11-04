{-| @Test.Backend.FloatPrograms — Float32/Float64 source programs with independent answers. -}
module Pudu.Backend.FloatPrograms (floatSuccessPrograms, floatRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text
import GHC.Float (double2Float, float2Double)

floatSuccessPrograms :: [(String, Text, Text)]
floatSuccessPrograms =
  [ ("float literals keep their parsed encodings", program
      [ "fn main() -> Int {"
      , "  print(display(0.1))", "  print(display(-0.0))", "  print(display(1.0e7))"
      , "  print(display(0.1e7))", "  print(display(1.0e-2))", "  print(display(0.1f32))"
      , "  print(display(5.0e-324))", "  print(display(1.7976931348623157e308))"
      , "  print(display(3.4028235e38f32))", "  print(display(1.0e-45f32))"
      , "  print(display(1_000.5))", "  let f: Float = 2.5", "  print(display(f))"
      , "  return 0", "}" ]
    , lines' (map show [0.1, -0.0, 1.0e7, 0.1e7, 1.0e-2, widen 0.1, 5.0e-324, 1.7976931348623157e308 :: Double]
        <> [show (widen 3.4028235e38), show (widen 1.0e-45), "1000.5", "2.5"]))
  , ("binary64 arithmetic rounds per operation", program
      [ "fn main() -> Int {"
      , "  print(display(0.1 + 0.2))", "  print(display(1.0 - 0.9))", "  print(display(0.1 * 3.0))"
      , "  print(display(1.0 / 3.0))", "  print(display(1.0 / 0.0))", "  print(display(-1.0 / 0.0))"
      , "  print(display(0.0 / 0.0))", "  print(display(-(0.0 / 0.0)))", "  print(display(1.0e308 * 10.0))"
      , "  print(display(-(0.0)))", "  print(display(0.0 - 0.0))", "  print(display(-0.0 + 0.0))"
      , "  print(display(1.0e16 + 1.0 - 1.0e16))"
      , "  return 0", "}" ]
    , lines' (map show
        [ at (+) 0.1 0.2, at (-) 1.0 0.9, at (*) 0.1 3.0, at (/) 1.0 3.0, at (/) 1 0, at (/) (-1) 0, nan
        , negate nan, at (*) 1.0e308 10.0, negate 0.0, at (-) 0.0 0.0, at (+) (-0.0) 0.0
        , at (-) (at (+) 1.0e16 1.0) 1.0e16 ]))
  , ("binary32 arithmetic narrows every result", program
      [ "fn main() -> Int {"
      , "  print(display(0.1f32 + 0.2f32))", "  print(display(1.0f32 / 3.0f32))"
      , "  print(display(16777216.0f32 + 1.0f32))", "  print(display(3.0e38f32 * 2.0f32))"
      , "  print(display(1.0e-45f32 / 2.0f32))", "  print(display(0.1f32 * 0.1f32 * 0.1f32))"
      , "  let x: Float32 = 1.1f32", "  print(display(x - 1.0f32))"
      , "  return 0", "}" ]
    , lines' (map (show . widen)
        [ f32 (+) (n 0.1) (n 0.2), f32 (/) 1 3, f32 (+) 16777216 1, f32 (*) (n 3.0e38) 2
        , f32 (/) (n 1.0e-45) 2, f32 (*) (f32 (*) (n 0.1) (n 0.1)) (n 0.1), f32 (-) (n 1.1) 1 ]))
  , ("float comparisons follow IEEE predicates", program
      [ "fn main() -> Int {"
      , "  let nan = 0.0 / 0.0"
      , "  print(display(nan == nan))", "  print(display(nan != nan))", "  print(display(nan < 1.0))"
      , "  print(display(nan >= nan))", "  print(display(0.0 == -0.0))", "  print(display(-0.0 < 0.0))"
      , "  print(display(1.5 <= 1.5))", "  print(display(2.0 > 1.0))", "  print(display(0.1f32 == 0.1f32))"
      , "  print(display(1.0 / 0.0 > 1.7976931348623157e308))"
      , "  return 0", "}" ]
    , lines' ["false", "true", "false", "false", "true", "false", "true", "true", "true", "true"])
  , ("floats travel through locals calls branches and loops", program
      [ "fn half(x: Float64) -> Float64 { x / 2.0 }"
      , "fn narrow(x: Float32, marker: ()) -> Float32 { x * 3.0f32 }"
      , "fn main() -> Int {"
      , "  var total = 0.0"
      , "  var index = 0"
      , "  while index < 10 {"
      , "    total = total + 0.1"
      , "    index = index + 1"
      , "  }"
      , "  print(display(total))"
      , "  print(display(half(total)))"
      , "  var y = 0.1f32"
      , "  print(display(narrow(y, { y = 2.0f32 })))"
      , "  print(display(y))"
      , "  let picked = if total > 0.5 { total } else { -total }"
      , "  print(display(picked))"
      , "  let found = loop { break 4.25f32 }"
      , "  print(display(found))"
      , "  return 0", "}" ]
    , lines' [ show tenth, show (at (/) tenth 2), show (widen (f32 (*) (n 0.1) 3)), show (widen 2.0), show tenth, "4.25" ])
  , ("float entry results render and exit zero", program
      [ "fn main() -> Float { 0.1 + 0.2 }" ]
    , lines' [show (0.1 + 0.2 :: Double)])
  , ("float32 entry results render widened", program
      [ "fn main() -> Float32 { 0.1f32 }" ]
    , lines' [show (widen 0.1)])
  , ("bool entry results render and exit zero", program
      [ "fn main() -> Bool { 1.5 < 2.5 }" ]
    , "true\n")
  ]
 where
  tenth = iterate (at (+) 0.1) 0 !! 10
  nan = at (/) 0 0
  n = id :: Float -> Float
  f32 :: (Double -> Double -> Double) -> Float -> Float -> Float
  f32 op a b = narrow (at op (widen a) (widen b))

{-| Each run is held to the interpreter rather than an answer: these print a
    runtime diagnostic, so the comparison is the rendered stderr itself. -}
floatRefusalPrograms :: [(String, Text)]
floatRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() {", "  print(\"start\")", "  let x = " <> expression, "  print(display(x))", "}" ])
  | (label, expression) <-
      [ ("float remainder", "1.5 % 2.0"), ("float bit and", "1.5 & 2.0"), ("float bit or", "1.5 | 2.0")
      , ("float xor", "1.5 ^ 2.0"), ("float wrapping add", "1.5 &+ 2.0"), ("float saturating multiply", "1.5 *| 2.0")
      , ("float shift", "1.5 << 2"), ("float complement", "~1.5"), ("float32 remainder", "1.5f32 % 2.0f32") ]
  ] <>
  [ ("float operands finish before unsupported operators fail", program
      [ "fn main() {"
      , "  print(\"before\")"
      , "  let x = { print(\"left\")"
      , "    1.5 } % { print(\"right\")"
      , "    2.0 }"
      , "  print(display(x))"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

lines' :: [String] -> Text
lines' = Text.pack . concatMap (<> "\n")

{-| Width conversions kept out of the optimizer's reach. At -O2 GHC folds
    float2Double of a literal Float into the Double literal, which turned the
    expected 0.1f32 into 0.1. -}
widen :: Float -> Double
widen = float2Double
{-# NOINLINE widen #-}

narrow :: Double -> Float
narrow = double2Float
{-# NOINLINE narrow #-}

{-| One binary64 operation the optimizer cannot rewrite; at -O2 GHC turns
    `-0.0 + 0.0` into `-0.0`, which is not what IEEE addition answers. -}
at :: (Double -> Double -> Double) -> Double -> Double -> Double
at op a b = op a b
{-# NOINLINE at #-}
