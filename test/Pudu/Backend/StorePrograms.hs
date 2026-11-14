{-| @Test.Backend.StorePrograms — indexed stores, hashing and the MultiMap
    primitives. No program prints a mixed hash: its seed differs per process. -}
module Pudu.Backend.StorePrograms (storeSuccessPrograms, storeModulePrograms, storeRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| Programs of one module, which the counted-allocation harness also runs. -}
storeSuccessPrograms :: [(String, Text, Text)]
storeSuccessPrograms =
  [ ( "store methods, persistence, equality and rendering", program
      [ "fn main() -> Int {"
      , "  let empty: Buckets[Str] = bucketsOf()"
      , "  let one = empty.insert(3, \"c\").insert(-1, \"a\").insert(3, \"d\")"
      , "  print(show(one) + \" \" + show(empty) + \" \" + display(one.size()))"
      , "  print(show(one.get(3)) + show(one.get(9)) + show(one.remove(3)) + show(one.keys()) + show(one.values()))"
      , "  print(display(one == one.insert(3, \"d\")) + display(one.isEmpty()) + one.toText())"
      , "  print(display(mixHash(1) == mixHash(1)))"
      , "  0"
      , "}" ]
    , "#[-1: \"a\", 3: \"d\"] #[] 2\nSome(\"d\")None#[-1: \"a\"][-1, 3][\"a\", \"d\"]\ntruefalse#[-1: \"a\", 3: \"d\"]\ntrue\n" )
  , ( "owned payloads, method values, builtin identity, nesting, ordering and transfers", program
      [ "type Tag = { name: Str, weight: Float }"
      , ""
      , "fn label(store: &Buckets[Tag], index: Int) -> Str {"
      , "  match store.get(index) { case Some(found) => found.name"
      , "    case None => \"none\" }"
      , "}"
      , ""
      , "fn noisy(text: Str, value: Int) -> Int { print(text)"
      , "  value }"
      , ""
      , "fn early(store: &Buckets[Tag]) -> Int {"
      , "  store.insert({ return 4 }, Tag{name: \"never\", weight: 0.0})"
      , "  1"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  let base: Buckets[Tag] = bucketsOf()"
      , "  let one = base.insert(noisy(\"key\", 2), Tag{name: \"two\", weight: 2.5})"
      , "  let two = one.insert(-5, Tag{name: \"minus\", weight: -1.0}).insert(2, Tag{name: \"again\", weight: 0.5})"
      , "  print(label(&one, 2) + label(&two, 2) + label(&two, 3) + show(two))"
      , "  let getter = two.get"
      , "  let sizer = two.size"
      , "  let inserter = one.insert"
      , "  print(show(getter(-5)) + display(sizer()) + show(getter) + show(inserter(9, Tag{name: \"nine\", weight: 9.0}).keys()))"
      , "  let make: fn() -> Buckets[Int] = bucketsOf"
      , "  let mix = mixHash"
      , "  print(show(make) + show(mix) + display(mix(3) == mixHash(3)) + show(make().insert(1, 1)))"
      , "  let nested: Buckets[Buckets[Str]] = bucketsOf()"
      , "  let filled = nested.insert(1, bucketsOf().insert(4, \"deep\")).insert(0, bucketsOf())"
      , "  print(show(filled) + display(filled == filled.remove(7)) + display(filled == filled.remove(0)) + display(filled.remove(0).remove(1).isEmpty()))"
      , "  let left: Buckets[Int] = bucketsOf().insert(1, 5)"
      , "  let right: Buckets[Int] = bucketsOf().insert(1, 6)"
      , "  let ordered = setOf([right, left, left.insert(0, 9)])"
      , "  print(show(ordered) + show(mapOf([(left, \"l\")]).get(left)))"
      , "  print(show(two.remove(noisy(\"gone\", 2)).values()) + two.toText().length().toText())"
      , "  print(display(early(&two)))"
      , "  0"
      , "}" ]
    , "key\ntwoagainnone#[-5: Tag{name: \"minus\", weight: -1.0}, 2: Tag{name: \"again\", weight: 0.5}]\nSome(Tag{name: \"minus\", weight: -1.0})2<store method get>[2, 9]\n<builtin bucketsOf><builtin mixHash>true#[1: 1]\n#[0: #[], 1: #[4: \"deep\"]]truefalsetrue\n#{#[0: 9, 1: 5], #[1: 5], #[1: 6]}Some(\"l\")\ngone\n[Tag{name: \"minus\", weight: -1.0}]75\n4\n" )
  , ( "hash indexes address stores through one narrowed word", program
      [ "fn main() -> Int {"
      , "  print(display(mixHash(7) == mixHash(7)) + display(mixHash(7) >= 0))"
      , "  var store: Buckets[Int] = bucketsOf()"
      , "  for index in 0..64 { store = store.insert(mixHash(index), index) }"
      , "  var sum = 0"
      , "  for index in 0..64 { sum = sum + (match store.get(mixHash(index)) { case Some(found) => found"
      , " case None => -1000 }) }"
      , "  var inside = true"
      , "  for key in store.keys() { if key > 9223372036854775807 { inside = false } }"
      , "  print(display(sum) + \" \" + display(store.size()) + \" \" + display(inside))"
      , "  0"
      , "}" ]
    , "truetrue\n2016 64 true\n" )
  , ( "hashOf over text, bytes, every integer carrier and rendered values", program
      [ "type Point = { x: Int, y: Float }"
      , ""
      , "fn main() -> Int {"
      , "  let big: BigInt = 123456789012345678901234567890123456789012345678901234567890"
      , "  let zero: BigInt = 0"
      , "  let small: BigInt = -7"
      , "  print(display(hashOf(\"\")) + \" \" + display(hashOf(\"a\")) + \" \" + display(hashOf(\"héllo ☃ 😀\")))"
      , "  print(display(hashOf(0)) + \" \" + display(hashOf(1)) + \" \" + display(hashOf(-1)) + \" \" + display(hashOf(256)) + \" \" + display(hashOf(-9223372036854775807 - 1)))"
      , "  print(display(hashOf(255u8)) + \" \" + display(hashOf(-128i8)) + \" \" + display(hashOf(18446744073709551615u64)))"
      , "  print(display(hashOf(340282366920938463463374607431768211455u128)) + \" \" + display(hashOf(-170141183460469231731687303715884105727i128)) + \" \" + display(hashOf(5i128)))"
      , "  print(display(hashOf(big)) + \" \" + display(hashOf(zero)) + \" \" + display(hashOf(small)))"
      , "  print(display(hashOf(bytesOf([1u8, 2u8, 255u8]))) + \" \" + display(hashOf(true)) + \" \" + display(hashOf('x')) + \" \" + display(hashOf(1.5)))"
      , "  print(display(hashOf(Point{x: 1, y: 2.0})) + \" \" + display(hashOf((1, \"a\"))) + \" \" + display(hashOf([1, 2])) + \" \" + display(hashOf(Some(3))) + \" \" + display(hashOf(1.25d)))"
      , "  let hash: fn(Str) -> Int = hashOf"
      , "  print(show(hash) + display(hash(\"a\") == hashOf(\"a\")) + display(hashOf(()) ))"
      , "  0"
      , "}" ]
    , "14695981039346656037 12638187200555641996 1699901058373058668\n590684067820433389 589727492704079044 589728592215707255 15034026112158478604 11182209195435569548\n763824163880569834 713124583202161338 2883527373169393575\n16703625864492730479 7431698849526133308 585901192238661664\n12565564692628723607 590684067820433389 587815441982998565\n15036127278879611375 6583304908937478053 12190245936731474311 5007220036841904057\n13462018947360223847 15622364235942202314 14519949274529468440 2803447575218988163 4747177672756761147\n<builtin hashOf>true567769145981429338\n" )
  , ( "folded store constants project through the store carrier", program
      [ "const STORE: Buckets[Str] = bucketsOf().insert(4, \"four\").insert(-2, \"minus\")"
      , "const SEEDLESS: Int = STORE.size()"
      , ""
      , "fn main() -> Int {"
      , "  print(show(STORE) + display(SEEDLESS) + show(STORE.get(4)))"
      , "  0"
      , "}" ]
    , "#[-2: \"minus\", 4: \"four\"]2Some(\"four\")\n" )
  , ( "large stores keep earlier versions and release removed payloads", program
      [ "fn main() -> Int {"
      , "  var store: Buckets[Str] = bucketsOf()"
      , "  for index in 0..1000 { store = store.insert(index * 7 - 3000, \"v\" + display(index)) }"
      , "  let kept = store"
      , "  for index in 0..500 { store = store.remove(index * 14 - 3000) }"
      , "  store = store.insert(4, \"x\").insert(4, \"y\").remove(123456)"
      , "  print(display(kept.size()) + \" \" + display(store.size()) + \" \" + show(store.get(4)) + show(store.get(-3000)) + show(kept.get(-3000)) + show(store.get(-2993)))"
      , "  let keys = store.keys()"
      , "  print(display(keys[0]) + \" \" + display(keys[499]) + \" \" + display(store.values().length()) + \" \" + display(kept == kept.insert(-3000, \"v0\")))"
      , "  0"
      , "}" ]
    , "1000 501 Some(\"y\")NoneSome(\"v0\")Some(\"v1\")\n-2993 3979 501 true\n" ) ]

{-| Programs over the library modules the store exists for. -}
storeModulePrograms :: [(String, Text, Text)]
storeModulePrograms =
  [ ( "MultiMap primitives directly and as values, with replaced key spellings", program
      [ "import Std.MultiMap as Multi"
      , "import Std.MultiMap {MultiMap}"
      , ""
      , "fn noisy(label: Str, value: Int) -> Int { print(label)"
      , "  value }"
      , ""
      , "fn main() -> Int {"
      , "  var held: MultiMap[Str, Int] = Multi.empty()"
      , "  held = Multi.add(&held, \"b\", 2)"
      , "  held = Multi.add(&held, \"a\", 1)"
      , "  held = Multi.add(&held, \"b\", 2)"
      , "  held = Multi.add(&held, \"b\", 3)"
      , "  print(show(held))"
      , "  print(display(Multi.contains(&held, \"b\", 3)) + display(Multi.contains(&held, \"b\", 4)) + display(Multi.contains(&held, \"z\", 1)))"
      , "  print(show(Multi.get(&held, \"b\")) + display(Multi.total(&held)) + show(Multi.pairs(&held)))"
      , "  let direct = multiMapAdd(&held, \"c\", noisy(\"value\", 9))"
      , "  print(show(direct.groups) + show(held.groups.size()))"
      , "  let add = multiMapAdd"
      , "  let has = multiMapContains"
      , "  let floats: MultiMap[Float, Int] = Multi.empty()"
      , "  let signed = add(&add(&floats, -0.0, 1), 0.0, 2)"
      , "  print(show(signed) + display(has(&signed, 0.0, 1)) + show(add))"
      , "  let numbers: MultiMap[Int, Int] = Multi.empty()"
      , "  print(show(Multi.add(&Multi.add(&numbers, 5, 6), 5, 6)))"
      , "  0"
      , "}" ]
    , "MultiMap{groups: {\"a\": [1], \"b\": [2, 2, 3]}, occurrences: {(\"a\", 1): 1, (\"b\", 2): 2, (\"b\", 3): 1}}\ntruefalsefalse\n[2, 2, 3]4[(\"a\", 1), (\"b\", 2), (\"b\", 2), (\"b\", 3)]\nvalue\n{\"a\": [1], \"b\": [2, 2, 3], \"c\": [9]}2\nMultiMap{groups: {0.0: [1, 2]}, occurrences: {(-0.0, 1): 1, (0.0, 2): 1}}true<builtin multiMapAdd>\nMultiMap{groups: {5: [6, 6]}, occurrences: {(5, 6): 2}}\n" )
  , ( "Std.HashMap inserts, replaces, removes and enumerates in insertion order", program
      [ "import Std.HashMap as HashMap"
      , ""
      , "fn main() -> Int {"
      , "  var table = HashMap.empty[Str, Int]()"
      , "  for index in 0..200 { table = HashMap.insert(&table, \"k\" + display(index), index * 2) }"
      , "  table = HashMap.insert(&table, \"k7\", -7)"
      , "  table = HashMap.remove(&table, &\"k9\")"
      , "  print(display(HashMap.size(&table)) + \" \" + show(HashMap.get(&table, &\"k7\")) + show(HashMap.get(&table, &\"k9\")) + show(HashMap.get(&table, &\"k199\")))"
      , "  let first = HashMap.keys(&table)"
      , "  print(first[0] + first[1] + first[198] + \" \" + display(HashMap.containsKey(&table, &\"k100\")))"
      , "  var total = 0"
      , "  for (_, value) in HashMap.entries(&table) { total = total + value }"
      , "  print(display(total))"
      , "  0"
      , "}" ]
    , "199 Some(-7)NoneSome(398)\nk0k1k199 true\n39761\n" ) ]

storeRefusalPrograms :: [(String, Text)]
storeRefusalPrograms =
  [ ( "an unorderable MultiMap key refuses at the call", program
      [ "import Std.MultiMap {MultiMap}"
      , ""
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  let empty: MultiMap[fn(Int) -> Int, Int] = MultiMap{groups: mapOf([]), occurrences: mapOf([])}"
      , "  multiMapAdd(&empty, |value| value, 1)"
      , "  0"
      , "}" ] )
  , ( "an unorderable MultiMap pair refuses at the call made through a value", program
      [ "import Std.MultiMap {MultiMap}"
      , ""
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  let empty: MultiMap[Int, fn(Int) -> Int] = MultiMap{groups: mapOf([]), occurrences: mapOf([])}"
      , "  print(display(multiMapContains(&empty, 1, |value| value)))"
      , "  let add = multiMapAdd"
      , "  add(&empty, 1, |value| value)"
      , "  0"
      , "}" ] )
  , ( "a full occurrence count refuses at the call", program
      [ "import Std.MultiMap {MultiMap}"
      , ""
      , "fn main() -> Int {"
      , "  let full: MultiMap[Int, Int] = MultiMap{groups: mapOf([(1, [2])]), occurrences: mapOf([((1, 2), 9223372036854775807)])}"
      , "  print(show(multiMapAdd(&full, 1, 3).occurrences))"
      , "  multiMapAdd(&full, 1, 2)"
      , "  0"
      , "}" ] )
  , ( "a full occurrence count through a value refuses at the call made through it", program
      [ "import Std.MultiMap {MultiMap}"
      , ""
      , "fn main() -> Int {"
      , "  let full: MultiMap[Int, Int] = MultiMap{groups: mapOf([(1, [2])]), occurrences: mapOf([((1, 2), 9223372036854775807)])}"
      , "  let add = multiMapAdd"
      , "  print(\"through a value\")"
      , "  add(&full, 1, 2)"
      , "  0"
      , "}" ] )
  , ( "ordering operators on stores keep the runtime refusal", program
      [ "fn main() -> Int {"
      , "  let left: Buckets[Int] = bucketsOf()"
      , "  print(\"before\")"
      , "  print(display(left < left.insert(1, 1)))"
      , "  0"
      , "}" ] )
  , ( "a store entry renders its entries", program
      [ "fn main() -> Buckets[Str] { bucketsOf().insert(2, \"two\").insert(-1, \"one\") }" ] )
  , ( "a mixHash entry retains its builtin rendering", program
      [ "fn main() -> fn(Int) -> Int { mixHash }" ] )
  , ( "a failing store argument stops later operands", program
      [ "fn main() -> Int {"
      , "  let store: Buckets[Int] = bucketsOf()"
      , "  let zero = 0"
      , "  print(\"before\")"
      , "  print(show(store.insert({ print(\"failure\")"
      , " 1 / zero }, { print(\"later\")"
      , " 2 })))"
      , "  0"
      , "}" ] ) ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
