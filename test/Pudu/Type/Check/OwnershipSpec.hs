{-| @Test.Type.Check.OwnershipSpec — moves of values that need drop -}
module Pudu.Type.Check.OwnershipSpec (moveProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import Test.QuickCheck ((===), Property, conjoin, counterexample)

import Pudu.Type.Check.Common (codes, compile, diagnosticContract)

moveProperties :: [(String, IO Property)]
moveProperties =
  [ ("values that need drop move once and are refused where a copy would escape", testOwnership)
  , ("every ownership refusal carries its code, span and help", testContracts)
  , ("an implementation of Drop has exactly the shape drop runs with", testDropShape)
  ]

resource :: [Text]
resource =
  [ "module M"
  , "type Res = { name: Str }"
  , "impl Drop for Res {"
  , "  fn drop(self: &mut Self) -> () {"
  , "    let _ = print(self.name)"
  , "  }"
  , "}"
  , "type Holder = { mut first: Res, second: Option[Res] }"
  , "fn take(r: Res) -> Str { r.name }"
  ]

inMain :: [Text] -> IO [Text]
inMain body = codes (mainSource body)

mainSource :: [Text] -> [Text]
mainSource body = resource <> ["fn main() -> Int {"] <> map ("  " <>) body <> ["  0", "}"]

testOwnership :: IO Property
testOwnership = do
  clean <- inMain ["let a = Res{name: \"a\"}", "let b = &a", "let _ = print(take(a))"]
  afterMove <- inMain ["let a = Res{name: \"a\"}", "let _ = print(take(a))", "let _ = print(a.name)"]
  maybeMoved <- inMain ["let a = Res{name: \"a\"}", "if true { let b = a } else { }", "let _ = print(a.name)"]
  inLoop <- inMain ["let a = Res{name: \"a\"}", "var i = 0", "while i < 2 { let b = take(a)", "  i = i + 1 }"]
  reinitialized <- inMain ["var a = Res{name: \"a\"}", "let _ = print(take(a))", "a = Res{name: \"b\"}", "let _ = print(a.name)"]
  fieldMove <- inMain ["let h = Holder{first: Res{name: \"f\"}, second: None}", "let f = h.first"]
  takenApart <- inMain ["let r = Res{name: \"r\"}", "match r {", "  case Res{name} => { let _ = print(name) }", "}"]
  explicitDrop <- inMain ["var r = Res{name: \"r\"}", "r.drop()"]
  inArray <- inMain ["let rs = [Res{name: \"r\"}]"]
  captured <- inMain ["let r = Res{name: \"r\"}", "let f = fn() -> Str { r.name }"]
  readTemporary <- inMain ["let _ = print(Res{name: \"t\"}.name)"]
  fieldStore <- inMain ["var h = Holder{first: Res{name: \"f\"}, second: None}", "h.first = Res{name: \"g\"}"]
  partBehind <- inMain ["let o = Some(Res{name: \"o\"})", "match o {", "  case Some(_) => { }", "  case None => { }", "}"]
  moduleValue <- codes (resource <> ["const SHARED = Res{name: \"s\"}", "fn main() -> Int { 0 }"])
  pure $ conjoin
    [ counterexample "borrowing and moving once is clean" (clean === [])
    , counterexample "a use after a move is refused" (afterMove === ["E4001"])
    , counterexample "a use after a move on some paths is refused" (maybeMoved === ["E4001"])
    , counterexample "a move in a loop is a use after a move on the next turn" (inLoop === ["E4001"])
    , counterexample "assigning a moved local makes it usable again" (reinitialized === [])
    , counterexample "a field that needs drop does not move out alone" (fieldMove === ["E4002"])
    , counterexample "a type with its own drop is not taken apart" (takenApart === ["E4002"])
    , counterexample "drop is not called by the program" (explicitDrop === ["E4003"])
    , counterexample "an array does not hold values that need drop" (inArray === ["E4004"])
    , counterexample "a closure does not capture a value that needs drop" (captured === ["E4004"])
    , counterexample "a module value does not hold a value that needs drop" (moduleValue === ["E4004"])
    , counterexample "a temporary that needs drop is not only read" (readTemporary === ["E4005"])
    , counterexample "a value that needs drop is not stored into a field" (fieldStore === ["E4006"])
    , counterexample "a pattern binds every part that needs drop" (partBehind === ["E4007"])
    ]

{-| Each refusal names the exact code, the span the reader can point at, and
    the help that says what to do instead. -}
testContracts :: IO Property
testContracts = do
  afterMove <- contractMain
    ["let a = Res{name: \"a\"}", "let _ = print(take(a))", "let _ = print(a.name)"]
    "a.name" "E4001" "use of moved value a"
    "a value that needs drop has one owner; borrow it with & to use it without moving it"
  maybeMoved <- contractMain
    ["let a = Res{name: \"a\"}", "if true { let b = a } else { }", "let _ = print(a.name)"]
    "a.name" "E4001" "use of a value that may have moved: a"
    "a value that needs drop has one owner; borrow it with & to use it without moving it"
  fieldMove <- contractMain
    ["let h = Holder{first: Res{name: \"f\"}, second: None}", "let f = h.first"]
    "h.first" "E4002" "cannot move a field that needs drop out of its record"
    "borrow it with & or move the whole record"
  takenApart <- contractMain
    ["let r = Res{name: \"r\"}", "match r {", "  case Res{name} => { let _ = print(name) }", "}"]
    "Res{name}" "E4002" "a Res cannot be taken apart: its drop needs the whole value"
    "bind the whole value to a name and read its fields through that name"
  explicitDrop <- contractMain
    ["var r = Res{name: \"r\"}", "r.drop()"]
    "drop()" "E4003" "drop runs at the end of ownership and cannot be called"
    "let the value go out of scope, or move it into a scope that ends where it should be dropped"
  inArray <- contractMain
    ["let rs = [Res{name: \"r\"}]"]
    "[Res{name: \"r\"}]" "E4004" "an array cannot hold a value that needs drop"
    "keep the value in a local, a record field, an Option or a Result"
  captured <- contractMain
    ["let r = Res{name: \"r\"}", "let f = fn() -> Str { r.name }"]
    "r.name" "E4004" "r needs drop and cannot be captured by a closure"
    "pass it to the closure as an argument instead"
  readTemporary <- contractMain
    ["let _ = print(Res{name: \"t\"}.name)"]
    "Res{name: \"t\"}" "E4005" "this value needs drop and is only read, so nothing would own it"
    "bind it to a name first"
  fieldStore <- contractMain
    ["var h = Holder{first: Res{name: \"f\"}, second: None}", "h.first = Res{name: \"g\"}"]
    "h.first" "E4006" "a value that needs drop can only be assigned to a local name"
    "assign the whole record to a local instead of storing into a field or reference"
  partBehind <- contractMain
    ["let o = Some(Res{name: \"o\"})", "match o {", "  case Some(_) => { }", "  case None => { }", "}"]
    "_) =>" "E4007" "this part of the value needs drop and is not bound"
    "bind it to a name so it has an owner that drops it"
  wrongMember <- contract
    [ "module M", "type Res = { name: Str }"
    , "impl Drop for Res {", "  fn other(self: &Self) -> () { }", "}" ]
    "fn other" "E4008" "Drop declares exactly fn drop(self: &mut Self) -> ()"
    "write the member as fn drop(self: &mut Self) -> () { ... }"
  wrongSelf <- contract
    [ "module M", "type Res = { name: Str }"
    , "impl Drop for Res {", "  fn drop(self: &Self) -> () { }", "}" ]
    "fn drop" "E4008" "Drop declares exactly fn drop(self: &mut Self) -> ()"
    "write the member as fn drop(self: &mut Self) -> () { ... }"
  pure $ conjoin
    [ counterexample "a use after a move points at the use" afterMove
    , counterexample "a maybe-moved use names the uncertainty" maybeMoved
    , counterexample "moving a droppable field names the field" fieldMove
    , counterexample "taking apart a Drop type names the pattern" takenApart
    , counterexample "an explicit drop names the member" explicitDrop
    , counterexample "an array holding a droppable value names the array" inArray
    , counterexample "a closure capture names the captured local" captured
    , counterexample "a read-only temporary names the temporary" readTemporary
    , counterexample "a field store names the field" fieldStore
    , counterexample "a wildcard part names the wildcard" partBehind
    , counterexample "a wrong Drop member names the member" wrongMember
    , counterexample "a wrong self names the member" wrongSelf
    ]

contractMain :: [Text] -> Text -> Text -> Text -> Text -> IO Property
contractMain body = contract (mainSource body)

contract :: [Text] -> Text -> Text -> Text -> Text -> IO Property
contract sourceLines needle code message help = do
  let source = Text.unlines sourceLines
  result <- compile source
  pure (diagnosticContract source needle code message (Just help) result)

testDropShape :: IO Property
testDropShape = do
  wrongMember <- codes
    [ "module M", "type Res = { name: Str }"
    , "impl Drop for Res {", "  fn other(self: &Self) -> () { }", "}" ]
  wrongSelf <- codes
    [ "module M", "type Res = { name: Str }"
    , "impl Drop for Res {", "  fn drop(self: &Self) -> () { }", "}" ]
  pure $ conjoin
    [ counterexample "the only member is drop" (wrongMember === ["E4008"])
    , counterexample "drop takes self: &mut Self" (wrongSelf === ["E4008"])
    ]
