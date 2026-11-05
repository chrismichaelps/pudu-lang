{-| @Test.Backend.WordMapPrograms — sparse word algebra and persistent ownership. -}
module Pudu.Backend.WordMapPrograms (wordMapSuccessPrograms, wordMapRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

wordMapSuccessPrograms :: [(String, Text, Text)]
wordMapSuccessPrograms =
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
wordMapRefusalPrograms =
  [ ("word-map argument failure stops later effects", program
      [ "fn main() -> Int {"
      , "  let unite = wordMapUnion"
      , "  let n = 0"
      , "  print(show(unite(mapOf([(\"x\", 1u64)]), { print(\"failure\")\n let bad = 1 / n\n mapOf([(\"later\", 2u64)]) })))"
      , "  0", "}" ])
  , ("word-map builtin entry retains tag rendering", program
      [ "fn main() -> fn(Map[Str, UInt64], Map[Str, UInt64]) -> Map[Str, UInt64] { wordMapUnion }" ]) ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
