{-| @Test.Backend.DefaultParameterPrograms — default parameter values,
    supplied in every combination, directly and through values, agree with
    the interpreter. -}
module Pudu.Backend.DefaultParameterPrograms
  ( defaultParameterSuccessPrograms, defaultParameterRefusalPrograms, defaultParameterModulePrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text

defaultParameterSuccessPrograms :: [(String, Text, Text, Text)]
defaultParameterSuccessPrograms =
  [ ("omitted defaults run in order through calls and values", program
      [ "fn noisy(label: Str) -> Int { print(label)"
      , " 7 }"
      , "fn greet(name: Str, punctuation: Str = \"!\", times: Int = noisy(\"default\")) -> Str {"
      , "  name.repeat(times) + punctuation"
      , "}"
      , "fn main() -> Int {"
      , "  print(greet(\"a\"))"
      , "  print(greet(\"b\", \"?\"))"
      , "  print(greet(\"c\", \".\", 2))"
      , "  let f = greet"
      , "  print(f(\"d\"))"
      , "  print(show(f))"
      , "  0"
      , "}" ]
    , "default\naaaaaaa!\ndefault\nbbbbbbb?\ncc.\ndefault\nddddddd!\n<fn greet>\n", "")
  , ("defaults read earlier parameters constants and generic parameters", program
      [ "const BASE: Int = 10"
      , "fn shift(value: Int, by: Int = value + BASE) -> Int { value + by }"
      , "fn pick[T](items: Array[T], index: Int = items.length() - 1) -> T { items[index] }"
      , "fn main() -> Int {"
      , "  print(display(shift(1)))"
      , "  print(display(shift(1, 2)))"
      , "  print(pick([\"x\", \"y\", \"z\"]))"
      , "  print(display(pick([1, 2], 0)))"
      , "  0"
      , "}" ]
    , "12\n3\nz\n1\n", "")
  , ("owned defaults and nested defaulted calls release their values", program
      [ "type Point = { x: Int, y: Int }"
      , "const ORIGIN: Point = Point{x: 0, y: 0}"
      , "fn tag(items: Array[Str] = [\"a\", \"b\"], label: Str = items.join(\"+\"), at: Point = ORIGIN) -> Str {"
      , "  label + \"@\" + show(at) + \"#\" + display(items.length())"
      , "}"
      , "fn outer(value: Int, inner: Str = tag([display(value)])) -> Str { inner }"
      , "fn main() -> Int {"
      , "  print(tag())"
      , "  print(tag([\"x\"]))"
      , "  print(tag([\"x\", \"y\"], \"given\"))"
      , "  print(tag([], \"\", Point{x: 1, y: 2}))"
      , "  print(outer(5))"
      , "  var total = 0"
      , "  for index in 0..300 { total = total + tag().length() + outer(index).length() }"
      , "  print(display(total))"
      , "  0"
      , "}" ]
    , "a+b@Point{x: 0, y: 0}#2\nx@Point{x: 0, y: 0}#1\ngiven@Point{x: 0, y: 0}#2\n@Point{x: 1, y: 2}#0\n5@Point{x: 0, y: 0}#1\n13690\n", "")
  , ("defaulted values survive captures arrays equality and rendering", program
      [ "fn greet(name: Str, punctuation: Str = \"!\") -> Str { name + punctuation }"
      , "type Holder = { speak: fn(Str, Str) -> Str }"
      , "fn main() -> Int {"
      , "  let f = greet"
      , "  let twice = |name: Str| f(name) + f(name, \"?\")"
      , "  print(twice(\"hi\"))"
      , "  let fs = [f, f]"
      , "  for g in fs { print(g(\"x\")) }"
      , "  print(display(f == greet))"
      , "  print(show(fs))"
      , "  0"
      , "}" ]
    , "hi!hi?\nx!\nx!\ntrue\n[<fn greet>, <fn greet>]\n", "")
  ]

defaultParameterRefusalPrograms :: [(String, Text)]
defaultParameterRefusalPrograms =
  [ ("a default's own call reports the depth limit", program
      [ "fn noisy(n: Int) -> Int { if n < 2 { print(\"default at \" + display(n)) }"
      , " n }"
      , "fn down(n: Int, note: Int = noisy(n)) -> Int {"
      , "  if n == 0 { return 0 }"
      , "  down(n - 1)"
      , "}"
      , "fn main() -> Int {"
      , "  down(20000)"
      , "}" ])
  , ("a default that fails stops after the supplied arguments", program
      [ "fn risky(value: Int, divisor: Int = value - 3) -> Int { 10 / divisor }"
      , "fn main() -> Int {"
      , "  print(display(risky(5)))"
      , "  print(display(risky(3, 1)))"
      , "  print(display(risky({ print(\"argument\")"
      , " 3 })))"
      , "  0"
      , "}" ])
  , ("a default with effects runs before a panic in the body", program
      [ "fn stop(reason: Str = { print(\"computing\")"
      , " \"default reason\" }) -> Int { panic(reason) }"
      , "fn main() -> Int {"
      , "  print(\"start\")"
      , "  stop()"
      , "}" ])
  ]

-- Literal defaults only: a default naming its own module's constant is still
-- read in the caller's module by the interpreter (#639).
defaultParameterModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
defaultParameterModulePrograms =
  [ ("defaults of another module's function fill through selective and qualified calls"
    , [("Lib.pudu", Text.unlines
    [ "module Lib"
    , ""
    , "export fn pad(text: Str, width: Int = 5, fill: Str = \".\") -> Str {"
    , "  var out = text"
    , "  while out.length() < width { out = out + fill }"
    , "  out"
    , "}" ])]
    , program
      [ "import Lib"
      , "import Lib {pad}"
      , ""
      , "fn main() -> Int {"
      , "  print(Lib.pad(\"ab\"))"
      , "  print(pad(\"ab\", 3))"
      , "  print(pad(\"ab\", 4, \"-\"))"
      , "  let p = pad"
      , "  print(p(\"z\"))"
      , "  0"
      , "}" ]
    , "ab...\nab.\nab--\nz....\n")
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
