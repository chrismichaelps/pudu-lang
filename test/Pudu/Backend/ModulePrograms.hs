{-| @Test.Backend.ModulePrograms — programs of several modules with hand-written answers. -}
module Pudu.Backend.ModulePrograms (modulePrograms, moduleRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

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
  ]

{-| Held to the interpreter's rendered diagnostics: a failure inside an
    imported function reports at its own module's source. -}
moduleRefusalPrograms :: [(String, [(FilePath, Text)], Text)]
moduleRefusalPrograms =
  [ ( "an overflow inside an imported function"
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
