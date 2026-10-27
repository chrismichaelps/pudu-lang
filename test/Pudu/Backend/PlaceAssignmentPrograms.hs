{-| @Test.Backend.PlaceAssignmentPrograms — assignment to fields, elements
    and paths of both, with the interpreter's order and failure spans. -}
module Pudu.Backend.PlaceAssignmentPrograms
  ( placeAssignmentSuccessPrograms, placeAssignmentRefusalPrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text

placeAssignmentSuccessPrograms :: [(String, Text, Text, Text)]
placeAssignmentSuccessPrograms =
  [ ("fields, elements and nested elements are assigned in place", program
      [ "type Point = { mut x: Int, y: Int }"
      , "fn main() -> Int {"
      , "  var p = Point{x: 1, y: 2}"
      , "  p.x = 5"
      , "  var list = [1, 2, 3]"
      , "  list[1] = 9"
      , "  var grid = [[1], [2]]"
      , "  grid[1][0] = 7"
      , "  print(show(p) + show(list) + show(grid))"
      , "  0"
      , "}" ]
    , "Point{x: 5, y: 2}[1, 9, 3][[1], [7]]\n", "")
  , ("element assignment keeps the old array for other holders and mixes fields", program
      [ "type Point = { mut x: Int, mut tags: Array[Str] }"
      , "fn main() -> Int {"
      , "  var list = [1, 2, 3]"
      , "  let before = list"
      , "  list[1] = 9"
      , "  print(show(list) + show(before))"
      , "  var grid = [[1], [2]]"
      , "  grid[1][0] = 7"
      , "  print(show(grid))"
      , "  var points = [Point{x: 1, tags: [\"a\"]}]"
      , "  points[0].x = 5"
      , "  points[0].tags[0] = \"z\""
      , "  print(show(points))"
      , "  var p = Point{x: 0, tags: [\"q\", \"r\"]}"
      , "  p.tags[1] = \"s\""
      , "  print(show(p))"
      , "  0"
      , "}" ]
    , "[1, 9, 3][1, 2, 3]\n[[1], [7]]\n[Point{x: 5, tags: [\"z\"]}]\nPoint{x: 0, tags: [\"q\", \"s\"]}\n", "")
  , ("element assignment of owned text reuses and releases its values", program
      [ "fn main() -> Int {"
      , "  var words = [\"a\", \"b\"]"
      , "  words[0] = words[0]"
      , "  words[1] = words[0] + words[1]"
      , "  var total = 0"
      , "  var buffer = [\"x\".repeat(4096)]"
      , "  for index in 0..300 {"
      , "    buffer[0] = buffer[0].slice(1, 4096) + \"y\""
      , "    total = total + buffer[0].length()"
      , "  }"
      , "  print(show(words) + \" \" + display(total))"
      , "  0"
      , "}" ]
    , "[\"a\", \"ab\"] 1228800\n", "")
  ]

placeAssignmentRefusalPrograms :: [(String, Text)]
placeAssignmentRefusalPrograms =
  [ ("an element index out of range fails at the root name", program
      [ "type Point = { mut x: Int, mut tags: Array[Str] }"
      , "fn main() -> Int {"
      , "  var list = [1, 2, 3]"
      , "  let before = list"
      , "  list[1] = 9"
      , "  print(show(list) + show(before))"
      , "  var grid = [[1], [2]]"
      , "  grid[1][0] = 7"
      , "  print(show(grid))"
      , "  var points = [Point{x: 1, tags: [\"a\"]}]"
      , "  points[0].x = 5"
      , "  points[0].tags[0] = \"z\""
      , "  print(show(points))"
      , "  var p = Point{x: 0, tags: [\"q\", \"r\"]}"
      , "  p.tags[1] = \"s\""
      , "  print(show(p))"
      , "  list[-1] = 4"
      , "  print(show(list))"
      , "  list[5] = 0"
      , "  0"
      , "}" ])
  , ("indices run before the value and the outer bound is checked first", program
      [ "fn main() -> Int {"
      , "  var grid = [[1], [2]]"
      , "  print(display(grid.length()))"
      , "  grid[5][0] = { print(\"value\")"
      , " 1 }"
      , "  0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
