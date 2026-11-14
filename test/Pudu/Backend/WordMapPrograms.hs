{-| @Test.Backend.WordMapPrograms — sparse word operations and persistent ownership. -}
module Pudu.Backend.WordMapPrograms (wordMapSuccessPrograms, wordMapRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

wordMapSuccessPrograms :: [(String, Text, Text)]
wordMapSuccessPrograms = algebraSuccessPrograms <> querySuccessPrograms

algebraSuccessPrograms :: [(String, Text, Text)]
algebraSuccessPrograms =
  [ ("all word operations, high bits, zero elision and persistent inputs", program
      [ "fn main() -> Int {"
      , "  let left = mapOf([(\"a\", 1u64), (\"b\", 3u64), (\"zero\", 0u64)])"
      , "  let right = mapOf([(\"b\", 6u64), (\"c\", 8u64)])"
      , "  print(show(wordMapUnion(left, right)))"
      , "  print(show(wordMapIntersection(left, right)))"
      , "  print(show(wordMapDifference(left, right)))"
      , "  print(show(wordMapSymmetricDifference(left, right)))"
      , "  let empty: Map[Str, UInt64] = mapOf([])"
      , "  print(show(wordMapUnion[Str](empty, left)) + show(wordMapIntersection(left, empty)))"
      , "  let a = mapOf([(1, 18446744073709551615u64)])"
      , "  let b = mapOf([(1, 9223372036854775808u64)])"
      , "  print(show(wordMapDifference(a, b)) + show(wordMapUnion(a, b)) + show(wordMapSymmetricDifference(a, a)))"
      , "  print(show(left) + show(right))"
      , "  0", "}" ]
    , "{\"a\": 1, \"b\": 7, \"c\": 8}\n{\"b\": 2}\n{\"a\": 1, \"b\": 1}\n{\"a\": 1, \"b\": 5, \"c\": 8}\n{\"a\": 1, \"b\": 3}{}\n{1: 9223372036854775807}{1: 18446744073709551615}{}\n{\"a\": 1, \"b\": 3, \"zero\": 0}{\"b\": 6, \"c\": 8}\n")
  , ("word-map values, captured calls, representatives and source order", program
      [ "fn data(label: Str, word: UInt64) -> Map[Str, UInt64] { print(label)\n mapOf([(\"x\", word)]) }"
      , "fn capture(f: fn(Map[Str, UInt64], Map[Str, UInt64]) -> Map[Str, UInt64]) { |a, b| f(a, b) }"
      , "fn main() -> Int {"
      , "  let unite: fn(Map[Str, UInt64], Map[Str, UInt64]) -> Map[Str, UInt64] = wordMapUnion"
      , "  let intersect = wordMapIntersection"
      , "  let difference = wordMapDifference"
      , "  let symmetric = wordMapSymmetricDifference"
      , "  let a = mapOf([(\"x\", 3u64)])"
      , "  let b = mapOf([(\"x\", 6u64)])"
      , "  print(show(capture(unite)(data(\"left\", 3u64), data(\"right\", 6u64))))"
      , "  print(show(intersect(a, b)) + show(difference(a, b)) + show(symmetric(a, b)))"
      , "  print(show(unite) + \" \" + display(unite == wordMapUnion))"
      , "  let floats = wordMapUnion(mapOf([(-0.0, 1u64)]), mapOf([(0.0, 2u64)]))"
      , "  print(show(floats))"
      , "  let tuples = wordMapUnion(mapOf([((\"a\", 1), 1u64)]), mapOf([((\"a\", 1), 4u64)]))"
      , "  print(show(tuples))"
      , "  let nan = 0.0 / 0.0"
      , "  print(show(wordMapUnion(mapOf([(nan, 1u64)]), mapOf([(nan, 2u64)]))))"
      , "  var snapshot = mapOf([(\"x\", 1u64)])"
      , "  print(show(wordMapUnion(snapshot, { snapshot = snapshot.insert(\"x\", 2u64)\n snapshot })))"
      , "  unite(data(\"before transfer\", 1u64), { return 0 })"
      , "  1", "}" ]
    , "left\nright\n{\"x\": 7}\n{\"x\": 2}{\"x\": 1}{\"x\": 5}\n<builtin wordMapUnion> true\n{-0.0: 3}\n{(\"a\", 1): 5}\n{NaN: 3}\n{\"x\": 3}\nbefore transfer\n")
  , ("large merged trees retain balanced updates and owned key cleanup", program
      [ "fn main() -> Int {"
      , "  var a: Map[Str, UInt64] = mapOf([])"
      , "  var b: Map[Str, UInt64] = mapOf([])"
      , "  for index in 0..1000 { a = a.insert(display(index), 1u64)\n b = b.insert(display(index), 2u64) }"
      , "  var joined = wordMapUnion(a, b)"
      , "  joined = joined.insert(\"extra\", 4u64).remove(\"0\")"
      , "  print(display(joined.size()) + \" \" + show(joined.get(\"500\")) + \" \" + display(a.size()))"
      , "  0", "}" ]
    , "1000 Some(3) 1000\n") ]

wordMapRefusalPrograms :: [(String, Text)]
wordMapRefusalPrograms = algebraRefusalPrograms <> queryRefusalPrograms

algebraRefusalPrograms :: [(String, Text)]
algebraRefusalPrograms =
  [ ("word-map argument failure stops later effects", program
      [ "fn main() -> Int {"
      , "  let unite = wordMapUnion"
      , "  let n = 0"
      , "  print(show(unite(mapOf([(\"x\", 1u64)]), { print(\"failure\")\n let bad = 1 / n\n mapOf([(\"later\", 2u64)]) })))"
      , "  0", "}" ])
  , ("word-map builtin entry retains tag rendering", program
      [ "fn main() -> fn(Map[Str, UInt64], Map[Str, UInt64]) -> Map[Str, UInt64] { wordMapUnion }" ]) ]


querySuccessPrograms :: [(String, Text, Text)]
querySuccessPrograms =
  [ ("word queries preserve empty, zero, high bits and UInt128 counts", program
      [ "fn main() -> Int {"
      , "  let empty: Map[Str, UInt64] = mapOf([])"
      , "  let zero = mapOf([(\"absent\", 0u64)])"
      , "  let a = mapOf([(\"x\", 3u64), (\"y\", 9223372036854775808u64)])"
      , "  let b = mapOf([(\"x\", 7u64), (\"y\", 9223372036854775808u64), (\"extra\", 1u64)])"
      , "  print(show(wordMapIsSubsetOf(empty, a)) + show(wordMapIsSubsetOf(zero, empty)))"
      , "  print(show(wordMapIsSubsetOf(a, b)) + show(wordMapIsSubsetOf(b, a)))"
      , "  print(show(wordMapIsDisjointFrom(empty, a)) + show(wordMapIsDisjointFrom(a, zero)))"
      , "  print(show(wordMapIsDisjointFrom(a, b)) + show(wordMapIsDisjointFrom(mapOf([(\"x\", 1u64)]), mapOf([(\"x\", 2u64)]))))"
      , "  let full = mapOf([(\"a\", 18446744073709551615u64), (\"b\", 9223372036854775808u64), (\"c\", 0u64)])"
      , "  let count: UInt128 = wordMapPopCount(full)"
      , "  print(show(wordMapPopCount(empty)) + \" \" + show(count) + \" \" + show(count + 1u128) + \" \" + show(count + 18446744073709551551u128))"
      , "  print(show(a) + show(b))"
      , "  0", "}" ]
    , "truetrue\ntruefalse\ntruetrue\nfalsetrue\n0 65 66 18446744073709551616\n{\"x\": 3, \"y\": 9223372036854775808}{\"extra\": 1, \"x\": 7, \"y\": 9223372036854775808}\n")
  , ("word members retain chunk order, wrapped identifiers and duplicates", program
      [ "fn main() -> Int {"
      , "  let chunks = mapOf([(18446744073709551615u64, 9223372036854775809u64), (288230376151711744u64, 1u64), (1u64, 9223372036854775808u64), (0u64, 3u64), (2u64, 0u64)])"
      , "  let members: Array[UInt64] = wordMapMembers(chunks)"
      , "  print(show(members))"
      , "  print(show(wordMapPopCount(chunks)) + \" \" + show(members[5] &+ 1u64))"
      , "  let empty: Map[UInt64, UInt64] = mapOf([])"
      , "  print(show(wordMapMembers(empty)) + show(wordMapMembers(mapOf([(1u64, 0u64)]))))"
      , "  print(display(wordMapMembers(mapOf([(0u64, 18446744073709551615u64)])).length()))"
      , "  0", "}" ]
    , "[0, 1, 127, 0, 18446744073709551552, 18446744073709551615]\n6 0\n[][]\n64\n")
  , ("query values, generics, owned keys and operand snapshots", program
      [ "fn generic[K](a: Map[K, UInt64], b: Map[K, UInt64]) -> Bool { wordMapIsSubsetOf[K](a, b) }"
      , "fn genericCount[K](value: Map[K, UInt64]) -> UInt128 { wordMapPopCount[K](value) }"
      , "fn genericDisjoint[K](a: Map[K, UInt64], b: Map[K, UInt64]) -> Bool { wordMapIsDisjointFrom[K](a, b) }"
      , "fn capture(f: fn(Map[Str, UInt64], Map[Str, UInt64]) -> Bool) { |a, b| f(a, b) }"
      , "fn countCapture(f: fn(Map[Str, UInt64]) -> UInt128) { |a| f(a) }"
      , "fn data(label: Str, word: UInt64) -> Map[Str, UInt64] { print(label)\n mapOf([(\"x\", word)]) }"
      , "fn main() -> Int {"
      , "  let subset: fn(Map[Str, UInt64], Map[Str, UInt64]) -> Bool = wordMapIsSubsetOf"
      , "  let disjoint = wordMapIsDisjointFrom"
      , "  let count: fn(Map[Str, UInt64]) -> UInt128 = wordMapPopCount"
      , "  let members: fn(Map[UInt64, UInt64]) -> Array[UInt64] = wordMapMembers"
      , "  print(show(capture(disjoint)(data(\"left\", 1u64), data(\"right\", 2u64))))"
      , "  print(show(subset) + \" \" + show(disjoint) + \" \" + show(count) + \" \" + show(members))"
      , "  print(show(subset == wordMapIsSubsetOf) + show(subset == disjoint))"
      , "  print(show(countCapture(count)(mapOf([(\"x\", 7u64)]))) + show(members(mapOf([(0u64, 2u64)]))))"
      , "  let tuple = mapOf([((\"owned\", 1), 3u64)])"
      , "  print(show(generic(tuple, tuple)) + show(genericCount(tuple)))"
      , "  let unused: Map[(Str, Int), UInt64] = mapOf([])"
      , "  if !genericDisjoint(tuple, unused) { panic(\"generic query\") }"
      , "  let nan = 0.0 / 0.0"
      , "  print(show(wordMapIsSubsetOf(mapOf([(nan, 1u64)]), mapOf([(nan, 3u64)]))))"
      , "  var held = mapOf([(\"x\", 3u64)])"
      , "  print(show(subset(held, { held = held.insert(\"x\", 1u64)\n held })))"
      , "  print(show(disjoint(held, { held = held.insert(\"x\", 2u64)\n held })))"
      , "  subset(data(\"before transfer\", 1u64), { return 0 })"
      , "  1", "}" ]
    , "left\nright\ntrue\n<builtin wordMapIsSubsetOf> <builtin wordMapIsDisjointFrom> <builtin wordMapPopCount> <builtin wordMapMembers>\ntruefalse\n3[1]\ntrue2\ntrue\nfalse\ntrue\nbefore transfer\n")
  , ("unary query transfer ends before the later effect", program
      [ "fn main() -> Int { wordMapPopCount({ return 0 })\n print(\"unreachable\")\n 1 }" ], "")
  , ("direct predicate transfer skips its later operand", program
      [ "fn later() -> Map[Str, UInt64] { print(\"unreachable\")\n mapOf([]) }"
      , "fn main() -> Int { wordMapIsSubsetOf({ print(\"transfer\")\n return 0 }, later())\n 1 }" ], "transfer\n")
  , ("a source declaration keeps a query builtin spelling", program
      [ "fn wordMapPopCount(value: Int) -> Int { value + 1 }"
      , "fn main() -> Int { print(display(wordMapPopCount(2)))\n 0 }" ], "3\n")
  ]

queryRefusalPrograms :: [(String, Text)]
queryRefusalPrograms =
  [ ("query unary argument failure retains the call path", program
      [ "fn main() -> Int { let count = wordMapPopCount\n let n = 0"
      , "  print(show(count({ print(\"failure\")\n let bad = 1 / n\n mapOf([(\"x\", 1u64)]) })))\n 0 }" ])
  , ("member query argument failure retains provenance", program
      [ "fn main() -> Int { let members = wordMapMembers\n let n = 0"
      , "  print(show(members({ print(\"failure\")\n let bad = 1 / n\n mapOf([(0u64, 1u64)]) })))\n 0 }" ])
  , ("query binary first argument failure skips the right effect", program
      [ "fn later() -> Map[Str, UInt64] { print(\"unreachable\")\n mapOf([(\"x\", 1u64)]) }"
      , "fn main() -> Int { let predicate = wordMapIsSubsetOf\n let n = 0"
      , "  print(show(predicate({ print(\"failure\")\n let bad = 1 / n\n mapOf([(\"x\", 1u64)]) }, later())))\n 0 }" ])
  , ("query binary second argument failure retains eager left effects", program
      [ "fn main() -> Int { let n = 0"
      , "  print(show(wordMapIsDisjointFrom({ print(\"left\")\n mapOf([(\"x\", 1u64)]) }, { print(\"failure\")\n let bad = 1 / n\n mapOf([(\"x\", 2u64)]) })))\n 0 }" ])
  ] <> [ ("query builtin entry " <> Text.unpack name, program ["fn main() -> " <> signature <> " { " <> name <> " }"])
       | (name, signature) <-
          [("wordMapIsSubsetOf", "fn(Map[Str, UInt64], Map[Str, UInt64]) -> Bool")
          ,("wordMapIsDisjointFrom", "fn(Map[Str, UInt64], Map[Str, UInt64]) -> Bool")
          ,("wordMapPopCount", "fn(Map[Str, UInt64]) -> UInt128")
          ,("wordMapMembers", "fn(Map[UInt64, UInt64]) -> Array[UInt64]")] ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
