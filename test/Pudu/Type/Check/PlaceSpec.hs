{-| @Test.Type.Check.PlaceSpec — writable places, lending with &mut, and where an exclusive reference may be written -}
module Pudu.Type.Check.PlaceSpec
  ( testPlaces
  ) where

import Data.List (sort)
import Data.Text (Text)
import Pudu.Type.Check.Common (codes)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

counterProgram :: [Text]
counterProgram =
  [ "module M"
  , "type Tally = { mut count: Int, label: Str }"
  , "type Pair = { mut left: Int, mut right: Int }"
  , "trait Tick { fn tick(self: &mut Self) -> () }"
  , "impl Tick for Tally { fn tick(self: &mut Self) -> () { self.count = self.count + 1 } }"
  , "fn bump(n: &mut Int) -> () { *n = *n + 1 }"
  , "fn both(left: &mut Int, right: &mut Int) -> () { *left = *right }"
  , "fn whole(pair: &mut Pair, part: &mut Int) -> () { *part = pair.left }"
  ]

with :: [Text] -> IO [Text]
with body = sort <$> codes (counterProgram <> body)

testPlaces :: IO Property
testPlaces = do
  variable <- with ["fn run() -> Int {", "  var n = 1", "  n = 2", "  n", "}"]
  field <- with ["fn run() -> Int {", "  var t = Tally{count: 1, label: \"a\"}", "  t.count = 2", "  t.count", "}"]
  element <- with ["fn run() -> Int {", "  var items = [1, 2]", "  items[0] = 5", "  items[0]", "}"]
  throughParameter <- with ["fn set(t: &mut Tally) -> () {", "  t.count = 3", "  *t = Tally{count: 0, label: \"b\"}", "}"]
  method <- with ["fn run() -> Int {", "  var t = Tally{count: 1, label: \"a\"}", "  t.tick()", "  Tick.tick(&mut t)", "  t.count", "}"]
  lendOn <- with ["fn twice(n: &mut Int) -> () {", "  bump(n)", "  bump(n)", "}"]
  disjoint <- with ["fn run() -> Int {", "  var p = Pair{left: 1, right: 2}", "  both(&mut p.left, &mut p.right)", "  p.left", "}"]
  functionValue <- with ["fn run() -> Int {", "  var n = 1", "  let f = bump", "  f(&mut n)", "  n", "}"]
  letWrite <- with ["fn run() -> Int {", "  let n = 1", "  n = 2", "  n", "}"]
  parameterWrite <- with ["fn run(n: Int) -> Int {", "  n = 2", "  n", "}"]
  patternWrite <- with ["fn run() -> () {", "  for x in [1, 2] { x = 3 }", "}"]
  immutableField <- with ["fn run() -> Str {", "  var t = Tally{count: 1, label: \"a\"}", "  t.label = \"b\"", "  t.label", "}"]
  sharedField <- with ["fn set(t: &Tally) -> () { t.count = 1 }"]
  sharedDeref <- with ["fn set(n: &Int) -> () { *n = 1 }"]
  textElement <- with ["fn run() -> () {", "  var s = \"ab\"", "  s[0] = 'c'", "}"]
  computed <- with ["fn make() -> Tally { Tally{count: 0, label: \"m\"} }", "fn run() -> () { make().count = 1 }"]
  keptBorrow <- with ["fn run() -> () {", "  var n = 1", "  let r = &mut n", "}"]
  answered <- with ["fn run(n: &mut Int) -> &mut Int { n }"]
  inField <- with ["type Held = { value: &mut Int }"]
  inArgument <- with ["fn run(value: Option[&mut Int]) -> () { }"]
  asynchronous <- with ["async fn run(n: &mut Int) -> () { *n = 1 }"]
  bound <- with ["fn run(n: &mut Int) -> () {", "  let r = n", "}"]
  captured <- with ["fn run(n: &mut Int) -> Int {", "  let read = fn() -> Int { *n }", "  read()", "}"]
  sameTwice <- with ["fn run() -> () {", "  var x = 1", "  both(&mut x, &mut x)", "}"]
  inside <- with ["fn run() -> () {", "  var p = Pair{left: 1, right: 2}", "  whole(&mut p, &mut p.left)", "}"]
  letReceiver <- with ["fn run() -> () {", "  let t = Tally{count: 1, label: \"a\"}", "  t.tick()", "}"]
  letLent <- with ["fn run() -> () {", "  let x = 1", "  bump(&mut x)", "}"]
  generic <- with ["fn keep[T](value: T) -> () { }", "fn run() -> () {", "  var x = 1", "  keep(&mut x)", "}"]
  pure $ conjoin
    [ counterexample "a var is assigned" (variable === [])
    , counterexample "a mut field of a var is assigned" (field === [])
    , counterexample "an element of a var array is assigned" (element === [])
    , counterexample "a &mut parameter's field and referent are assigned" (throughParameter === [])
    , counterexample "a &mut self method changes a var receiver" (method === [])
    , counterexample "an exclusive reference is lent on by name" (lendOn === [])
    , counterexample "two different fields are lent to one call" (disjoint === [])
    , counterexample "a function taking &mut is an ordinary value" (functionValue === [])
    , counterexample "a let cannot be assigned" (letWrite === ["E3078"])
    , counterexample "a parameter cannot be assigned" (parameterWrite === ["E3078"])
    , counterexample "a pattern binding cannot be assigned" (patternWrite === ["E3078"])
    , counterexample "a field not declared mut cannot be assigned" (immutableField === ["E3079"])
    , counterexample "nothing is written through a shared reference's field" (sharedField === ["E3080"])
    , counterexample "nothing is written through a shared reference" (sharedDeref === ["E3080"])
    , counterexample "a character of text is not a place" (textElement === ["E3077"])
    , counterexample "a computed value is not a place" (computed === ["E3077"])
    , counterexample "a borrow is not kept in a binding" (keptBorrow === ["E3081", "E3084"])
    , counterexample "a function does not answer &mut" (answered === ["E3083"])
    , counterexample "a field is not &mut" (inField === ["E3083"])
    , counterexample "a type argument is not &mut" (inArgument === ["E3083"])
    , counterexample "an async function does not take &mut" (asynchronous === ["E3083"])
    , counterexample "a binding does not hold an exclusive parameter" (bound === ["E3084"])
    , counterexample "a closure does not capture an exclusive parameter" (captured === ["E3084"])
    , counterexample "one place is not lent twice" (sameTwice === ["E3082"])
    , counterexample "a place is not lent beside what holds it" (inside === ["E3082"])
    , counterexample "a let receiver is not changed by a method" (letReceiver === ["E3078"])
    , counterexample "a let is not lent" (letLent === ["E3078"])
    , counterexample "an exclusive reference does not become a type argument" (generic === ["E3084"])
    ]
