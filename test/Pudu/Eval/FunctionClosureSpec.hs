{-| @Test.Eval.FunctionClosureSpec — evaluation of functions, closures, defaults, and trait implementations -}
module Pudu.Eval.FunctionClosureSpec
  ( functionClosureProperties
  , testBuiltinImpls
  , testDecimalImpls
  , testClosures
  , testFunctions
  , testSlotScopes
  ) where

import Test.QuickCheck (Property, conjoin, counterexample, (===))

import Pudu.Eval.Common (evaluate, evaluateWith, runProgram)

functionClosureProperties :: [(String, IO Property)]
functionClosureProperties =
  [ ("functions defaults and recursion evaluate", testFunctions)
  , ("function literals capture the environment they were written in", testClosures)
  , ("implementations reach built-in types", testBuiltinImpls)
  , ("Decimal implementations reach direct generic and qualified calls", testDecimalImpls)
  , ("slot admission preserves ordered lexical scope and capture", testSlotScopes)
  ]

testSlotScopes :: IO Property
testSlotScopes = do
  initializer <- captured
    ["let value = value + 1", "value"]
  before <- captured
    ["let result = value", "let value = 99", "result"]
  after <- captured
    ["{ let value = 9\n value }", "value"]
  earlyCapture <- captured
    ["let read = fn() -> Int => value", "let value = 9", "read()"]
  shorthand <- runProgram ["type Point = { value: Int }"]
    [ "let value = 5"
    , "let read = fn() -> Int {"
    , "  let initial = Point{value}"
    , "  let value = 9"
    , "  initial.value", "}"
    ] "read()"
  branch <- captured
    [ "var marker = 0"
    , "if let Some(value) = Some(9) { marker = value }"
    , "value + marker"
    ]
  arm <- captured
    [ "let marker = 0"
    , "match Some(9) { case Some(value) => value + marker case None => marker }"
    , "value"
    ]
  condition <- captured
    [ "var count = 0"
    , "while count < value { let value = 0\n count = count + 1 }"
    , "count"
    ]
  overflow <- runProgram []
    [ "let value = 255u8"
    , "let read = fn() -> UInt8 { let value = value + 1u8\n value }"
    ] "read()"
  snapshot <- runProgram []
    [ "var value = 5"
    , "let read = fn() -> Int => value"
    , "value = 9"
    ] "read()"
  nestedWrite <- runProgram []
    [ "var value = 5"
    , "{ let marker = 1\n value = value + marker }"
    ] "value"
  pure $ conjoin
    [ counterexample "initializer reads the captured binding" (initializer === "6")
    , counterexample "a later declaration cannot redirect an earlier read" (before === "5")
    , counterexample "nested scope restores the outer binding" (after === "5")
    , counterexample "capture precedes the later local binding" (earlyCapture === "5")
    , counterexample "shorthand fields read the current lexical binding" (shorthand === "5")
    , counterexample "successful pattern bindings end with their branch" (branch === "14")
    , counterexample "match arm bindings end with their arm" (arm === "5")
    , counterexample "loop condition cannot read a body-local slot" (condition === "5")
    , counterexample "fallback retains checked arithmetic diagnostics" (overflow === "failed: E7005")
    , counterexample "capture holds a snapshot before later local mutation" (snapshot === "5")
    , counterexample "a nested frame writes the existing parent binding" (nestedWrite === "6")
    ]
 where
  captured body = runProgram []
    (["let value = 5", "let read = fn() -> Int {"] <> body <> ["}"]) "read()"

testFunctions :: IO Property
testFunctions = do
  direct <- evaluateWith ["fn double(n: Int) -> Int { n * 2 }"] "double(21)"
  defaulted <- evaluateWith ["fn greet(name: Str, mark: Str = \"!\") -> Str { name + mark }"] "greet(\"pudu\")"
  chained <- evaluateWith
    [ "fn add(a: Int, b: Int) -> Int { a + b }"
    , "fn quadruple(n: Int) -> Int { add(n, n) + add(n, n) }"
    ]
    "quadruple(4)"
  recursive <- evaluateWith
    [ "fn factorial(n: Int) -> Int {"
    , "  if n <= 1 {"
    , "    1"
    , "  } else {"
    , "    n * factorial(n - 1)"
    , "  }"
    , "}"
    ]
    "factorial(6)"
  expressionBody <- evaluateWith ["fn triple(n: Int) -> Int = n * 3"] "triple(5)"
  pure $ conjoin
    [ direct === "42"
    , counterexample "a default fills a missing argument" (defaulted === "\"pudu!\"")
    , chained === "16"
    , recursive === "720"
    , expressionBody === "15"
    ]

testClosures :: IO Property
testClosures = do
  captured <- evaluateWith
    [ "fn adder(step: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + step }"
    ]
    "adder(10)(5)"
  independent <- runProgram
    [ "fn adder(step: Int) -> fn(Int) -> Int { fn(n: Int) -> Int => n + step }"
    ]
    [ "let addTen = adder(10)"
    , "let addOne = adder(1)"
    ]
    "addTen(5) + addOne(5)"
  passed <- evaluateWith
    [ "fn apply(f: fn(Int) -> Int, n: Int) -> Int { f(n) }" ]
    "apply(fn(x) => x * 3, 7)"
  overLocal <- runProgram [] ["let base = 100", "let shift = fn(x: Int) -> Int => x + base"] "shift(1)"
  inMap <- evaluate "[1, 2, 3].map(fn(n) => n * 10)"
  pure $ conjoin
    [ counterexample "a literal keeps the value it closed over" (captured === "15")
    , counterexample "two literals do not share one capture" (independent === "21")
    , counterexample "a literal is an ordinary argument" (passed === "21")
    , counterexample "a literal sees the block it was written in" (overLocal === "101")
    , counterexample "a literal drives a built-in method" (inMap === "[10, 20, 30]")
    ]

testBuiltinImpls :: IO Property
testBuiltinImpls = do
  onInteger <- evaluateWith
    [ "trait Doubling { fn twice(self: &Self) -> Self }"
    , "impl Doubling for Int { fn twice(self: &Self) -> Self { *self + *self } }"
    ]
    "21.twice()"
  onText <- evaluateWith
    [ "trait Shouting { fn shout(self: &Self) -> Str }"
    , "impl Shouting for Str { fn shout(self: &Self) -> Str { *self + \"!\" } }"
    ]
    "\"hi\".shout()"
  onArray <- evaluateWith
    [ "trait Counting { fn twice(self: &Self) -> Int }"
    , "impl Counting for Array { fn twice(self: &Self) -> Int { 2 } }"
    ]
    "[1, 2].twice()"
  builtinStillWins <- evaluate "[1, 2, 3].length()"
  generic <- evaluateWith
    [ "trait Ranking { fn before(self: &Self, other: &Self) -> Bool }"
    , "impl Ranking for Int { fn before(self: &Self, other: &Self) -> Bool { *self < *other } }"
    , "fn smallest[T: Ranking](items: &Array[T]) -> Option[T] {"
    , "  if items.length() == 0 { None } else {"
    , "    var best = items[0]"
    , "    for item in items { if item.before(&best) { best = item } }"
    , "    Some(best)"
    , "  }"
    , "}"
    ]
    "smallest(&[3, 1, 2])"
  onOption <- evaluateWith
    [ "trait Named { fn label(self: &Self) -> Int }"
    , "impl Named for Option[Int] { fn label(self: &Self) -> Int { 7 } }"
    ]
    "Some(1).label()"
  onAbsent <- evaluateWith
    [ "trait Named { fn label(self: &Self) -> Int }"
    , "impl Named for Option[Int] { fn label(self: &Self) -> Int { 7 } }"
    ]
    "None.label()"
  onResult <- evaluateWith
    [ "trait Named { fn label(self: &Self) -> Int }"
    , "impl Named for Result[Int, Str] { fn label(self: &Self) -> Int { 9 } }"
    ]
    "Err(\"x\").label()"
  onUserSum <- evaluateWith
    [ "type Colour = Red | Green"
    , "trait Named { fn label(self: &Self) -> Int }"
    , "impl Named for Colour { fn label(self: &Self) -> Int { 5 } }"
    ]
    "Green.label()"
  pure $ conjoin
    [ counterexample "an implementation for Int is reachable" (onInteger === "42")
    , counterexample "an implementation for Str is reachable" (onText === "\"hi!\"")
    , counterexample "an implementation for Array is reachable" (onArray === "2")
    , counterexample "a built-in method still wins its own name" (builtinStillWins === "3")
    , counterexample "a bounded generic works over a built-in type"
        (generic === "Some(1)")
    , counterexample "an implementation for Option is reachable from a variant"
        (onOption === "7")
    , counterexample "and from the variant carrying nothing" (onAbsent === "7")
    , counterexample "an implementation for Result is reachable" (onResult === "9")
    , counterexample "a program's own sum is reachable the same way"
        (onUserSum === "5")
    ]


testDecimalImpls :: IO Property
testDecimalImpls = do
  let declarations =
        [ "trait Doubling { fn twice(self: &Self) -> Self }"
        , "impl Doubling for Decimal { fn twice(self: &Self) -> Self { *self + *self } }"
        , "fn doubled[T: Doubling](value: T) -> T { value.twice() }"
        ]
  direct <- evaluateWith declarations "2.50d.twice()"
  generic <- evaluateWith declarations "doubled(-2.50d)"
  qualified <- evaluateWith declarations "Doubling.twice(&2.50d)"
  ownerQualified <- evaluateWith declarations "Decimal.twice(&2.50d)"
  missing <- evaluateWith declarations "2.50d.missing()"
  rendered <- evaluate "2.50d.toText()"
  pure $ conjoin
    [ counterexample "direct dispatch retains Decimal arithmetic and scale" (direct === "5.00")
    , counterexample "bounded generic dispatch handles negative Decimal values" (generic === "-5.00")
    , counterexample "trait qualification uses the same Decimal owner" (qualified === "5.00")
    , counterexample "type qualification reaches the registered implementation" (ownerQualified === "5.00")
    , counterexample "an absent member is still refused" (missing === "failed: E3005")
    , counterexample "universal rendering remains the fallback" (rendered === "\"2.50\"")
    ]
