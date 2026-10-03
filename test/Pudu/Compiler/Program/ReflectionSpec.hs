{-| @Test.Compiler.Program.ReflectionSpec — loaded reflection identity and owner contracts -}
module Pudu.Compiler.Program.ReflectionSpec (reflectionProgramProperties) where

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Pudu.Compiler.Program.Common (codes)
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

reflectionProgramProperties :: [(String, IO Property)]
reflectionProgramProperties =
  [ ("loaded Meta descriptors preserve owner and field types", testDescriptors)
  , ("loaded Meta refuses runtime references and homogeneous field assumptions", testRefusals)
  , ("loaded Meta receiver specialization also protects ordinary generic methods", testOrdinaryReceivers)
  ]

testDescriptors :: IO Property
testDescriptors = checkCases
  [ ("record properties and owner-specific read", record
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  let name: Str = field.name"
      , "  let held: F = field.get(self)"
      , "  let skipped: Bool = field.has(\"skip\")"
      , "  let wire: Str = field.attributeOr(\"json\", name)"
      , "  let default: Bool = field.attributeOr(\"default\", false)"
      , "}"
      ], [])
  , ("alias identity", fixture ["import Std.Meta as M"] "Record" False
      [ "comptime for field: M.Field[T, F] in M.fields[T]() {"
      , "  let held: F = field.get(self)"
      , "}"
      ], [])
  , ("selected field identity", fixture ["import Std.Meta {Field, fields, FieldAccess}"] "Record" False
      [ "comptime for field: Field[T, F] in fields[T]() {"
      , "  let held: F = field.get(self)"
      , "}"
      ], [])
  , ("variant properties and nested heterogeneous payload", fixture ["import Std.Meta"] "Sum" False
      [ "comptime for variant: Meta.Variant[T] in Meta.variants[T]() {"
      , "  let name: Str = variant.name"
      , "  let matches: Bool = variant.matches(self)"
      , "  comptime for field: Meta.Field[T, F] in variant.fields() {"
      , "    let held: F = field.get(self)"
      , "  }"
      , "}"
      ], [])
  , ("wrong field owner", record
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  let held = field.get(&true)"
      , "}"
      ], ["E3001"])
  , ("wrong field result", record
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  let held: Int = field.get(self)"
      , "}"
      ], ["E3001"])
  , ("wrong numeric owner", record
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  let held = field.get(&1)"
      , "}"
      ], ["E3001"])
  , ("captured field method keeps its owner", record
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  let get = field.get"
      , "  let held = get(&true)"
      , "}"
      ], ["E3001"])
  , ("wrong variant owner", fixture ["import Std.Meta"] "Sum" False
      [ "comptime for variant: Meta.Variant[T] in Meta.variants[T]() {"
      , "  let held = variant.matches(&true)"
      , "}"
      ], ["E3001"])
  , ("wrong numeric setter held type", fixture ["import Std.Meta"] "Record" True
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  field.set(self, 1)"
      , "}"
      ], ["E3001"])
  , ("rigid field bounds bind the actual method self", bounded
      [ "let held = field.get(self)", "let result: Bool = held.same(&held)" ], [])
  , ("rigid field method cannot infer a different self", bounded
      [ "let held = field.get(self)", "let result = held.same(&true)" ], ["E3001"])
  , ("wrong setter held type", fixture ["import Std.Meta"] "Record" True
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {"
      , "  field.set(self, true)"
      , "}"
      ], ["E3001"])
  , ("nameOf and ordinary arrays remain available", record
      [ "let name: Str = Meta.nameOf[T]()"
      , "comptime for number: Int in [1, 2] { let held: Int = number }"
      ], [])
  ]

bounded :: [Text] -> Text
bounded body = Text.unlines
  [ "module Probe", "import Std.Meta"
  , "trait Same { fn same(self: &Self, other: &Self) -> Bool }"
  , "trait Tag { fn tag(self: &Self) -> Str }"
  , "derive Tag for T: Record { fn tag(self: &T) -> Str {"
  , "  comptime for field: Meta.Field[T, F] in Meta.fields[T]() where F: Same {"
  ] <> Text.unlines (map ("    " <>) body <>
    ["  }", "  \"ok\"", "} }", "export fn main() -> Int { 0 }"])

testOrdinaryReceivers :: IO Property
testOrdinaryReceivers = checkCases
  [ ("result is tied to owner", ordinary ["let box = Box { value: true }", "let held: Int = box.read()"], ["E3001"])
  , ("captured result is tied to owner", ordinary ["let box = Box { value: true }", "let read = box.read", "let held: Int = read()"], ["E3001"])
  , ("argument is tied to owner", ordinary ["let box = Box { value: true }", "let held = box.keep(\"wrong\")"], ["E3001"])
  , ("captured argument is tied to owner", ordinary ["let box = Box { value: true }", "let keep = box.keep", "let held = keep(\"wrong\")"], ["E3001"])
  , ("borrowed owner is specialized", ordinary ["let box = Box { value: true }", "let borrow = &box", "let held: Int = borrow.read()"], ["E3001"])
  , ("receivers instantiate independently", ordinary
      [ "let first = Box { value: true }", "let second = Box { value: \"text\" }"
      , "let flag: Bool = first.read()", "let text: Str = second.read()"
      , "let keep = second.keep", "let held: Str = keep(text)"
      ], [])
  , ("constructor-wide Self returns the applied receiver", Text.unlines
      [ "module Probe", "trait Echo { fn echo(self: &Self) -> Self }"
      , "impl Echo for Array { fn echo(self: &Self) -> Self { *self } }"
      , "export fn main() -> Int {"
      , "  let held: Array[Bool] = [true].echo()", "  0", "}"
      ], [])
  , ("concrete implementation head keeps its arguments", Text.unlines
      [ "module Probe", "type Box[A] = { value: A }"
      , "trait Read { fn read(self: &Self) -> Int }"
      , "impl Read for Box[Int] { fn read(self: &Self) -> Int { self.value } }"
      , "export fn main() -> Int {"
      , "  let box = Box { value: true }", "  let held = box.read()", "  0", "}"
      ], ["E3001"])
  ]
 where
  ordinary body = Text.unlines
    ([ "module Probe", "type Box[A] = { value: A }"
     , "trait Read[A] { fn read(self: &Self) -> A }"
     , "trait Keep[A] { fn keep(self: &Self, value: A) -> A }"
     , "impl[A] Read[A] for Box[A] { fn read(self: &Self) -> A { self.value } }"
     , "impl[A] Keep[A] for Box[A] { fn keep(self: &Self, value: A) -> A { value } }"
     , "export fn main() -> Int {"
     ] <> map ("  " <>) body <> ["  0", "}"])

testRefusals :: IO Property
testRefusals = checkCases
  [ ("concrete fields cannot homogenize a record", record
      [ "comptime for field: Meta.Field[T, Int] in Meta.fields[T]() {"
      , "  let held: Int = field.get(self)"
      , "}"
      ], ["E3001"])
  , ("metadata source and annotation share an owner", record
      [ "comptime for field: Meta.Field[Int, F] in Meta.fields[T]() {}" ], ["E3001"])
  , ("owner type cannot replace a fresh field parameter", record
      [ "comptime for field: Meta.Field[T, T] in Meta.fields[T]() {}" ], ["E3001"])
  , ("a bound cannot turn a built-in type into a field parameter", boundedConcrete, ["E3001"])
  , ("field and variant sequences are distinct", record
      [ "comptime for variant: Meta.Variant[T] in Meta.fields[T]() {}" ], ["E3001"])
  , ("metadata is not an array", record
      [ "let held = Meta.fields[T]().push(1)" ], ["E3005"])
  , ("implicit field type cannot escape its loop", record
      [ "comptime for field: Meta.Field[T, F] in Meta.fields[T]() {}"
      , "let escaped: F = 1"
      ], ["E2011"])
  , ("runtime captured reflection is refused", Text.unlines
      [ "module Probe", "import Std.Meta as M", "export fn main() -> Int {"
      , "  let held = M.nameOf", "  0", "}"
      ], ["E2018"])
  , ("runtime selected reflection is refused", Text.unlines
      [ "module Probe", "import Std.Meta {fields}", "export fn main() -> Int {"
      , "  let held = fields", "  0", "}"
      ], ["E2018"])
  , ("unrelated Field cannot introduce an implicit parameter", Text.unlines
      [ "module Probe", "type Field[A, B] = {}"
      , "trait Tag { fn tag(self: &Self) -> Str }"
      , "derive Tag for T: Record { fn tag(self: &T) -> Str {"
      , "  comptime for field: Field[T, F] in [] {}"
      , "  \"ok\"", "} }", "export fn main() -> Int { 0 }"
      ], ["E2011"])
  ]
 where
  boundedConcrete = Text.unlines
    [ "module Probe", "import Std.Meta", "trait Marker {}"
    , "trait Tag { fn tag(self: &Self) -> Str }"
    , "derive Tag for T: Record { fn tag(self: &T) -> Str {"
    , "  comptime for field: Meta.Field[T, Int] in Meta.fields[T]() where Int: Marker {}"
    , "  \"ok\"", "} }", "export fn main() -> Int { 0 }"
    ]

record :: [Text] -> Text
record = fixture ["import Std.Meta"] "Record" False

fixture :: [Text] -> Text -> Bool -> [Text] -> Text
fixture imports shape mutable body = Text.unlines $
  ["module Probe"] <> imports <>
  [ "trait Tag { fn tag(self: " <> borrow <> "Self) -> Str }"
  , "derive Tag for T: " <> shape <> " { fn tag(self: " <> borrow <> "T) -> Str {"
  ] <> map ("  " <>) body <> ["  \"ok\"", "} }", "export fn main() -> Int { 0 }"]
 where
  borrow = if mutable then "&mut " else "&"

checkCases :: [(String, Text, [Text])] -> IO Property
checkCases cases = withSystemTempDirectory "pudu-meta-contracts" $ \directory -> do
  results <- mapM (check directory) cases
  pure (conjoin results)
 where
  check directory (label, source, expected) = do
    let path = directory </> "Probe.pudu"
    TextIO.writeFile path source
    actual <- codes path
    pure (counterexample label (actual === expected))
