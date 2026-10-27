{-| @Test.Backend.SumPrograms — sums, Option, Result and match with hand-written answers. -}
module Pudu.Backend.SumPrograms (sumSuccessPrograms, sumRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

shapes :: [Text]
shapes =
  [ "type Shape ="
  , "  | Dot"
  , "  | Circle(Int)"
  , "  | Pair(Str, Char)"
  , "  | Box{w: Int, h: Int}"
  , ""
  ]

sumSuccessPrograms :: [(String, Text, Text)]
sumSuccessPrograms =
  [ printing "rendering follows renderValue"
      [ "Dot", "Circle(3)", "Pair(\"a\", 'b')", "Box{w: 1, h: 2}", "Shape.Circle(-4)", "show(Box{w: 0, h: 9})" ]
      [ "Dot", "Circle(3)", "Pair(\"a\", 'b')", "Box{w: 1, h: 2}", "Circle(-4)", "Box{w: 0, h: 9}" ]
  , printing "Option and Result render their payloads"
      [ "Some(1)", "Some(Some(\"x\"))", "None == Some(1)", "Ok(2) == Ok(2)", "show(Err(\"bad\"))", "show(Some((1, 'c')))" ]
      [ "Some(1)", "Some(Some(\"x\"))", "false", "true", "Err(\"bad\")", "Some((1, 'c'))" ]
  , printing "equality compares the variant and then the payload"
      [ "Dot == Dot", "Circle(1) == Circle(1)", "Circle(1) == Circle(2)", "Circle(1) == Dot"
      , "Box{w: 1, h: 2} == Box{w: 1, h: 2}", "Box{w: 1, h: 2} != Box{w: 2, h: 1}"
      , "Pair(\"a\", 'b') == Pair(\"a\", 'b')", "Some(0.0 / 0.0) == Some(0.0 / 0.0)" ]
      [ "true", "true", "false", "false", "true", "true", "true", "false" ]
  , ("match tries arms in order with guards and bindings", program
      [ "fn describe(shape: Shape) -> Str {"
      , "  match shape {"
      , "    case Dot => \"dot\""
      , "    case Circle(r) if r > 10 => \"big circle\""
      , "    case Circle(0) => \"point circle\""
      , "    case Circle(r) => \"circle \" + display(r)"
      , "    case Pair(name, _) => \"pair \" + name"
      , "    case Box{w, h: 1} => \"strip \" + display(w)"
      , "    case Box{w, h} => \"box \" + display(w * h)"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  print(describe(Dot))"
      , "  print(describe(Circle(11)))"
      , "  print(describe(Circle(0)))"
      , "  print(describe(Circle(4)))"
      , "  print(describe(Pair(\"p\", 'q')))"
      , "  print(describe(Box{w: 5, h: 1}))"
      , "  print(describe(Box{w: 3, h: 4}))"
      , "  return 0"
      , "}" ]
    , "dot\nbig circle\npoint circle\ncircle 4\npair p\nstrip 5\nbox 12\n")
  , ("literal, range, tuple and alternative patterns", program
      [ "fn classify(n: Int) -> Str {"
      , "  match n {"
      , "    case 0 => \"zero\""
      , "    case 1 | 2 | 3 => \"small\""
      , "    case 4..10 => \"medium\""
      , "    case 10..=20 => \"large\""
      , "    case _ => \"huge\""
      , "  }"
      , "}"
      , "fn corner(point: (Int, Bool)) -> Str {"
      , "  match point {"
      , "    case (0, true) => \"origin on\""
      , "    case (0, _) => \"origin\""
      , "    case (x, true) => \"on \" + display(x)"
      , "    case (_, false) => \"off\""
      , "  }"
      , "}"
      , "fn word(text: Str) -> Int {"
      , "  match text {"
      , "    case \"one\" => 1"
      , "    case \"two\" | \"deux\" => 2"
      , "    case _ => 0"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  print(classify(0) + classify(2) + classify(9) + classify(10) + classify(20) + classify(21))"
      , "  print(corner((0, true)) + corner((0, false)) + corner((3, true)) + corner((3, false)))"
      , "  print(display(word(\"one\") + word(\"deux\") + word(\"three\")))"
      , "  return 0"
      , "}" ]
    , "zerosmallmediumlargelargehuge\norigin onoriginon 3off\n3\n")
  , ("Option and Result flow through calls, loops and nested patterns", program
      [ "fn find(limit: Int) -> Option[Int] {"
      , "  var i = 0"
      , "  while i < limit {"
      , "    if i * i > 10 { return Some(i) }"
      , "    i = i + 1"
      , "  }"
      , "  None"
      , "}"
      , "fn parse(text: Str) -> Result[Int, Str] {"
      , "  if text == \"7\" { Ok(7) } else { Err(\"not seven: \" + text) }"
      , "}"
      , "fn main() -> Int {"
      , "  print(show(find(10)) + \" \" + show(find(3)))"
      , "  let nested = Some(Some(2))"
      , "  match nested {"
      , "    case Some(Some(n)) => print(\"inner \" + display(n))"
      , "    case Some(None) => print(\"empty inner\")"
      , "    case None => print(\"nothing\")"
      , "  }"
      , "  var round = 0"
      , "  while round < 2 {"
      , "    let text = if round == 0 { \"7\" } else { \"x\" }"
      , "    match parse(text) {"
      , "      case Ok(n) => print(\"ok \" + display(n))"
      , "      case Err(message) => print(message)"
      , "    }"
      , "    round = round + 1"
      , "  }"
      , "  return 0"
      , "}" ]
    , "Some(4) None\ninner 2\nok 7\nnot seven: x\n")
  , ("payloads run left to right and a Never payload stops the variant", program
      [ "fn early() -> Int {"
      , "  let shape = Pair({ print(\"first\")"
      , "    \"a\" }, { return 4 })"
      , "  print(show(shape))"
      , "  0"
      , "}"
      , "fn main() -> Int {"
      , "  let box = Box{h: { print(\"h\")"
      , "    2 }, w: { print(\"w\")"
      , "    3 }}"
      , "  print(display(early()))"
      , "  print(show(box))"
      , "  return 0"
      , "}" ]
    , "h\nw\nfirst\n4\nBox{w: 3, h: 2}\n")
  , ("sums through mutation and loop values", program
      [ "fn main() -> Int {"
      , "  var current = Circle(1)"
      , "  var steps = 0"
      , "  while steps < 3 {"
      , "    current = match current {"
      , "      case Circle(r) => Circle(r * 2)"
      , "      case other => other"
      , "    }"
      , "    steps = steps + 1"
      , "  }"
      , "  let found = loop { break Some(current) }"
      , "  print(show(found))"
      , "  return 0"
      , "}" ]
    , "Some(Circle(8))\n")
  ] <>
  [ ("sum entry " <> label, program (["fn main() -> " <> kind <> " {", "  " <> body, "}"]), answer <> "\n")
  | (label, kind, body, answer) <-
      [ ("of a unit variant", "Shape", "Dot", "Dot")
      , ("of a record variant", "Shape", "Box{w: 2, h: 3}", "Box{w: 2, h: 3}")
      , ("of an option", "Option[Str]", "Some(\"q\")", "Some(\"q\")")
      , ("of a result", "Result[Int, Str]", "Err(\"no\")", "Err(\"no\")") ]
  ]
 where
  printing label expressions answers =
    ( label
    , program (["fn main() -> Int {"] <> ["  print(display(" <> expression <> "))" | expression <- expressions] <> ["  return 0", "}"])
    , Text.pack (concatMap (<> "\n") answers) )

{-| Held to the interpreter's rendered diagnostics. A match no arm accepts is
    not here: checking requires every match to cover its subject, so E7011 is
    unreachable from a checked program, and both paths keep it only as a guard. -}
sumRefusalPrograms :: [(String, Text)]
sumRefusalPrograms =
  [ (label <> " refuses at run time", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let x = " <> expression, "  print(show(x))", "  return 0", "}" ])
  | (label, expression) <-
      [ ("ordering two options", "Some(1) < None"), ("subtracting a variant", "Circle(1) - Dot")
      , ("adding results", "Ok(1) + Ok(2)") ]
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> shapes <> body)
