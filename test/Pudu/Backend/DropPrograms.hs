{-| @Test.Backend.DropPrograms — values that need drop are dropped once, in
    reverse declaration order, on every way a scope ends, with the same trace
    in the interpreter and native code. -}
module Pudu.Backend.DropPrograms
  ( dropSuccessPrograms
  , dropStopPrograms
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| Programs that finish, with the trace both engines print. -}
dropSuccessPrograms :: [(String, Text, Text)]
dropSuccessPrograms =
  [ ( "every way a scope ends drops what it owns, newest first"
    , program
        [ "type Pair = { left: Res, right: Res }"
        , "fn make(name: Str) -> Res { Res{name: name} }"
        , "fn consume(r: Res) -> () {"
        , "  let _ = print(\"consume \" + r.name)"
        , "}"
        , "fn passBack(r: Res) -> Res { r }"
        , "fn early(flag: Bool) -> Int {"
        , "  let guard = make(\"guard\")"
        , "  if flag { return 1 }"
        , "  let late = make(\"late\")"
        , "  2"
        , "}"
        , "fn fallible(ok: Bool) -> Result[Int, Str] {"
        , "  let held = make(\"held\")"
        , "  let value: Result[Int, Str] = if ok { Ok(1) } else { Err(\"no\") }"
        , "  let got = value?"
        , "  Ok(got + 1)"
        , "}"
        , "fn conditional(flag: Bool) -> Int {"
        , "  let r = make(\"cond\")"
        , "  if flag { let taken = r }"
        , "  0"
        , "}"
        , "fn main() -> Int {"
        , "  let a = make(\"a\")"
        , "  let b = make(\"b\")"
        , "  {"
        , "    let inner = make(\"inner\")"
        , "    let _ = print(\"in block\")"
        , "  }"
        , "  consume(make(\"arg\"))"
        , "  let kept = passBack(make(\"back\"))"
        , "  var v = make(\"v1\")"
        , "  v = make(\"v2\")"
        , "  let _ = make(\"discard\")"
        , "  make(\"statement\")"
        , "  let _ = print(\"early \" + display(early(true)))"
        , "  let _ = print(\"early \" + display(early(false)))"
        , "  let _ = print(\"cond \" + display(conditional(true)))"
        , "  let _ = print(\"cond \" + display(conditional(false)))"
        , "  let _ = print(show(fallible(false)))"
        , "  var i = 0"
        , "  while i < 2 {"
        , "    let turn = make(\"turn\" + display(i))"
        , "    i = i + 1"
        , "    if i == 1 { continue }"
        , "    break"
        , "  }"
        , "  let p = Pair{left: make(\"left\"), right: make(\"right\")}"
        , "  let o = Some(make(\"some\"))"
        , "  match o {"
        , "    case Some(r) => { let _ = print(\"matched \" + r.name) }"
        , "    case None => { }"
        , "  }"
        , "  let _ = print(\"end\")"
        , "  0"
        , "}"
        ]
    , lines'
        [ "in block", "drop inner", "consume arg", "drop arg", "drop v1", "drop discard"
        , "drop statement", "drop guard", "early 1", "drop late", "drop guard", "early 2"
        , "drop cond", "cond 0", "drop cond", "cond 0"
        , "drop held", "Err(\"no\")", "drop turn0", "drop turn1", "matched some", "drop some"
        , "end", "drop left", "drop right", "drop v2", "drop back", "drop b", "drop a" ] )
  , ( "a value's own drop runs before its parts, and replaced values drop before the store"
    , program
        [ "type Holder = { label: Str, first: Res, second: Option[Res] }"
        , "impl Drop for Holder {"
        , "  fn drop(self: &mut Self) -> () {"
        , "    let _ = print(\"drop holder \" + self.label)"
        , "  }"
        , "}"
        , "fn pair() -> (Res, Res) { (Res{name: \"p1\"}, Res{name: \"p2\"}) }"
        , "fn main() -> Int {"
        , "  let h = Holder{label: \"h\", first: Res{name: \"f\"}, second: Some(Res{name: \"s\"})}"
        , "  let (x, y) = pair()"
        , "  var w = Res{name: \"w1\"}"
        , "  var n = 0"
        , "  while n < 3 {"
        , "    w = Res{name: \"w\" + display(n + 2)}"
        , "    n = n + 1"
        , "  }"
        , "  let moved = w"
        , "  let _ = print(\"done \" + x.name + y.name + moved.name)"
        , "  0"
        , "}"
        ]
    , lines'
        [ "drop w1", "drop w2", "drop w3", "done p1p2w4", "drop w4", "drop p2", "drop p1"
        , "drop holder h", "drop f", "drop s" ] )
  , ( "a closure drops the parameter it owns when the closure ends"
    , program
        [ "fn make(name: Str) -> Res { Res{name: name} }"
        , "fn apply(f: fn(Res) -> Int) -> Int { f(make(\"arg\")) }"
        , "fn main() -> Int {"
        , "  let _ = apply(|r: Res| {"
        , "    let _ = print(\"in \" + r.name)"
        , "    0"
        , "  })"
        , "  let _ = print(\"after\")"
        , "  0"
        , "}"
        ]
    , lines' [ "in arg", "drop arg", "after" ] )
  , ( "a task owns its async function's parameters and drops them when it ends, named or not"
    , program
        [ "async fn useIt(r: Res) -> Int {"
        , "  let _ = print(\"task \" + r.name)"
        , "  1"
        , "}"
        , "async fn ignore(r: Res) -> Int { 2 }"
        , "async fn main() -> Result[Int, Str] {"
        , "  let pending = useIt(Res{name: \"used\"})"
        , "  let _ = print(\"made\")"
        , "  let a = pending.await"
        , "  let b = ignore(Res{name: \"ignored\"}).await"
        , "  let lifted = async fn(r: Res) -> Int {"
        , "    let _ = print(\"lambda \" + r.name)"
        , "    3"
        , "  }"
        , "  let c = lifted(Res{name: \"lam\"}).await"
        , "  let _ = print(\"sum \" + display(a + b + c))"
        , "  Ok(0)"
        , "}"
        ]
    , lines'
        [ "made", "task used", "drop used", "drop ignored", "lambda lam", "drop lam", "sum 6" ] )
  ]

{-| Programs that stop: what each owns is dropped before the stop is reported,
    and both engines report it alike. -}
dropStopPrograms :: [(String, Text)]
dropStopPrograms =
  [ ( "a stop drops what every frame still owns, innermost first"
    , program
        [ "fn deeper(r: Res) -> Int {"
        , "  let inner = Res{name: \"inner\"}"
        , "  panic(\"stop \" + r.name)"
        , "}"
        , "fn main() -> Int {"
        , "  let a = Res{name: \"a\"}"
        , "  let b = Res{name: \"b\"}"
        , "  deeper(Res{name: \"param\"})"
        , "}"
        ] )
  ]

{-| A module declaring the resource every program drops. -}
program :: [Text] -> Text
program body = Text.unlines
  ([ "module Main", ""
   , "type Res = { name: Str }"
   , "impl Drop for Res {"
   , "  fn drop(self: &mut Self) -> () {"
   , "    let _ = print(\"drop \" + self.name)"
   , "  }"
   , "}"
   ] <> body)

lines' :: [Text] -> Text
lines' = Text.unlines
