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
  , ("if let takes the pattern's block once and binds only there", program
      [ "fn describe(shape: Shape) -> Str {"
      , "  if let Circle(r) = shape { \"circle \" + display(r) }"
      , "  else if let Box{w, h} = shape { \"box \" + display(w * h) }"
      , "  else { \"other\" }"
      , "}"
      , "fn traced(n: Int) -> Option[Int] {"
      , "  print(\"read \" + display(n))"
      , "  if n > 0 { Some(n) } else { None }"
      , "}"
      , "fn main() -> Int {"
      , "  print(describe(Circle(3)) + \" \" + describe(Box{w: 2, h: 5}) + \" \" + describe(Dot))"
      , "  if let Some(n) = traced(4) { print(\"got \" + display(n)) }"
      , "  if let Some(n) = traced(0) { print(\"never \" + display(n)) }"
      , "  let value = if let Some(n) = traced(2) { n * 10 } else { -1 }"
      , "  print(display(value))"
      , "  if let Some(n) = traced(1) { n } else { 7 }"
      , "  let none = if let Some(_) = traced(5) { 1 }"
      , "  print(show(none))"
      , "  let flag = if let (0, b) = (0, true) { b } else { false }"
      , "  print(display(flag))"
      , "  return 0"
      , "}" ]
    , "circle 3 box 10 other\nread 4\ngot 4\nread 0\nread 2\n20\nread 1\nread 5\n()\ntrue\n")
  , ("while let reads its subject each turn and honours break and continue", program
      [ "fn next(n: Int) -> Option[Int] {"
      , "  print(\"next \" + display(n))"
      , "  if n < 3 { Some(n + 1) } else { None }"
      , "}"
      , "fn main() -> Int {"
      , "  var current = 0"
      , "  var total = 0"
      , "  while let Some(n) = next(current) {"
      , "    current = n"
      , "    if n == 2 { continue }"
      , "    total = total + n"
      , "  }"
      , "  print(display(total))"
      , "  var outer = 0"
      , "  @rounds while let Some(n) = next(outer) {"
      , "    outer = n"
      , "    var inner = 0"
      , "    while let Some(m) = next(inner) {"
      , "      inner = m"
      , "      if m == 2 && n == 2 { break @rounds }"
      , "    }"
      , "  }"
      , "  print(display(outer))"
      , "  let unit = while let Some(n) = next(9) { print(display(n)) }"
      , "  print(show(unit))"
      , "  return 0"
      , "}" ]
    , Text.unlines
        [ "next 0", "next 1", "next 2", "next 3", "4"
        , "next 0", "next 0", "next 1", "next 2", "next 3", "next 1", "next 0", "next 1", "2"
        , "next 9", "()" ])
  , ("a transferring let else subject makes its bindings unreachable", program
      [ "fn early() -> Int {"
      , "  let Some(value) = { return 7 } else { return 9 }"
      , "  value"
      , "}"
      , "fn main() -> Int {"
      , "  print(display(early()))"
      , "  return 0"
      , "}" ]
    , "7\n")
  , ("let else retains bindings and evaluates each subject once", program
      [ "fn traced(n: Int) -> Option[Int] {"
      , "  print(\"read \" + display(n))"
      , "  if n > 0 { Some(n) } else { None }"
      , "}"
      , "fn pick(n: Int) -> Int {"
      , "  let Some(first) = traced(n) else { return -1 }"
      , "  let Some(second) = traced(first + 1) else { return -2 }"
      , "  print(display(first) + \" \" + display(second))"
      , "  first + second"
      , "}"
      , "fn main() -> Int {"
      , "  print(display(pick(2)))"
      , "  print(display(pick(0)))"
      , "  return 0"
      , "}" ]
    , "read 2\nread 3\n2 3\n5\nread 0\n-1\n")
  , ("let else fallback sees outer names after partial pattern failure", program
      [ "fn choose(flag: Bool) -> Str {"
      , "  let name = \"outer\""
      , "  {"
      , "    let Some((name, true)) = Some((name + \" inner\", flag)) else {"
      , "      print(name)"
      , "      return name + \" fallback\""
      , "    }"
      , "    name + \" matched\""
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  print(choose(true))"
      , "  print(choose(false))"
      , "  return 0"
      , "}" ]
    , "outer inner matched\nouter\nouter fallback\n")
  , ("let else alternatives share bindings and record patterns retain fields", program
      [ "fn pick(n: Int) -> Str {"
      , "  let Some((value, 1)) | Some((value, 2)) = Some((\"held\", n)) else { return \"miss\" }"
      , "  let Box{w, h: 3} = Box{w: n, h: 3} else { return \"wrong box\" }"
      , "  let 1..=2 = w else { return \"wrong range\" }"
      , "  value + display(w)"
      , "}"
      , "fn main() -> Int {"
      , "  print(pick(1) + \" \" + pick(2) + \" \" + pick(3))"
      , "  return 0"
      , "}" ]
    , "held1 held2 miss\n")
  , ("let else fallback preserves labelled loop transfers and owned values", program
      [ "fn main() -> Int {"
      , "  var turn = 0"
      , "  let answer = @outer loop {"
      , "    turn = turn + 1"
      , "    loop {"
      , "      let Some(text) = (if turn == 2 { Some(\"kept\") } else { None }) else {"
      , "        print(\"skip\")"
      , "        if turn == 3 { break @outer \"done\" }"
      , "        continue @outer"
      , "      }"
      , "      print(text)"
      , "      continue @outer"
      , "    }"
      , "  }"
      , "  print(answer)"
      , "  return 0"
      , "}" ]
    , "skip\nkept\nskip\ndone\n")
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
  ] <>
  [ ("an overflow inside an if let body", program
      [ "fn main() -> Int {", "  print(\"start\")", "  if let Some(n) = Some(9223372036854775807) { print(display(n + 1)) }", "  return 0", "}" ])
  , ("an overflow in a while let subject", program
      [ "fn main() -> Int {", "  var n = 9223372036854775806", "  while let Some(m) = Some(n + 1) { print(display(m))", "    n = m }", "  return 0", "}" ])
  , ("an overflow in a let else subject precedes its fallback", program
      [ "fn main() -> Int {", "  print(\"start\")", "  var n = 9223372036854775807"
      , "  let Some(value) = Some(n + 1) else { print(\"unreachable fallback\")", "    return 0 }"
      , "  print(display(value))", "  return 0", "}" ])
  , ("a let else fallback preserves output and its failure span", program
      [ "fn main() -> Int {", "  let held: Option[Int] = None", "  var n = 9223372036854775807"
      , "  let Some(value) = held else { print(\"fallback\")", "    return n + 1 }"
      , "  print(display(value))", "  return 0", "}" ])
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> shapes <> body)
