{-| @Test.Backend.ModulePrograms — programs of several modules with hand-written answers. -}
module Pudu.Backend.ModulePrograms (modulePrograms, moduleRefusalPrograms, constantPrograms, constantModulePrograms, constantRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.DefaultParameterPrograms (defaultParameterModulePrograms)
import Pudu.Backend.RenderingCallablePrograms (renderingCallableModulePrograms)
import Pudu.Backend.ReferencePrograms (referenceSuccessPrograms, referenceRefusalPrograms)
import Pudu.Backend.MethodPrograms (methodSuccessPrograms, methodRefusalPrograms)
import Pudu.Backend.GenericPrograms (genericSuccessPrograms, genericRefusalPrograms)
import Pudu.Backend.TryPrograms (trySuccessPrograms, tryRefusalPrograms)
import Pudu.Backend.ForPrograms (forSuccessPrograms, forRefusalPrograms)
import Pudu.Backend.ClosurePrograms (closureSuccessPrograms, closureRefusalPrograms)
import Pudu.Backend.ArrayPrograms (arraySuccessPrograms, arrayRefusalPrograms)
import Pudu.Backend.ArrayPatternPrograms (arrayPatternSuccessPrograms, arrayPatternRefusalPrograms)
import Pudu.Backend.TextCollectionPrograms (textCollectionSuccessPrograms, textCollectionRefusalPrograms)
import Pudu.Backend.TextViewPrograms (textViewSuccessPrograms, textViewRefusalPrograms, textViewFacadePrograms)
import Pudu.Backend.ConvertPrograms (convertSuccessPrograms, convertRefusalPrograms)
import Pudu.Backend.KeyedPrograms (keyedSuccessPrograms, keyedRefusalPrograms)
import Pudu.Backend.ShapePrograms (shapeModulePrograms, shapeSuccessPrograms)
import Pudu.Backend.RangePrograms (rangeRefusalPrograms, rangeSuccessPrograms)
import Pudu.Backend.BytesPrograms (bytesRefusalPrograms, bytesSuccessPrograms)
import Pudu.Backend.WordMapPrograms (wordMapRefusalPrograms, wordMapSuccessPrograms)
import Pudu.Backend.StorePrograms (storeModulePrograms, storeRefusalPrograms, storeSuccessPrograms)

geometry :: (FilePath, Text)
geometry = ("Geometry.pudu", Text.unlines
  [ "module Geometry"
  , ""
  , "export type Point = { x: Int, y: Int }"
  , ""
  , "export type Shape ="
  , "  | Dot"
  , "  | Circle(Int)"
  , ""
  , "export fn area(shape: Shape) -> Int {"
  , "  match shape {"
  , "    case Dot => 0"
  , "    case Circle(r) => 3 * r * r"
  , "  }"
  , "}"
  , ""
  , "export fn shift(point: Point, by: Int) -> Point {"
  , "  Point{x: point.x + by, y: point.y + helper(by)}"
  , "}"
  , ""
  , "fn helper(by: Int) -> Int { by * 2 }"
  , ""
  , "export fn countdown(n: Int) -> Int {"
  , "  if n <= 0 { 0 } else { n + countdown(n - 1) }"
  , "}"
  , ""
  , "export fn label(text: Str) -> Str { \"<\" + text + \">\" }"
  ])

{-| A module that itself imports another, so a call crosses two modules. -}
layout :: (FilePath, Text)
layout = ("Layout.pudu", Text.unlines
  [ "module Layout"
  , ""
  , "import Geometry as G"
  , ""
  , "export fn corner(n: Int) -> G.Point { G.shift(G.Point{x: 0, y: 0}, n) }"
  ])

modulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
modulePrograms =
  [(label, [], source, answer) | (label, source, answer) <- textViewFacadePrograms <> textViewSuccessPrograms <> wordMapSuccessPrograms <> storeSuccessPrograms <> storeModulePrograms <> constantPrograms <> referenceSuccessPrograms <> methodSuccessPrograms <> genericSuccessPrograms <> trySuccessPrograms <> forSuccessPrograms <> closureSuccessPrograms <> arraySuccessPrograms <> arrayPatternSuccessPrograms <> textCollectionSuccessPrograms <> convertSuccessPrograms <> keyedSuccessPrograms <> shapeSuccessPrograms <> rangeSuccessPrograms <> bytesSuccessPrograms] <> constantModulePrograms <> renderingCallableModulePrograms <> defaultParameterModulePrograms <> shapeModulePrograms <>
  [ ( "implementations inherit the defaults of an imported trait, run in the trait's module"
    , [ ("Lib.pudu", Text.unlines
          [ "module Lib", ""
          , "fn shout(text: Str) -> Str { text + \"!\" }"
          , "export type Wrapped[T] = { held: T }"
          , "export trait Loud[T] {"
          , "  fn word(self: &Self) -> T"
          , "  fn loudly(self: &Self, render: fn(T) -> Str) -> Str { shout(render(self.word())) }"
          , "  fn wrapped(self: &Self) -> Wrapped[T] { Wrapped{held: self.word()} }"
          , "  fn twice(self: &Self) -> (T, T) { (self.word(), self.word()) }"
          , "}" ]) ]
    , program
        [ "import Lib {Loud}"
        , "type Bell = { n: Int }", "type Name = { text: Str }"
        , "fn shout(text: Str) -> Str { \"the importer's shout\" }"
        , "impl Loud[Int] for Bell { fn word(self: &Self) -> Int { self.n } }"
        , "impl Loud[Str] for Name {"
        , "  fn word(self: &Self) -> Str { self.text }"
        , "  fn twice(self: &Self) -> (Str, Str) { (self.text, \"overridden\") }", "}"
        , "fn main() -> Int {"
        , "  let bell = Bell{n: 4}", "  let name = Name{text: \"pudu\"}"
        , "  print(bell.loudly(|n| n.toText()))", "  print(Loud.loudly(&bell, |n| (n * 2).toText()))"
        , "  print(display(bell.wrapped().held))", "  print(show(bell.twice()))"
        , "  print(name.loudly(|text| text))", "  print(show(name.twice()))"
        , "  return 0", "}" ]
    , "4!\n8!\n4\n(4, 4)\npudu!\n(\"pudu\", \"overridden\")\n" )
  , ( "module-qualified functions are values with one identity"
    , [ ("Lib.pudu", Text.unlines
          [ "module Lib", ""
          , "export fn twice(value: Int) -> Int { value * 2 }"
          , "export fn greet(name: Str, mark: Str = \"!\") -> Str { name + mark }" ]) ]
    , program
        [ "import Lib"
        , "import Lib as L"
        , ""
        , "fn apply(f: fn(Int) -> Int, value: Int) -> Int { f(value) }"
        , "fn main() -> Int {"
        , "  let t = Lib.twice"
        , "  print(display(t(4)))"
        , "  print(display(apply(L.twice, 5)))"
        , "  print(show(Lib.twice))"
        , "  print(display(Lib.twice == L.twice))"
        , "  let g = L.greet"
        , "  print(g(\"a\") + g(\"b\", \"?\"))"
        , "  0"
        , "}"
        ]
    , "8\n10\n<fn twice>\ntrue\na!b?\n" )
  , ( "calls through a selective import, an alias and a module that imports another"
    , [geometry, layout]
    , program
        [ "import Geometry {area, countdown, Circle, Dot}"
        , "import Geometry as Geo"
        , "import Layout"
        , ""
        , "fn main() -> Int {"
        , "  print(display(area(Circle(2)) + area(Dot)))"
        , "  print(display(countdown(4)))"
        , "  print(display(Geo.shift(Geo.Point{x: 1, y: 1}, 3)))"
        , "  print(display(Layout.corner(2)))"
        , "  print(Geo.label(\"tag\"))"
        , "  0"
        , "}"
        ]
    , "12\n10\nPoint{x: 4, y: 7}\nPoint{x: 2, y: 4}\n<tag>\n" )
  , ( "a type named in two modules stays two types"
    , [geometry]
    , program
        [ "import Geometry as Geo"
        , ""
        , "type Point = { label: Str }"
        , "type Shape = Square(Int) | Dot"
        , ""
        , "fn main() -> Int {"
        , "  let mine = Point{label: \"here\"}"
        , "  let theirs = Geo.Point{x: 1, y: 2}"
        , "  print(display(mine))"
        , "  print(display(theirs))"
        , "  print(show(Square(3)))"
        , "  print(show(Geo.Circle(1)))"
        , "  print(display(Geo.area(Geo.Dot)))"
        , "  0"
        , "}"
        ]
    , "Point{label: \"here\"}\nPoint{x: 1, y: 2}\nSquare(3)\nCircle(1)\n0\n" )
  , ( "an imported function's result is an entry result"
    , [geometry]
    , program
        [ "import Geometry {shift, Point}"
        , ""
        , "fn main() -> Point { shift(Point{x: 0, y: 0}, 1) }"
        ]
    , "Point{x: 1, y: 2}\n" )
  , ( "folded constants keep module identity through selected and transitive imports"
    , [ ("Config.pudu", Text.unlines
          [ "module Config", "export type Point = { x: Int, y: Int }"
          , "export const POINT: Point = Point{y: 4, x: 2}", "export const ANSWER: Int = 21"
          , "export const TOKEN: Str = \"lib\"", "export fn point() -> Point { POINT }" ])
      , ("Bridge.pudu", Text.unlines
          [ "module Bridge", "import Config as C", "export const DOUBLE: Int = C.ANSWER * 2" ]) ]
    , program
        [ "import Config {TOKEN}", "import Config as C", "import Bridge as B"
        , "type Point = { label: Str }", "const POINT = Point{label: \"root\"}"
        , "const ANSWER = 7", "fn main() -> Int {"
        , "  print(TOKEN + display(ANSWER) + \" \" + display(C.ANSWER) + \" \" + display(B.DOUBLE))"
        , "  print(show(POINT) + \" \" + show(C.POINT) + \" \" + show(C.point()))"
        , "  0", "}" ]
    , "lib7 21 42\nPoint{label: \"root\"} Point{x: 2, y: 4} Point{x: 2, y: 4}\n" )
  ]

constantPrograms :: [(String, Text, Text)]
constantPrograms =
  [ ("folded numeric constants keep widths and compile-time answers", program
      [ "comptime fn square(n: Int) -> Int { n * n }"
      , "type Small = Int8", "const BASE = 7", "const ANSWER = square(BASE)"
      , "const SMALL: Small = 127i8"
      , "const WIDE = 340282366920938463463374607431768211455u128"
      , "const NARROW = 0.1f32", "const ZERO = -0.0", "const NAN = 0.0 / 0.0"
      , "const UNUSED = [1, 2]", "fn main() -> Int {"
      , "  print(display(ANSWER) + \" \" + display(SMALL) + \" \" + display(WIDE))"
      , "  print(display(NARROW) + \" \" + display(ZERO) + \" \" + display(NAN))"
      , "  print(display(NAN == NAN))", "  0", "}" ]
    , "49 127 340282366920938463463374607431768211455\n0.10000000149011612 -0.0 NaN\nfalse\n")
  , ("folded aggregates retain ownership across reads, mutation and transfers", program
      [ "type Box = { mut text: Str, number: Int }"
      , "const BOX = Box{number: 3, text: \"original\"}"
      , "const HELD = Some((BOX, Ok(\"payload\")))"
      , "const FLAG = true", "const LETTER = 'λ'", "const UNIT = ()"
      , "fn held() -> Option[(Box, Result[Str, Int])] { return HELD }"
      , "fn main() -> Int {"
      , "  var copy = BOX", "  copy.text = \"changed\""
      , "  print(show(copy) + \" \" + show(BOX))"
      , "  print(show(held()))", "  var n = 0", "  while n < 2 {"
      , "    print(show(HELD))", "    n = n + 1", "  }"
      , "  print(display(FLAG) + \" \" + display(LETTER) + \" \" + display(UNIT))"
      , "  0", "}" ]
    , Text.unlines
        [ "Box{text: \"changed\", number: 3} Box{text: \"original\", number: 3}"
        , "Some((Box{text: \"original\", number: 3}, Ok(\"payload\")))"
        , "Some((Box{text: \"original\", number: 3}, Ok(\"payload\")))"
        , "Some((Box{text: \"original\", number: 3}, Ok(\"payload\")))", "true λ ()" ])
  , ("folded collections retain nested owned data and independent reads", program
      [ "const NAMES = [\"a\", \"b\"]"
      , "const TABLE = mapOf([(\"b\", [3, 4]), (\"a\", [1, 2])])"
      , "const MARKS = setOf([\"z\", \"a\", \"z\"])"
      , "const RANGES = (..4, 2.., 1..=3, ..)"
      , "const HELD = Some((NAMES, TABLE, MARKS, RANGES))"
      , "fn held() { HELD }"
      , "fn main() -> Int {"
      , "  var copy = NAMES"
      , "  copy[0] = \"changed\""
      , "  print(show(copy) + \" \" + show(NAMES))"
      , "  print(show(TABLE) + \" \" + show(MARKS) + \" \" + show(RANGES))"
      , "  if let Some((names, table, marks, ranges)) = held() { print(show(names) + show(marks) + show(table.get(\"a\")) + show(ranges[2])) }"
      , "  for index in 0..30 { let value = held() }"
      , "  0"
      , "}" ]
    , "[\"changed\", \"b\"] [\"a\", \"b\"]\n{\"a\": [1, 2], \"b\": [3, 4]} #{\"a\", \"z\"} (..4, 2.., 1..=3, ..)\n[\"a\", \"b\"]#{\"a\", \"z\"}Some([1, 2])1..=3\n")
  , ("folded empty collections, ranges and floating key representatives", program
      [ "const EMPTY: Array[Str] = []"
      , "const MAP: Map[Str, Int] = mapOf([])"
      , "const SET: Set[Int] = setOf([])"
      , "const RANGES = [1..3, 1..=3, 3..1, ..2, 2..]"
      , "const KEYS = mapOf([(-0.0, \"first\"), (0.0, \"last\")])"
      , "const EXTREMES = (-9223372036854775808..-9223372036854775807, 9223372036854775807..=9223372036854775807)"
      , "fn main() -> Int {"
      , "  print(show(EMPTY) + \" \" + show(MAP) + \" \" + show(SET))"
      , "  print(show(RANGES) + \" \" + show(KEYS))"
      , "  print(show(EXTREMES))"
      , "  var total = 0"
      , "  for number in RANGES[1] { total = total + number }"
      , "  print(display(total) + \" \" + show(EMPTY.push(\"new\")) + show(EMPTY))"
      , "  0"
      , "}" ]
    , "[] {} #{}\n[1..3, 1..=3, 3..1, ..2, 2..] {-0.0: \"last\"}\n(-9223372036854775808..-9223372036854775807, 9223372036854775807..=9223372036854775807)\n6 [\"new\"][]\n")
  , ("folded nominal sums retain collection payloads", program
      [ "type Packet = Items(Array[Str]) | Empty"
      , "const HELD = Items([\"a\", \"b\"])"
      , "fn main() -> Int { print(show(HELD))\n 0 }" ]
    , "Items([\"a\", \"b\"])\n")
  ]

constantModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
constantModulePrograms =
  [ ("folded imported collections keep canonical nominal element owners"
    , [("Data.pudu", Text.unlines
        [ "module Data", "export type Item = { name: Str }"
        , "export const ITEMS: Array[Item] = [Item{name: \"module\"}]"
        , "export const TABLE: Map[Str, Array[Item]] = mapOf([(\"row\", ITEMS)])" ])]
    , program
        [ "import Data {TABLE}", "import Data as D"
        , "type Item = { code: Int }", "const ITEMS = [Item{code: 7}]"
        , "fn main() -> Int {"
        , "  print(show(ITEMS) + \" \" + show(D.ITEMS) + \" \" + show(TABLE))"
        , "  print(D.ITEMS[0].name)", "  0", "}" ]
    , "[Item{code: 7}] [Item{name: \"module\"}] {\"row\": [Item{name: \"module\"}]}\nmodule\n") ]

constantRefusalPrograms :: [(String, [(FilePath, Text)], Text)]
constantRefusalPrograms =
  [ ("a frozen array read retains the failing index span", [], program
      [ "const ITEMS = [\"a\"]", "fn main() -> Int {"
      , "  print(\"before\")", "  print(ITEMS[2])", "  0", "}" ])
  , ("a frozen open range retains the length refusal", [], program
      [ "const OPEN = 2..", "fn main() -> Int {"
      , "  print(show(OPEN))", "  OPEN.length()", "}" ]) ]

{-| Held to the interpreter's rendered diagnostics: a failure inside an
    imported function reports at its own module's source. -}
moduleRefusalPrograms :: [(String, [(FilePath, Text)], Text)]
moduleRefusalPrograms =
  constantRefusalPrograms <> [(label, [], source) | (label, source) <- textViewRefusalPrograms <> wordMapRefusalPrograms <> storeRefusalPrograms <> referenceRefusalPrograms <> methodRefusalPrograms <> genericRefusalPrograms <> tryRefusalPrograms <> forRefusalPrograms <> closureRefusalPrograms <> arrayRefusalPrograms <> arrayPatternRefusalPrograms <> textCollectionRefusalPrograms <> convertRefusalPrograms <> keyedRefusalPrograms <> rangeRefusalPrograms <> bytesRefusalPrograms] <>
  [ ( "a failure in an imported inherited default names the trait module"
    , [("Lib.pudu", Text.unlines
        [ "module Lib", "export trait Divide {"
        , "  fn divisor(self: &Self) -> Int"
        , "  fn answer(self: &Self) -> Int { 12 / self.divisor() }", "}" ])]
    , program
        [ "import Lib {Divide}", "type Zero = { value: Int }"
        , "impl Divide for Zero { fn divisor(self: &Self) -> Int { self.value } }"
        , "fn main() -> Int {", "  print(\"before\")"
        , "  Zero{value: 0}.answer()", "}" ] )
  , ( "a constant read preserves the runtime overflow operation's span"
    , [], program
        [ "const MAX = 9223372036854775807", "fn main() -> Int {"
        , "  print(\"start\")", "  var n = MAX", "  n + 1", "}" ] )
  , ( "an overflow inside an imported function"
    , [("Arith.pudu", Text.unlines
        [ "module Arith"
        , ""
        , "export fn double(n: Int) -> Int { n * 2 }"
        ])]
    , program
        [ "import Arith as A"
        , ""
        , "fn main() -> Int {"
        , "  print(\"start\")"
        , "  A.double(9223372036854775807)"
        , "}"
        ] )
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
