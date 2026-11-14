{-| @Test.Backend.BytesPrograms — byte sequences against `Eval.Bytes`. -}
module Pudu.Backend.BytesPrograms (bytesSuccessPrograms, bytesRefusalPrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

bytesSuccessPrograms :: [(String, Text, Text)]
bytesSuccessPrograms =
  [ ("strided gathers groups and refuses a malformed shape", program
      [ "fn shown(value: Option[Bytes]) -> Str {"
      , "  match value {", "    case Some(bytes) => show(bytes.toArray())", "    case None => \"none\"", "  }", "}"
      , "fn main() -> Int {"
      , "  let pixels = bytesOf([1u8, 2u8, 3u8, 4u8, 5u8, 6u8, 7u8, 8u8, 9u8, 10u8])"
      , "  print(shown(pixels.strided(0, 3, 4)) + \" \" + shown(pixels.strided(1, 2, 3)) + \" \" + shown(pixels.strided(0, 0, 1)))"
      , "  print(shown(pixels.strided(9, 1, 1)) + \" \" + shown(pixels.strided(10, 1, 1)) + \" \" + shown(pixels.strided(99, 2, 5)))"
      , "  print(shown(pixels.strided(-1, 1, 1)) + \" \" + shown(pixels.strided(0, -1, 1)) + \" \" + shown(pixels.strided(0, 1, 0)) + \" \" + shown(pixels.strided(0, 3, 2)))"
      , "  print(shown(pixels.strided(2, 5, 100)) + \" \" + shown(pixels.strided(0, 1, 9223372036854775807)) + \" \" + shown(bytesOf([]).strided(0, 1, 1)))"
      , "  print(show(pixels.strided(0, 2, 2) == Some(pixels)))"
      , "  return 0", "}" ]
    , "[1, 2, 3, 5, 6, 7, 9, 10] [2, 3, 5, 6, 8, 9] []\n[10] [] []\nnone none none none\n[3, 4, 5, 6, 7] [1] []\ntrue\n")
  , ("every byte method, valid and invalid UTF-8, range slices, ordering and keys", program
      [ "fn text(raw: Array[UInt8]) -> Str {", "  match bytesOf(raw).toText() {", "    case Some(t) => \"Some(\" + t + \")\""
      , "    case None => \"None\"", "  }", "}"
      , "", "fn main() -> Int {", "  let hi = \"héllo\".toBytes()"
      , "  let none = bytesOf([])", "  print(show(hi) + \" \" + display(hi) + \" \" + show(none) + \" \" + display(hi.length()) + \" \" + display(none.isEmpty()) + \" \" + display(hi.isEmpty()))", "  print(show(hi.at(0)) + show(hi.at(5)) + show(hi.at(6)) + show(hi.at(-1)) + show(none.at(0)))"
      , "  print(show(hi.slice(1, 3)) + \" \" + show(hi.slice(-5, 99)) + \" \" + show(hi.slice(4, 2)) + \" \" + show(hi.take(2)) + \" \" + show(hi.take(99)) + \" \" + show(hi.drop(-3)) + \" \" + show(hi.drop(4)))", "  print(show(hi.concat(none)) + \" \" + show(none.concat(hi)) + \" \" + show(hi.concat(hi)))", "  let l = \"l\".toBytes()"
      , "  print(display(hi.indexOf(l)) + \" \" + display(hi.indexOf(none)) + \" \" + display(hi.indexOf(\"zz\".toBytes())) + \" \" + display(hi.contains(l)) + \" \" + display(hi.startsWith(\"h\".toBytes())) + \" \" + display(hi.endsWith(\"lo\".toBytes())) + \" \" + display(none.startsWith(none)) + \" \" + display(l.endsWith(hi)))", "  print(show(hi.reverse()) + \" \" + show(hi.toArray()) + \" \" + show(none.toArray()))", "  print(text([104u8, 105u8]) + \" \" + text([195u8, 169u8]) + \" \" + text([195u8]) + \" \" + text([192u8, 128u8]) + \" \" + text([237u8, 160u8, 128u8]) + \" \" + text([244u8, 144u8, 128u8, 128u8]) + \" \" + text([240u8, 159u8, 152u8, 128u8]) + \" \" + text([255u8]) + \" \" + text([224u8, 128u8, 128u8]) + \" \" + text([]))"
      , "  print(show(hi[1..3]) + \" \" + show(hi[..2]) + \" \" + show(hi[4..]) + \" \" + show(hi[..]))", "  print(display(hi == \"héllo\".toBytes()) + display(hi != none) + display((hi, 1) < (l, 0)) + display((none, 0) < (hi, 0)))", "  let keyed = mapOf([(\"b\".toBytes(), 1), (\"a\".toBytes(), 2), (none, 3)])"
      , "  print(show(keyed) + \" \" + show(setOf([l, hi, l])))", "  return 0", "}" ]
    , "0x68c3a96c6c6f 0x68c3a96c6c6f 0x 6 true false\nSome(104)Some(111)NoneNoneNone\n0xc3a9 0x68c3a96c6c6f 0x 0x68c3 0x68c3a96c6c6f 0x68c3a96c6c6f 0x6c6f\n0x68c3a96c6c6f 0x68c3a96c6c6f 0x68c3a96c6c6f68c3a96c6c6f\n3 0 -1 true true true true false\n0x6f6c6ca9c368 [104, 195, 169, 108, 108, 111] []\nSome(hi) Some(é) None None None None Some(😀) None None Some()\n0xc3a9 0x68c3 0x6c6f 0x68c3a96c6c6f\ntruetruetruetrue\n{0x: 3, 0x61: 2, 0x62: 1} #{0x68c3a96c6c6f, 0x6c}\n")
  , ("all byte values round-trip without signed narrowing", program
      [ "fn main() -> Int {"
      , "  var raw: Array[UInt8] = []", "  for n in 0..256 {"
      , "    if let Some(byte) = convertInteger[UInt8](n) { raw = raw.push(byte) }", "  }"
      , "  let bytes = bytesOf(raw)"
      , "  print(display(bytes.length()) + \" \" + display(bytes.toArray() == raw))"
      , "  print(show(bytes.at(0)) + \" \" + show(bytes.at(127)) + \" \" + show(bytes.at(128)) + \" \" + show(bytes.at(255)))"
      , "  print(show(bytes.slice(0, 2)) + \" \" + show(bytes.slice(254, 999)))"
      , "  print(display((bytesOf([127u8]), 0) < (bytesOf([128u8]), 0)))"
      , "  print(show(bytesOf([0u8, 255u8, 0u8]).indexOf(bytesOf([255u8, 0u8]))))"
      , "  let view = \"a\\0\".toBytes().concat(bytesOf([255u8])).drop(1).take(2)"
      , "  print(show(view) + \" \" + show(view.reverse()) + \" \" + show(view.toText()))"
      , "  return 0", "}" ]
    , "256 true\nSome(0) Some(127) Some(128) Some(255)\n0x0001 0xfeff\ntrue\n1\n0x00ff 0xff00 None\n")
  , ("a Bytes entry renders arbitrary bytes", program
      ["fn main() -> Bytes { bytesOf([0u8, 255u8]) }"]
    , "0x00ff\n")
  , ("an explicit Bytes entry return renders empty bytes", program
      ["fn main() -> Bytes { return bytesOf([]) }"]
    , "0x\n")
  , ("byte methods preserve argument order and captured storage", program
      [ "fn bytes(tag: Str) -> Bytes { print(tag)\n \"abcd\".toBytes() }"
      , "fn index(tag: Str, n: Int) -> Int { print(tag)\n n }"
      , "fn keep(bytes: &Bytes) -> Bytes { *bytes }"
      , "fn main() -> Int {"
      , "  print(show(bytes(\"receiver\").slice(index(\"from\", 1), index(\"to\", 3))))"
      , "  print(show(bytes(\"concat-receiver\").concat(bytes(\"concat-argument\"))))"
      , "  print(show(bytes(\"at-receiver\").at(index(\"at-index\", 2))))"
      , "  var value = bytesOf([0u8, 255u8])"
      , "  let captured = fn() -> Bytes => value"
      , "  value = bytesOf([1u8])"
      , "  print(show(captured()) + \" \" + show(keep(&value)))"
      , "  return 0", "}" ]
    , "receiver\nfrom\nto\n0x6263\nconcat-receiver\nconcat-argument\n0x6162636461626364\nat-receiver\nat-index\nSome(99)\n0x00ff 0x01\n")
  , ("folded bytes retain arbitrary data inside aggregates", program
      [ "type Packet = { payload: Bytes }"
      , "const RAW = bytesOf([0u8, 128u8, 255u8])"
      , "const EMPTY = bytesOf([])", "const PACKET = Packet{payload: RAW}"
      , "const PAIR = (RAW, \"é\".toBytes())"
      , "fn main() -> Int {"
      , "  print(show(RAW) + \" \" + show(RAW.toText()) + \" \" + show(EMPTY))"
      , "  print(show(PACKET) + \" \" + show(PAIR))"
      , "  print(display(RAW == PACKET.payload) + \" \" + show(RAW.drop(1)))"
      , "  return 0", "}" ]
    , "0x0080ff None 0x\nPacket{payload: 0x0080ff} (0x0080ff, 0xc3a9)\ntrue 0x80ff\n")
  , ("a large folded constant and escape-sensitive bytes are one literal each", program
      [ "const BIG: Bytes = cycled(60000)"
      , "const EDGES: Bytes = bytesOf([0u8, 34u8, 63u8, 92u8, 48u8, 0u8, 55u8, 127u8, 128u8, 255u8])"
      , "comptime fn cycled(count: Int) -> Bytes {"
      , "  var out: Array[UInt8] = []", "  var next = 0u8", "  var index = 0"
      , "  while index < count {", "    out = out.push(next)"
      , "    next = if next == 255u8 { 0u8 } else { next + 1u8 }", "    index = index + 1", "  }"
      , "  bytesOf(out)", "}"
      , "fn main() -> Int {"
      , "  print(display(BIG.length()) + \" \" + show(BIG.take(3)) + \" \" + show(BIG.drop(59997)) + \" \" + show(BIG.at(511)))"
      , "  print(show(EDGES) + \" \" + display(EDGES.length()) + \" \" + display(BIG.slice(256, 260) == BIG.take(4)))"
      , "  print(display(BIG == BIG) + \" \" + show(BIG.slice(254, 258)))"
      , "  0", "}" ]
    , "60000 0x000102 0x5d5e5f Some(255)\n0x00223f5c3000377f80ff 10 true\ntrue 0xfeff0001\n")
  , ("UTF-8 scalar boundaries and malformed continuations", program
      [ "fn isText(bytes: Bytes) -> Bool {"
      , "  match bytes.toText() {", "    case Some(_) => true", "    case None => false", "  }", "}"
      , "fn main() -> Int {"
      , "  let valid = [bytesOf([0u8]), bytesOf([127u8]), bytesOf([194u8, 128u8]), bytesOf([223u8, 191u8]), bytesOf([224u8, 160u8, 128u8]), bytesOf([237u8, 159u8, 191u8]), bytesOf([238u8, 128u8, 128u8]), bytesOf([239u8, 191u8, 191u8]), bytesOf([240u8, 144u8, 128u8, 128u8]), bytesOf([244u8, 143u8, 191u8, 191u8])]"
      , "  for bytes in valid { print(display(isText(bytes))) }"
      , "  let invalid = [bytesOf([128u8]), bytesOf([193u8, 191u8]), bytesOf([194u8, 127u8]), bytesOf([224u8, 160u8]), bytesOf([224u8, 160u8, 192u8]), bytesOf([237u8, 160u8, 128u8]), bytesOf([240u8, 143u8, 191u8, 191u8]), bytesOf([244u8, 144u8, 128u8, 128u8]), bytesOf([245u8, 128u8, 128u8, 128u8]), bytesOf([240u8, 144u8, 128u8])]"
      , "  for bytes in invalid { print(show(bytes.toText())) }"
      , "  return 0", "}" ]
    , Text.replicate 10 "true\n" <> Text.replicate 10 "None\n")
  ]

bytesRefusalPrograms :: [(String, Text)]
bytesRefusalPrograms =
  [ ("a byte slice past the end counts bytes", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let raw = \"abc\".toBytes()"
      , "  print(show(raw[1..5]))", "  return 0", "}" ])
  , ("a byte range value ending before it starts", program
      [ "fn main() -> Int {", "  print(\"start\")", "  let raw = \"abc\".toBytes()"
      , "  let r = 2..1", "  print(show(raw[r]))", "  return 0"
      , "}" ])
  ] <>
  [ ("byte operator " <> Text.unpack operation <> " reports at the operation", program
      [ "fn bytes() -> Bytes { print(\"operand\")\n bytesOf([1u8]) }"
      , "fn main() -> Int {", "  let result = " <> expression
      , "  print(show(result))", "  return 0", "}" ])
  | (operation, expression) <- [("negate", "-bytes()"), ("complement", "~bytes()"), ("add", "bytes() + bytes()"), ("order", "bytes() < bytes()")] ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)
