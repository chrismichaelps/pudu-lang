{-| @Test.Backend.RenderingCallablePrograms — rendering values keep builtin semantics. -}
module Pudu.Backend.RenderingCallablePrograms
  ( renderingCallableSuccessPrograms, renderingCallableRefusalPrograms, renderingCallableModulePrograms ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Pudu.Comptime.Limits (callDepthLimit)

renderingCallableSuccessPrograms :: [(String, Text, Text, Text)]
renderingCallableSuccessPrograms =
  [
    ("rendering builtin signatures and identities coexist", program
      [ "fn main() -> Int {"
      , "  let integer: fn(Int) -> Str = display"
      , "  let text: fn(Str) -> Str = display"
      , "  let quoted: fn(Str) -> Str = show"
      , "  print(integer(42))"
      , "  print(text(\"raw\"))"
      , "  print(quoted(\"a\\n\"))"
      , "  print(display(integer == display))"
      , "  print(display(text == show))"
      , "  print(show(quoted))"
      , "  0"
      , "}" ]
    , "42\nraw\n\"a\\n\"\ntrue\nfalse\n<builtin show>\n", "")
  , ("rendering builtins specialize through generic callers", program
      [ "fn render[T](value: T, converter: fn(T) -> Str) -> Str { converter(value) }"
      , "fn main() -> Int {"
      , "  print(display(render(340282366920938463463374607431768211455u128, show) == show(340282366920938463463374607431768211455u128)))"
      , "  print(display(render((), display) == \"()\"))"
      , "  print(display(render(true, show) == \"true\"))"
      , "  print(display(render(1.25f32, show) == show(1.25f32)))"
      , "  print(display(render('é', display) == display('é')))"
      , "  print(display(render([\"a\", \"b\"], show) == show([\"a\", \"b\"])))"
      , "  print(display(render((Some(4), \"x\"), display) == display((Some(4), \"x\"))))"
      , "  0"
      , "}" ]
    , "true\ntrue\ntrue\ntrue\ntrue\ntrue\ntrue\n", "")
  , ("rendering values survive records captures returns and operand effects", program
      [ " type Renderer = { render: fn(Str) -> Str }"
      , "fn choose() -> fn(Str) -> Str { display }"
      , "fn capture(convert: fn(Str) -> Str) -> fn(Str) -> Str { |value| convert(value) }"
      , "fn main() -> Int {"
      , "  let holder = Renderer{render: show}"
      , "  print(holder.render({ print(\"argument\")\n \"held\" }))"
      , "  print(capture(choose())(\"captured\"))"
      , "  let printers: Array[fn(Str) -> Str] = [display, show]"
      , "  for printer in printers { print(printer(\"x\")) }"
      , "  0"
      , "}" ]
    , "argument\n\"held\"\ncaptured\nx\n\"x\"\n", "")
  , ("nearer source and local rendering declarations win", program
      [ "fn display(value: Str) -> Str { \"user:\" + value }"
      , "fn main() -> Int {"
      , "  let render = display"
      , "  print(show(render))"
      , "  print(render(\"x\"))"
      , "  let show: fn(Str) -> Str = |text| \"local:\" + text"
      , "  print(show(\"y\"))"
      , "  0"
      , "}" ]
    , "<fn display>\nuser:x\nlocal:y\n", "")
  , ("rendering function arguments use callable rendering", program
      [ "fn main() -> Int {"
      , "  let repr: fn(fn(Int) -> Str) -> Str = show"
      , "  let render: fn(Int) -> Str = display"
      , "  print(repr(render))"
      , "  0"
      , "}" ]
    , "<builtin display>\n", "")
  , ("rendering builtin entry reports its tag", program
      [ "fn main() -> fn(Int) -> Str { display }" ]
    , "<builtin display>\n", "")
  , ("owned display identity retains and releases text results", program
      [ "fn main() -> Int {"
      , "  let convert: fn(Str) -> Str = display"
      , "  var text = \"x\".repeat(8192)"
      , "  for index in 0..40 { text = convert(text) }"
      , "  print(show(text.length()))"
      , "  0"
      , "}" ]
    , "8192\n", "")
  , ("rendering argument transfer bypasses the builtin invocation", program
      [ "fn stop() -> Int {"
      , "  let render: fn(Int) -> Str = show"
      , "  render({ print(\"transfer\")\n return 7 })"
      , "  99", "}"
      , "fn main() -> Int { print(display(stop()))\n 0 }" ]
    , "transfer\n7\n", "")
  , ("rendering builtin does not descend at the source depth limit", deep
      [ "fn main() -> Int { print(descend(" <> number (callDepthLimit - 1) <> ", display))\n 0 }" ]
    , "7\n", "")
  ]

renderingCallableRefusalPrograms :: [(String, Text)]
renderingCallableRefusalPrograms =
  [
    ("rendering builtin unary failures name builtin", program
      [ "fn main() -> Int { let renderer: fn(Int) -> Str = show\n let invalid = -renderer\n print(display(invalid))\n 0 }" ])
  , ("rendering builtin ordering is refused after operand effects", program
      [ "fn left() -> fn(Int) -> Str { print(\"left\")\n display }"
      , "fn right() -> fn(Int) -> Str { print(\"right\")\n show }"
      , "fn main() -> Int { let invalid = left() < right()\n print(display(invalid))\n 0 }" ])
  , ("rendering builtin map keys retain runtime refusal", program
      [ "fn main() -> Int { let renderer: fn(Int) -> Str = show\n let invalid = mapOf([(renderer, 1)])\n print(display(invalid))\n 0 }" ])
  , ("rendering callable arguments fail before dispatch", program
      [ "fn main() -> Int { let renderer: fn(Int) -> Str = show\n print(renderer({ print(\"argument\")\n 1 / 0 }))\n 0 }" ])
  , ("source rendering callable still descends at the same boundary", deep
      [ "fn custom(value: Int) -> Str { display(value) }"
      , "fn main() -> Int { print(descend(" <> number (callDepthLimit - 1) <> ", custom))\n 0 }" ])
  ]

deep :: [Text] -> Text
deep body = program
  ([ "fn descend(n: Int, render: fn(Int) -> Str) -> Str {"
   , "  if n == 0 { return render(7) }", "  descend(n - 1, render)", "}" ] <> body)

number :: Int -> Text
number = Text.pack . show

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

renderingCallableModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
renderingCallableModulePrograms =
  [("rendering callable specializations retain canonical nominal owners",
    [("First.pudu", provider "First" "Int"), ("Second.pudu", provider "Second" "Str")], program
      [ "import First as A", "import Second as B"
      , "fn main() -> Int {"
      , "  print(display(A.renderer()(A.Token{value: 7}) == display(A.Token{value: 7})))"
      , "  print(display(B.renderer()(B.Token{value: \"x\"}) == display(B.Token{value: \"x\"})))"
      , "  0", "}" ], "true\ntrue\n")]
 where
  provider name field = Text.unlines
    [ "module " <> name, "export type Token = { value: " <> field <> " }"
    , "export fn renderer() -> fn(Token) -> Str { display }" ]
