{-| @Test.Backend.RecordPrograms — records with hand-written answers. -}
module Pudu.Backend.RecordPrograms (recordSuccessPrograms, recordRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

declarations :: [Text]
declarations =
  [ "type Point = { mut x: Int, y: Int }"
  , "type Named = { name: Str, at: Point, tags: (Str, Char) }"
  , "type Empty = {}"
  , "type Holder = { mut inner: Point, label: Str }"
  ]

recordSuccessPrograms :: [(String, Text, Text)]
recordSuccessPrograms =
  [ printing "rendering follows declaration order"
      [ "Point{x: 1, y: 2}", "Point{y: 2, x: 1}", "Named{tags: (\"t\", 'q'), at: Point{y: 0, x: -1}, name: \"a\\\"b\"}"
      , "Empty{}", "show(Point{x: 3, y: 4})" ]
      [ "Point{x: 1, y: 2}", "Point{x: 1, y: 2}", "Named{name: \"a\\\"b\", at: Point{x: -1, y: 0}, tags: (\"t\", 'q')}"
      , "Empty{}", "Point{x: 3, y: 4}" ]
  , printing "equality is field by field whatever order was written"
      [ "Point{x: 1, y: 2} == Point{y: 2, x: 1}", "Point{x: 1, y: 2} != Point{x: 1, y: 3}"
      , "Empty{} == Empty{}", "Named{name: \"n\", at: Point{x: 0, y: 0}, tags: (\"\", 'c')} == Named{name: \"n\", at: Point{x: 0, y: 1}, tags: (\"\", 'c')}" ]
      [ "true", "true", "true", "false" ]
  , printing "fields and updates"
      [ "Point{x: 1, y: 2}.y", "Named{name: \"n\", at: Point{x: 5, y: 6}, tags: (\"t\", 'c')}.at.x"
      , "Point{..Point{x: 1, y: 2}, y: 9}", "Named{..Named{name: \"a\", at: Point{x: 1, y: 1}, tags: (\"t\", 'c')}, at: Point{x: 2, y: 2}}" ]
      [ "2", "5", "Point{x: 1, y: 9}", "Named{name: \"a\", at: Point{x: 2, y: 2}, tags: (\"t\", 'c')}" ]
  , ("fields run in written order and an update runs its base first", program
      [ "fn mark(label: Str, n: Int) -> Int {"
      , "  print(label)"
      , "  n"
      , "}"
      , "fn base() -> Point {"
      , "  print(\"base\")"
      , "  Point{x: 0, y: 0}"
      , "}"
      , "fn main() -> Int {"
      , "  let a = Point{y: mark(\"y\", 2), x: mark(\"x\", 1)}"
      , "  let b = Point{..base(), y: mark(\"field\", 3)}"
      , "  print(show(a) + show(b))"
      , "  return 0"
      , "}" ]
    , "y\nx\nbase\nfield\nPoint{x: 1, y: 2}Point{x: 0, y: 3}\n")
  , ("field assignment keeps value semantics", program
      [ "fn main() -> Int {"
      , "  let a = Point{x: 1, y: 2}"
      , "  var p = a"
      , "  p.x = 5"
      , "  var h = Holder{inner: a, label: \"h\"}"
      , "  h.inner.x = 9"
      , "  print(show(p) + show(a) + show(h))"
      , "  var q = Point{x: 1, y: 2}"
      , "  q.x = {"
      , "    q = Point{x: 10, y: 20}"
      , "    7"
      , "  }"
      , "  print(show(q))"
      , "  return 0"
      , "}" ]
    , "Point{x: 5, y: 2}Point{x: 1, y: 2}Holder{inner: Point{x: 9, y: 2}, label: \"h\"}\nPoint{x: 7, y: 20}\n")
  , ("records through calls, loops, branches and patterns", program
      [ "fn shift(p: Point) -> Point { Point{..p, x: p.x + 1} }"
      , "fn pick(flag: Bool) -> Named {"
      , "  if flag { Named{name: \"yes\", at: Point{x: 1, y: 1}, tags: (\"y\", 'y')} }"
      , "  else { Named{name: \"no\", at: Point{x: 0, y: 0}, tags: (\"n\", 'n')} }"
      , "}"
      , "fn main() -> Int {"
      , "  var m = pick(true)"
      , "  var i = 0"
      , "  while i < 3 {"
      , "    m = Named{..m, name: m.name + \"!\", at: shift(m.at)}"
      , "    i = i + 1"
      , "  }"
      , "  print(display(m))"
      , "  let {at: {x, y: down}, tags: (_, mark)} = pick(false)"
      , "  print(display(x) + display(down) + display(mark))"
      , "  let found = loop { break Point{x: 4, y: 4} }"
      , "  print(show(found))"
      , "  return 0"
      , "}" ]
    , "Named{name: \"yes!!!\", at: Point{x: 4, y: 1}, tags: (\"y\", 'y')}\n00n\nPoint{x: 4, y: 4}\n")
  , ("a Never field stops the record", program
      [ "fn early() -> Int {"
      , "  let p = Point{x: { print(\"first\")"
      , "    1 }, y: { return 6 }}"
      , "  p.x"
      , "}"
      , "fn main() -> Int {"
      , "  print(display(early()))"
      , "  return 0"
      , "}" ]
    , "first\n6\n")
  ] <>
  [ ("record entry " <> label, program ["fn main() -> " <> kind <> " {", "  " <> body, "}"], answer <> "\n")
  | (label, kind, body, answer) <-
      [ ("of fields", "Point", "Point{y: 1, x: 0}", "Point{x: 0, y: 1}")
      , ("nested", "Named", "Named{name: \"e\", at: Point{x: 1, y: 2}, tags: (\"\\n\", '\\'')}", "Named{name: \"e\", at: Point{x: 1, y: 2}, tags: (\"\\n\", '\\'')}")
      , ("empty", "Empty", "Empty{}", "Empty{}") ]
  ]
 where
  printing label expressions answers =
    ( label
    , program (["fn main() -> Int {"] <> ["  print(display(" <> expression <> "))" | expression <- expressions] <> ["  return 0", "}"])
    , Text.pack (concatMap (<> "\n") answers) )

{-| Held to the interpreter's rendered diagnostics. -}
recordRefusalPrograms :: [(String, Text)]
recordRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let x = " <> expression, "  print(show(x))", "  return 0", "}" ])
  | (label, expression) <-
      [ ("record ordering", "Point{x: 1, y: 2} < Point{x: 1, y: 3}"), ("record addition", "Point{x: 1, y: 2} + Point{x: 1, y: 2}")
      , ("record negation", "-Point{x: 1, y: 2}"), ("empty record ordering", "Empty{} >= Empty{}") ]
  ] <>
  [ ("record operands finish before the refusal", program
      [ "fn side(label: Str) -> Point {"
      , "  print(label)"
      , "  Point{x: 1, y: 1}"
      , "}"
      , "fn main() -> Int {"
      , "  let x = side(\"left\") > side(\"right\")"
      , "  print(show(x))"
      , "  return 0"
      , "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> declarations <> [""] <> body)
