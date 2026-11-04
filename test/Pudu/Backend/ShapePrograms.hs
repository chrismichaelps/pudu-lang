{-| @Test.Backend.ShapePrograms — record shapes across modules, calls
    through function-valued fields, and assignments used as values. -}
module Pudu.Backend.ShapePrograms (shapeSuccessPrograms, shapeModulePrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

shapeSuccessPrograms :: [(String, Text, Text)]
shapeSuccessPrograms =
  [ ("a record of aliases holding a function, called through its field", program
      [ "type Name = Str", "type Gate = fn(Str) -> Int", "type Holder = { name: Name, admits: Gate }"
      , "", "fn main() -> Int {", "  let held = Holder{name: \"pudu\", admits: fn(reader: Str) -> Int { reader.length() }}"
      , "  print(display(held.name.length() * 10 + (held.admits)(\"abc\")))", "  0", "}" ]
    , "43\n")
  , ("a method of a field's name wins, and arguments run before the receiver", program
      [ "type Task = { run: fn(Int) -> Int, name: Str }", "", "trait Runs {"
      , "  fn run(self: Task, n: Int) -> Int", "}", ""
      , "impl Runs for Task {", "  fn run(self: Task, n: Int) -> Int { n + 1000 }", "}"
      , "", "fn noted(n: Int) -> Int {", "  print(\"arg \" + display(n))"
      , "  n", "}", ""
      , "fn main() -> Int {", "  let job = Task{run: |n| n * 2, name: \"t\"}", "  print(display(job.run(noted(3))) + \" \" + display((job.run)(noted(4))))"
      , "  let picked = job.run", "  print(display(picked(5)))", "  0"
      , "}" ]
    , "arg 3\narg 4\n1003 1004\n10\n")
  , ("mutually recursive records in one module", program
      [ "type Node = { label: Int, parent: Option[Wrap] }", "type Wrap = { node: Node }", ""
      , "fn depth(node: Node) -> Int {", "  match node.parent {", "    case Some(wrapped) => 1 + depth(wrapped.node)"
      , "    case None => 0", "  }", "}"
      , "", "fn main() -> Int {", "  let root = Node{label: 1, parent: None}"
      , "  let child = Node{label: 2, parent: Some(Wrap{node: root})}", "  print(show(child))", "  print(display(depth(child) * 10 + child.label))"
      , "  0", "}" ]
    , "Node{label: 2, parent: Some(Wrap{node: Node{label: 1, parent: None}})}\n12\n")
  , ("assignments used as arm, if-let and binding values", program
      [ "type Box = { mut count: Int }", "", "fn main() -> Int {"
      , "  var parts: Array[Str] = []", "  var box = Box{count: 0}", "  for word in [\"a\", \"\", \"b\"] {"
      , "    match word {", "      case \"\" => box.count = box.count + 1", "      case w => parts = parts.push(w)"
      , "    }", "  }", "  var total = 0"
      , "  let options = [Some(2), None, Some(5)]", "  for o in options {", "    if let Some(n) = o { total = total + n } else { total = total - 1 }"
      , "  }", "  let unit = (total = total * 2)", "  print(show(parts) + \" \" + show(box) + \" \" + display(total) + \" \" + show(unit))"
      , "  return 0", "}" ]
    , "[\"a\", \"b\"] Box{count: 1} 12 ()\n")
  ]

{-| Programs of several modules, each with the files beside its root. -}
shapeModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
shapeModulePrograms =
  [ ( "records that reach each other across two modules"
    , [ ("Node.pudu", Text.unlines
          [ "module Node", "", "import Wrap {Wrap}"
          , "", "export type Node = { label: Int, parent: Option[Wrap] }", ""
          , "export fn depth(node: Node) -> Int {", "  match node.parent {", "    case Some(wrapped) => 1 + depth(wrapped.node)"
          , "    case None => 0", "  }", "}" ])
      , ("Wrap.pudu", Text.unlines
          [ "module Wrap", "", "import Node {Node}"
          , "", "export type Wrap = { node: Node }", ""
          , "export fn wrap(node: Node) -> Wrap { Wrap{node} }", "", "export fn unwrap(value: Wrap) -> Node { value.node }" ]) ]
    , program
        [ "import Node {Node, depth}", "import Wrap {wrap, unwrap}", ""
        , "fn main() -> Int {", "  let root = Node{label: 1, parent: None}", "  let child = Node{label: 2, parent: Some(wrap(root))}"
        , "  let grandchild = Node{label: 3, parent: Some(wrap(child))}", "  print(display(depth(grandchild) * 10 + unwrap(wrap(grandchild)).label))", "  0"
        , "}" ]
    , "23\n" )
  , ( "a record whose fields are another module's aliases"
    , [ ("Names.pudu", Text.unlines
          [ "module Names", "", "export type Name = Str"
          , "", "export type Gate = fn(Str) -> Int", ""
          , "export fn named() -> Name { \"pudu\" }" ])
      , ("Holder.pudu", Text.unlines
          [ "module Holder", "", "import Names"
          , "", "export type Holder = { name: Names.Name, admits: Names.Gate }" ]) ]
    , program
        [ "import Holder", "import Names", ""
        , "fn main() -> Int {", "  let held = Holder.Holder{name: \"pudu\", admits: fn(reader: Str) -> Int { reader.length() }}", "  let named = Holder.Holder{name: Names.named(), admits: held.admits}"
        , "  let admits = named.admits", "  print(named.name + \" \" + display(held.admits(\"ab\")))", "  print(display(held.name.length() * 10 + admits(\"abc\")))"
        , "  0", "}" ]
    , "pudu 2\n43\n" )
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
