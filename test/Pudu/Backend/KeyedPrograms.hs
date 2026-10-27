{-| @Test.Backend.KeyedPrograms — maps and sets against `Eval.Keyed` and
    `Eval.Builtin.Collection`. -}
module Pudu.Backend.KeyedPrograms (keyedSuccessPrograms, keyedRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

keyedSuccessPrograms :: [(String, Text, Text)]
keyedSuccessPrograms =
  [ ("every map and set method, duplicates, keys of every shape, iteration and rendering", program
      [ "type Point = { x: Int, y: Int }", "type Shade = Dark | Light | Mid(Int)", ""
      , "fn main() -> Int {", "  let m = mapOf([(\"b\", 2), (\"a\", 1), (\"c\", 3), (\"a\", 10)])", "  print(show(m) + \" \" + display(m.size()) + \" \" + display(m.isEmpty()))"
      , "  print(show(m.get(\"a\")) + \" \" + show(m.get(\"z\")) + \" \" + display(m.containsKey(\"c\")) + \" \" + display(m.containsKey(\"q\")))", "  let m2 = m.insert(\"d\", 4).insert(\"b\", 20).remove(\"c\").remove(\"nope\")", "  print(show(m2) + \" \" + show(m))"
      , "  print(show(m.keys()) + \" \" + show(m.values()) + \" \" + show(m.entries()))", "  print(show(m.merge(mapOf([(\"a\", 100), (\"e\", 5)]))) + \" \" + show(mapOf([(\"x\", 0)]).merge(m)))", "  let empty: Map[Str, Int] = mapOf([])"
      , "  print(show(empty) + \" \" + display(empty.isEmpty()) + \" \" + show(empty.keys()) + \" \" + display(empty == mapOf([])))", "  print(display(m == mapOf([(\"c\", 3), (\"a\", 10), (\"b\", 2)])) + \" \" + display(m != m2))", "  for entry in m { print(entry[0] + \"=\" + display(entry[1])) }"
      , "  for (k, v) in m2 { print(k + \":\" + display(v)) }", "  let s = setOf([3, 1, 2, 3, 1])", "  let t = #{5, 3, 4}"
      , "  print(show(s) + \" \" + show(t) + \" \" + display(s.size()) + \" \" + display(s.contains(2)) + \" \" + display(s.contains(9)))", "  print(show(s.insert(0)) + \" \" + show(s.remove(1)) + \" \" + show(s.remove(7)) + \" \" + show(s.toArray()) + \" \" + show(s))", "  print(show(s.union(t)) + \" \" + show(s.intersect(t)) + \" \" + show(s.difference(t)) + \" \" + show(t.difference(s)))"
      , "  let none: Set[Int] = #{}", "  print(show(none) + \" \" + display(none.isEmpty()) + \" \" + show(none.union(s)) + \" \" + display(s == #{1, 2, 3}))", "  for n in s { print(display(n * 10)) }"
      , "  let points = mapOf([(Point{x: 2, y: 1}, \"b\"), (Point{x: 1, y: 5}, \"a\"), (Point{x: 1, y: 2}, \"c\")])", "  print(show(points))", "  let shades = setOf([Mid(2), Light, Dark, Mid(1)])"
      , "  print(show(shades))", "  let floats = mapOf([(0.0, \"zero\"), (-0.0, \"negzero\"), (1.5, \"x\")])", "  print(show(floats) + \" \" + display(floats.size()))"
      , "  let nested = mapOf([(1, #{\"x\"}), (2, #{\"y\", \"z\"})])", "  print(show(nested) + \" \" + show(nested.get(2)))", "  let tupled = (mapOf([(1, 2)]), 3)"
      , "  print(display(tupled < (mapOf([(1, 3)]), 0)) + \" \" + display((setOf([1]), 1) < (setOf([1, 2]), 0)) + \" \" + show(tupled))", "  let words = setOf([\"pear\", \"apple\", \"fig\"])", "  print(show(words) + show(mapOf([((1, \"b\"), 1), ((1, \"a\"), 2)])))"
      , "  return 0", "}" ]
    , "{\"a\": 10, \"b\": 2, \"c\": 3} 3 false\nSome(10) None true false\n{\"a\": 10, \"b\": 20, \"d\": 4} {\"a\": 10, \"b\": 2, \"c\": 3}\n[\"a\", \"b\", \"c\"] [10, 2, 3] [(\"a\", 10), (\"b\", 2), (\"c\", 3)]\n{\"a\": 100, \"b\": 2, \"c\": 3, \"e\": 5} {\"a\": 10, \"b\": 2, \"c\": 3, \"x\": 0}\n{} true [] true\ntrue true\na=10\nb=2\nc=3\na:10\nb:20\nd:4\n#{1, 2, 3} #{3, 4, 5} 3 true false\n#{0, 1, 2, 3} #{2, 3} #{1, 2, 3} [1, 2, 3] #{1, 2, 3}\n#{1, 2, 3, 4, 5} #{3} #{1, 2} #{4, 5}\n#{} true #{1, 2, 3} true\n10\n20\n30\n{Point{x: 1, y: 2}: \"c\", Point{x: 1, y: 5}: \"a\", Point{x: 2, y: 1}: \"b\"}\n#{Dark, Light, Mid(1), Mid(2)}\n{0.0: \"negzero\", 1.5: \"x\"} 2\n{1: #{\"x\"}, 2: #{\"y\", \"z\"}} Some(#{\"y\", \"z\"})\ntrue true ({1: 2}, 3)\n#{\"apple\", \"fig\", \"pear\"}{(1, \"a\"): 2, (1, \"b\"): 1}\n")
  , ("maps through records, parameters, references, copies and an entry result", program
      [ "type Inventory = { name: Str, stock: Map[Str, Int], tags: Set[Str] }", "", "fn restock(inventory: Inventory, item: Str, count: Int) -> Inventory {"
      , "  let current = match inventory.stock.get(item) {", "    case Some(n) => n", "    case None => 0"
      , "  }", "  Inventory{name: inventory.name, stock: inventory.stock.insert(item, current + count), tags: inventory.tags.insert(item)}", "}"
      , "", "fn total(stock: &Map[Str, Int]) -> Int {", "  var sum = 0"
      , "  for (_, n) in *stock { sum = sum + n }", "  sum", "}"
      , "", "fn counts(words: Array[Str]) -> Map[Str, Int] {", "  var seen: Map[Str, Int] = mapOf([])"
      , "  for word in words {", "    seen = match seen.get(word) {", "      case Some(n) => seen.insert(word, n + 1)"
      , "      case None => seen.insert(word, 1)", "    }", "  }"
      , "  seen", "}", ""
      , "fn main() -> Map[Str, Int] {", "  let start = Inventory{name: \"shop\", stock: mapOf([]), tags: #{}}", "  let one = restock(start, \"apple\", 3)"
      , "  let two = restock(restock(one, \"pear\", 2), \"apple\", 4)", "  print(show(start) + \" \" + show(one) + \" \" + show(two))", "  print(display(total(&two.stock)) + \" \" + display(one == two) + \" \" + display(one.stock == restock(start, \"apple\", 3).stock))"
      , "  let copies = [two.stock, two.stock.remove(\"apple\"), two.stock]", "  print(show(copies))", "  counts(\"the cat and the hat and the bat\".split(\" \"))"
      , "}" ]
    , "Inventory{name: \"shop\", stock: {}, tags: #{}} Inventory{name: \"shop\", stock: {\"apple\": 3}, tags: #{\"apple\"}} Inventory{name: \"shop\", stock: {\"apple\": 7, \"pear\": 2}, tags: #{\"apple\", \"pear\"}}\n9 false true\n[{\"apple\": 7, \"pear\": 2}, {\"pear\": 2}, {\"apple\": 7, \"pear\": 2}]\n{\"and\": 2, \"bat\": 1, \"cat\": 1, \"hat\": 1, \"the\": 3}\n")
  , ("thousands of inserts and removes keep the order and the counts", program
      [ "fn main() -> Int {", "  var m: Map[Int, Str] = mapOf([])", "  var i = 0"
      , "  while i < 3000 {", "    m = m.insert((i * 7919) % 3001, display(i))", "    i = i + 1"
      , "  }", "  let full = m", "  i = 0"
      , "  while i < 3000 {", "    if i % 3 != 1 { m = m.remove((i * 104729) % 3001) }", "    i = i + 1"
      , "  }", "  var keys = 0", "  for k in m.keys() { keys = keys + k }"
      , "  var s: Set[Int] = #{}", "  i = 3000", "  while i > 0 {"
      , "    s = s.insert(i % 997)", "    i = i - 1", "  }"
      , "  print(display(full.size()) + \" \" + display(m.size()) + \" \" + display(keys) + \" \" + display(s.size()) + \" \" + show(m.get(2)) + \" \" + show(full.get(0)))", "  print(show(m.keys().slice(0, 8)) + \" \" + show(s.toArray().slice(990, 997)))", "  return 0"
      , "}" ]
    , "3000 1001 1500704 997 None Some(\"0\")\n[3, 4, 7, 8, 11, 12, 16, 20] [990, 991, 992, 993, 994, 995, 996]\n")
  ]

keyedRefusalPrograms :: [(String, Text)]
keyedRefusalPrograms =
  [ ("a map key holding a function fails after the pairs are built", program
      [ "fn twice(n: Int) -> Int { n * 2 }", "", "fn main() -> Int {"
      , "  let handlers = mapOf([(1, twice), (2, |n| n + 1)])", "  print(display(handlers.size()))", "  let bad = mapOf([((1, twice), \"x\")])"
      , "  print(show(bad))", "  return 0", "}" ])
  , ("a set literal names a sum key by its variant", program
      [ "type Op = Apply(fn(Int) -> Int) | Skip", "", "fn main() -> Int {"
      , "  let ok = setOf([Skip])", "  print(display(ok.size()))", "  let bad = #{Skip, Apply(|n| n)}"
      , "  print(show(bad))", "  return 0", "}" ])
  , ("insert checks a record key", program
      [ "type Holder = { run: fn() -> Int }", "", "fn main() -> Int {"
      , "  let empty: Set[Holder] = setOf([])", "  print(display(empty.size()))", "  let grown = empty.insert(Holder{run: || 1})"
      , "  print(display(grown.size()))", "  return 0", "}" ])
  , ("insert checks an array key after a good one", program
      [ "fn main() -> Int {", "  let m: Map[Array[fn() -> Int], Int] = mapOf([])", "  print(\"start\")"
      , "  let n = m.insert([], 1)", "  print(show(n.size()))", "  let o = n.insert([|| 2], 2)"
      , "  print(show(o.size()))", "  return 0", "}" ])
  , ("maps holding functions compare equal but cannot be ordered", program
      [ "fn main() -> Int {", "  let f = |n: Int| n", "  let pairs = mapOf([(1, f)])"
      , "  print(display(pairs == mapOf([(1, f)])))", "  print(display((pairs, 1) < (pairs, 2)))", "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
