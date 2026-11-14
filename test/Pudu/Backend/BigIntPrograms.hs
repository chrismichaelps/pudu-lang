{-| @Test.Backend.BigIntPrograms — BigInt values: exact arithmetic past every
    fixed width, truncating division, two's-complement bits, shifts,
    conversions and collections, with the interpreter's failures. -}
module Pudu.Backend.BigIntPrograms (bigIntSuccessPrograms, bigIntRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

bigIntSuccessPrograms :: [(String, Text, Text)]
bigIntSuccessPrograms =
  [ ("literals, arithmetic, recursion and conversion past 64 bits", program
      [ "fn fact(n: BigInt) -> BigInt {"
      , "  if n <= 1 { return 1 }"
      , "  n * fact(n - 1)"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  let big: BigInt = 123456789012345678901234567890"
      , "  print(show(big * big))"
      , "  print(display(fact(30)))"
      , "  print(display(-big / 7) + \" \" + display(-big % 7))"
      , "  print(display(big == big + 0) + \" \" + display(big < big + 1))"
      , "  let small: BigInt = 5"
      , "  print(show([small, big]))"
      , "  print(display(convertInteger[Int](small)))"
      , "  0"
      , "}" ]
    , "15241578753238836750495351562536198787501905199875019052100\n265252859812191058636308480000000\n-17636684144620811271604938270 0\ntrue true\n[5, 123456789012345678901234567890]\nSome(5)\n")
  , ("every operator on mixed signs, collections, patterns and conversions", program
      [ "type Account = { owner: Str, balance: BigInt }"
      , "type Amount = Exact(BigInt) | Missing"
      , ""
      , "fn power(base: BigInt, exponent: Int) -> BigInt {"
      , "  var result: BigInt = 1"
      , "  var count = 0"
      , "  while count < exponent {"
      , "    result = result * base"
      , "    count = count + 1"
      , "  }"
      , "  result"
      , "}"
      , ""
      , "fn describe(value: BigInt) -> Str {"
      , "  match value {"
      , "    case 0 => \"zero\""
      , "    case 1 => \"one\""
      , "    case 340282366920938463463374607431768211456 => \"two to the 128\""
      , "    case _ => if value < 0 { \"negative\" } else { \"other\" }"
      , "  }"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  let a: BigInt = 340282366920938463463374607431768211457"
      , "  let b: BigInt = -18446744073709551617"
      , "  print(display(a + b) + \" \" + display(a - b) + \" \" + display(a * b))"
      , "  print(display(a / b) + \" \" + display(a % b) + \" \" + display(b / 7) + \" \" + display(b % 7))"
      , "  print(display(-a / 3) + \" \" + display(-a % 3) + \" \" + display(a / -3) + \" \" + display(a % -3))"
      , "  print(display(a & b) + \" \" + display(a | b) + \" \" + display(a ^ b) + \" \" + display(~b))"
      , "  print(display(b >> 3) + \" \" + display(b << 70) + \" \" + display(a >> 200) + \" \" + display(b >> 200))"
      , "  print(display(a &+ b) + \" \" + display(a -| b) + \" \" + display(a *| b))"
      , "  print(display(power(2, 128)) + \" \" + describe(power(2, 128)) + \" \" + describe(b) + \" \" + describe(0))"
      , "  print(display(a == a) + display(a < b) + display(b <= b) + display(a > b) + display(a != b))"
      , "  let small: BigInt = 300"
      , "  print(show(convertInteger[UInt8](small)) + show(convertInteger[Int](small)) + show(convertInteger[Int128](a)) + show(convertInteger[UInt128](power(2, 128) - 1)))"
      , "  let wide: Int128 = -170141183460469231731687303715884105728"
      , "  let back = convertInteger[BigInt](wide)"
      , "  print(show(back) + \" \" + show(convertInteger[BigInt](255u8)) + show(convertInteger[Int64](b)))"
      , "  let accounts = [Account{owner: \"x\", balance: a}, Account{owner: \"y\", balance: b}]"
      , "  print(show(accounts))"
      , "  print(show(Exact(b)) + \" \" + show(Missing))"
      , "  var totals = mapOf([(\"big\", a), (\"small\", b)])"
      , "  totals = totals.insert(\"zero\", 0)"
      , "  print(show(totals))"
      , "  let keyed = setOf([b, a, b, 0, power(2, 64)])"
      , "  print(show(keyed))"
      , "  var sum: BigInt = 0"
      , "  for item in [a, b, power(10, 30)] { sum = sum + item }"
      , "  print(display(sum) + \" \" + show((a, b)))"
      , "  let triple = |value: BigInt| value * 3"
      , "  print(display(triple(b)))"
      , "  0"
      , "}" ]
    , "340282366920938463444927863358058659840 340282366920938463481821351505477763074 -6277101735386680764176071790128604879584176795969512275969\n-18446744073709551615 2 -2635249153387078802 -3\n-113427455640312821154458202477256070485 -2 -113427455640312821154458202477256070485 2\n340282366920938463463374607431768211457 -18446744073709551617 -340282366920938463481821351505477763074 18446744073709551616\n-2305843009213693953 -21778071482940061662836566496350576836608 0 -1\n340282366920938463444927863358058659840 340282366920938463481821351505477763074 -6277101735386680764176071790128604879584176795969512275969\n340282366920938463463374607431768211456 two to the 128 negative zero\ntruefalsetruetruetrue\nNoneSome(300)NoneSome(340282366920938463463374607431768211455)\nSome(-170141183460469231731687303715884105728) Some(255)None\n[Account{owner: \"x\", balance: 340282366920938463463374607431768211457}, Account{owner: \"y\", balance: -18446744073709551617}]\nExact(-18446744073709551617) Missing\n{\"big\": 340282366920938463463374607431768211457, \"small\": -18446744073709551617, \"zero\": 0}\n#{-18446744073709551617, 0, 18446744073709551616, 340282366920938463463374607431768211457}\n340282367920938463444927863358058659840 (340282366920938463463374607431768211457, -18446744073709551617)\n-55340232221128654851\n")
  , ("factorials, Fibonacci and wide shifts stay exact", program
      [ "fn fact(n: BigInt) -> BigInt {"
      , "  if n <= 1 { return 1 }"
      , "  n * fact(n - 1)"
      , "}"
      , ""
      , "fn digits(value: BigInt) -> Int { display(value).length() }"
      , ""
      , "fn main() -> Int {"
      , "  let big = fact(300)"
      , "  print(display(digits(big)) + \" \" + display(big % 1000000007) + \" \" + display(big / fact(298)))"
      , "  var fib: (BigInt, BigInt) = (0, 1)"
      , "  var index = 0"
      , "  while index < 400 {"
      , "    let (low, high) = fib"
      , "    fib = (high, low + high)"
      , "    index = index + 1"
      , "  }"
      , "  let (answer, _) = fib"
      , "  print(display(answer))"
      , "  var bits: BigInt = 1"
      , "  bits = bits << 1000"
      , "  print(display(((bits - 1) & (bits >> 500)) == (bits >> 500) - 1))"
      , "  print(show([fact(25), -fact(26), 0, fact(27) / -fact(26)]))"
      , "  0"
      , "}" ]
    , "615 419467694 89700\n176023680645013966468226945392411250770384383304492191886725992896575345044216019675\nfalse\n[15511210043330985984000000, -403291461126605635584000000, 0, -27]\n")
  ]

bigIntRefusalPrograms :: [(String, Text)]
bigIntRefusalPrograms =
  [ ("division by zero after an exact quotient", program
      [ "fn main() -> Int {"
      , "  let a: BigInt = 340282366920938463463374607431768211457"
      , "  let zero: BigInt = 0"
      , "  print(display(a / 3))"
      , "  print(display(a / zero))"
      , "  0"
      , "}" ])
  , ("a remainder by zero takes the dividend's sign first", program
      [ "fn main() -> Int {"
      , "  let a: BigInt = -340282366920938463463374607431768211457"
      , "  let zero: BigInt = 0"
      , "  print(display(a % 7))"
      , "  print(display(a % zero))"
      , "  0"
      , "}" ])
  , ("a negative shift count is refused", program
      [ "fn main() -> Int {"
      , "  let a: BigInt = 12345678901234567890123"
      , "  let count = -2"
      , "  print(display(a << 2))"
      , "  print(display(a >> count))"
      , "  0"
      , "}" ])
  , ("an entry BigInt above 255 exits with 255", program
      [ "fn main() -> BigInt {"
      , "  let a: BigInt = 340282366920938463463374607431768211457"
      , "  print(display(a))"
      , "  a"
      , "}" ])
  , ("a negative entry BigInt exits with 1", program
      [ "fn main() -> BigInt {"
      , "  let a: BigInt = -5"
      , "  a * 2"
      , "}" ])
  ]

program :: [Text] -> Text
program lines' = Text.unlines (["module Main", ""] <> lines')
