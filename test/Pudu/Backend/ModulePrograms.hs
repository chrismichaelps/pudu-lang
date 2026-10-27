{-| @Test.Backend.ModulePrograms — programs of several modules with hand-written answers. -}
module Pudu.Backend.ModulePrograms (modulePrograms, moduleRefusalPrograms, constantPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Backend.ReferencePrograms (referenceSuccessPrograms, referenceRefusalPrograms)
import Pudu.Backend.MethodPrograms (methodSuccessPrograms, methodRefusalPrograms)
import Pudu.Backend.GenericPrograms (genericSuccessPrograms, genericRefusalPrograms)
import Pudu.Backend.TryPrograms (trySuccessPrograms, tryRefusalPrograms)

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
  [(label, [], source, answer) | (label, source, answer) <- constantPrograms <> referenceSuccessPrograms <> methodSuccessPrograms <> genericSuccessPrograms <> trySuccessPrograms] <>
  [ ( "calls through a selective import, an alias and a module that imports another"
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
  ]

{-| Held to the interpreter's rendered diagnostics: a failure inside an
    imported function reports at its own module's source. -}
moduleRefusalPrograms :: [(String, [(FilePath, Text)], Text)]
moduleRefusalPrograms =
  [(label, [], source) | (label, source) <- referenceRefusalPrograms <> methodRefusalPrograms <> genericRefusalPrograms <> tryRefusalPrograms] <>
  [ ( "a constant read preserves the runtime overflow operation's span"
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
