{-| @Test.Backend.KernelCountedPrograms — library-importing kernel programs shared by
    the refusal conformance cases and the counted-allocation run. Each body runs
    to completion; a refusal case appends its refusing tail. -}
module Pudu.Backend.KernelCountedPrograms
  ( flatTableProgram
  , codecProgram
  , kernelCountedLibraryPrograms
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

{-| Library programs that finish normally, for the counted-allocation run. -}
kernelCountedLibraryPrograms :: [(String, Text)]
kernelCountedLibraryPrograms =
  [ ("the flat table primitives over growth, deletion and degenerate tables", flatTableProgram [])
  , ("the JSON, XML and CSV codecs over accepted and refused inputs", codecProgram [])
  ]

{-| The flat-table program with @ending@ run before it returns. -}
flatTableProgram :: [Text] -> Text
flatTableProgram ending = program (flatTableBody <> ending <> ["  0", "}"])

{-| The codec program with @ending@ run before it returns. -}
codecProgram :: [Text] -> Text
codecProgram ending = program (codecBody <> ending <> ["  0", "}"])

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

flatTableBody :: [Text]
flatTableBody =
  [ "import Std.FlatMap as Flat"
  , "import Std.FlatMap {FlatMap}"
  , ""
  , "fn key(index: Int) -> UInt64 {"
  , "  match convertInteger[UInt64](index) { case Some(word) => word"
  , "    case None => 0u64 }"
  , "}"
  , ""
  , "fn main() -> Int {"
  , "  var table: FlatMap[Str] = swissTableEmpty(3)"
  , "  print(show(table) + display(swissTableSize(&table)) + show(swissTableLookup(&table, 4u64)) + show(swissTableEntries(&table)))"
  , "  for index in 0..40 { table = swissTableInsert(&table, key(index * 7919), \"v\" + display(index)) }"
  , "  print(display(table.capacity) + \" \" + display(swissTableSize(&table)) + show(swissTableLookup(&table, 7919u64)) + show(swissTableLookup(&table, 5u64)))"
  , "  let before = table"
  , "  table = swissTableInsert(&table, 7919u64, \"again\")"
  , "  for index in 0..20 { table = swissTableDelete(&table, key(index * 2 * 7919)) }"
  , "  table = swissTableDelete(&table, 99u64)"
  , "  print(display(swissTableSize(&table)) + show(swissTableLookup(&table, 7919u64)) + show(swissTableLookup(&table, 0u64)) + show(swissTableLookup(&before, 0u64)) + display(swissTableSize(&before)))"
  , "  for index in 0..10 { table = swissTableInsert(&table, key(index * 2 * 7919), \"back\") }"
  , "  print(show(swissTableEntries(&table)))"
  , "  print(show(table))"
  , "  let made = Flat.empty[Int](100)"
  , "  let filled = Flat.insert(&made, 18446744073709551615u64, 5)"
  , "  print(display(made.capacity) + show(Flat.get(&filled, 18446744073709551615u64)) + display(Flat.containsKey(&filled, 1u64)) + display(Flat.size(&filled)) + show(Flat.entries(&filled)) + display(Flat.isEmpty(&made)) + show(Flat.remove(&filled, 18446744073709551615u64)))"
  , "  let odd: FlatMap[Int] = FlatMap{capacity: 0, count: 0, ctrl: bucketsOf(), slots: bucketsOf()}"
  , "  let grown = swissTableInsert(&odd, 3u64, 4)"
  , "  print(show(grown) + show(swissTableLookup(&grown, 3u64)) + show(swissTableDelete(&grown, 3u64)))"
  , "  let small: FlatMap[Int] = FlatMap{capacity: 3, count: 0, ctrl: bucketsOf(), slots: bucketsOf()}"
  , "  let three = swissTableInsert(&swissTableInsert(&small, 1u64, 1), 2u64, 2)"
  , "  print(show(three) + show(swissTableLookup(&three, 2u64)) + show(swissTableLookup(&three, 1u64)))"
  , "  let insert: fn(&FlatMap[Str], UInt64, Str) -> FlatMap[Str] = swissTableInsert"
  , "  let size: fn(&FlatMap[Str]) -> Int = swissTableSize"
  , "  let find: fn(&FlatMap[Str], UInt64) -> Option[Str] = swissTableLookup"
  , "  let fresh: fn(Int) -> FlatMap[Str] = swissTableEmpty"
  , "  let one = insert(&fresh(1), 9u64, \"nine\")"
  , "  print(show(insert) + display(size(&one)) + show(find(&one, 9u64)) + show(find(&one, 8u64)))"
  ]

codecBody :: [Text]
codecBody =
  [ "import Std.Json as J"
  , "import Std.Json {Json, Null, Boolean, Number, Fractional, Text, List, Object}"
  , "import Std.Xml as Xml"
  , "import Std.Csv as Csv"
  , ""
  , "fn main() -> Int {"
  , "  let texts = [ \"null\", \" true \", \"false\", \"0\", \"-0\", \"-12\", \"9223372036854775807\", \"9223372036854775808\", \"-9223372036854775808\", \"1.5\", \"-2e10\", \"1E+2\", \"01\", \"1.\", \".5\", \"1e\", \"-\", \"\\\"\\\"\", \"\\\"a\\\\n\\\\t\\\\\\\"\\\\\\\\\\\\/\\\\b\\\\f\\\\r\\\"\", \"\\\"\\\\u00e9\\\\u4e2d\\\\ud83d\\\\ude00\\\\u0000x\\\"\", \"\\\"\\\\ud83d\\\"\", \"\\\"\\\\udc00\\\"\", \"\\\"\\\\ud83dx\\\"\", \"\\\"\\\\u12g4\\\"\", \"\\\"bad\\\\q\\\"\", \"\\\"open\", \"\\\"h\233\&llo \9731\& \128512\&\\\"\", \"[]\", \"[ ]\", \"[1, 2 ,3]\", \"[1,]\", \"[,1]\", \"[1 2]\", \"\\{\\}\", \"\\{ \\}\", \"\\{\\\"a\\\":1,\\\"b\\\":[true,null,\\{\\\"c\\\":\\\"d\\\"\\}],\\\"a\\\":2\\}\", \"\\{\\\"a\\\" 1\\}\", \"\\{a:1\\}\", \"\\{\\\"a\\\":1,\\}\", \"[[[[[[[[[[1]]]]]]]]]]\", \"tru\", \"nulll\", \"1 2\", \"\", \"  \", \"[\\\"x\\\"]  \\n\\t\", \"\\\"tab\\there\\\"\", \"\\{\\\"k\\\":-0.0e-0\\}\" ]"
  , "  for text in texts {"
  , "    let decoded = jsonDecode(text)"
  , "    match decoded {"
  , "      case Some(value) => print(show(value) + \" | \" + jsonEncode(&value, false) + \" | \" + jsonEncode(&value, true))"
  , "      case None => print(\"none: \" + show(J.decode(text)))"
  , "    }"
  , "  }"
  , "  var deep = \"\""
  , "  for index in 0..512 { deep = deep + \"[\" }"
  , "  var close = \"\""
  , "  for index in 0..512 { close = close + \"]\" }"
  , "  print(display(match jsonDecode(deep + close) { case Some(_) => 1"
  , "    case None => 0 }) + display(match jsonDecode(\"[\" + deep + close + \"]\") { case Some(_) => 1"
  , "    case None => 0 }))"
  , "  let built = Json.Object([(\"ctl\", Json.Text(\"\\u{1}\\u{1f}\\u{7f}\\\"\\\\/\")), (\"n\", Json.Number(-9223372036854775807 - 1)), (\"f\", Json.Fractional(\"1.50\")), (\"l\", Json.List([Json.Null, Json.Boolean(false), Json.List([]), Json.Object([])]))])"
  , "  print(jsonEncode(&built, false))"
  , "  print(jsonEncode(&built, true))"
  , "  print(J.encode(&built) + show(J.decode(J.encodePretty(&built)) == Ok(built)))"
  , "  let documents = [ \"<a/>\", \"<a></a>\", \"  <?xml version=\\\"1.0\\\"?>\\n<!-- note --><root a=\\\"1\\\" b='two &amp; &lt;3&gt; &quot;q&quot; &apos;s&apos; &#65;&#x42;&#x1F600;&#xD800;&#99999999;&unknown;&#;&#x; &toolongentityname; & alone'>text <b>bold</b><!-- c --><![CDATA[raw <&> ]]><?pi x?> tail&amp;\\n <c d=\\\"\\\"/> \\u{a0}\\u{3000} </root> trailing\", \"<a b=\\\"1\\\" b=\\\"2\\\"/>\", \"<a b=1/>\", \"<a b/>\", \"<a\", \"<a>\", \"<a></b>\", \"<a><b></a></b>\", \"<!DOCTYPE x><a/>\", \"<?xml?\", \"<!-- x\", \"\", \"   \", \"text\", \"<a>&#x110000;&#12;&#0;</a>\", \"<ns:tag xmlns:ns=\\\"u\\\"><ns:child/></ns:tag>\", \"<a>\\n  <b/>\\n</a  >\", \"<a x = 'y' ></a>\", \"< a/>\", \"<a/ >\", \"<\233\& \252\&=\\\"\241\&\\\">\223\&</\233\&>\", \"<a><![CDATA[x]]</a>\", \"<a><?pi</a>\", \"<a><!-- x</a>\", \"<a>]]></a>\" ]"
  , "  for document in documents {"
  , "    match xmlDecode(document) {"
  , "      case Some(tag) => print(show(tag))"
  , "      case None => print(\"none: \" + show(Xml.decode(document)))"
  , "    }"
  , "  }"
  , "  var nest = \"\""
  , "  var unnest = \"\""
  , "  for index in 0..512 { nest = nest + \"<n>\""
  , "    unnest = unnest + \"</n>\" }"
  , "  print(display(match xmlDecode(nest + unnest) { case Some(_) => 1"
  , "    case None => 0 }) + display(match xmlDecode(\"<n>\" + nest + unnest + \"</n>\") { case Some(_) => 1"
  , "    case None => 0 }))"
  , "  let sheets = [ \"a,b,c\\n1,2,3\\n\", \"a,b\\r\\n\\\"q,1\\\",\\\"he said \\\"\\\"hi\\\"\\\"\\\"\\r\\nlast,row\", \"\", \"\\n\\n\", \"no newline\", \"x,\\\"open\\n\", \"x,\\\"q\\\"\", \"\233\&,\9731\&\\n\128512\&,\\n\", \"a\\r,b\\r\\n\", \"\\\"a\\\"b\\\"c\\\",d\\n\", \"a,b\\n\\\"\" ]"
  , "  for sheet in sheets {"
  , "    print(show(csvRecords(sheet.toBytes(), \",\")) + show(csvRecords(sheet.toBytes(), \";\")))"
  , "  }"
  , "  print(show(csvRecords(bytesOf([97u8, 255u8, 10u8]), \",\")) + show(csvRecords(bytesOf([97u8, 10u8, 255u8]), \",\")) + show(csvRecords(bytesOf([97u8, 10u8, 255u8, 44u8]), \",\")) + show(csvRecords(bytesOf([195u8, 10u8]), \",\")))"
  , "  let decode = jsonDecode"
  , "  let encode = jsonEncode"
  , "  let xml = xmlDecode"
  , "  let csv = csvRecords"
  , "  print(show(decode) + show(decode(\"[1]\")) + encode(&Json.Null, true) + show(xml(\"<q/>\")) + show(csv(\"a\\n\".toBytes(), \",\")) + show(encode))"
  ]
