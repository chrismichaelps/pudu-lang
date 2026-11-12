{-| @Test.Backend.HostServicePrograms — the host families a program reaches
    through a token or a library of the machine: stream endpoints, secured
    connections, compression, child programs, time rendering and reading, and
    stop requests. Every expectation is what the interpreter prints for the
    same program, and no expectation holds a descriptor number, a port, or
    the system's own reason. -}
module Pudu.Backend.HostServicePrograms (hostServicePrograms, standardInputPrograms) where

import qualified Data.ByteString as ByteString

import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding

hostServicePrograms :: [(String, Text, Text)]
hostServicePrograms =
  [ ( "stream endpoints: listening, connecting, echoing, budgets and closed tokens", program
      [ "fn echo(listener: Int) -> () {"
      , "  match tcpAccept(listener) { case Ok(peer) => {"
      , "      match socketReceive(peer, 64) { case Ok(Some(chunk)) => {"
      , "          let _ = socketSend(peer, chunk)"
      , "          let _ = socketSendWithin(peer, \"!\".toBytes(), 500)"
      , "        }"
      , "        case _ => {} }"
      , "      let _ = socketFinish(peer)"
      , "      let _ = socketClose(peer)"
      , "    }"
      , "    case Err(_) => {} }"
      , "}"
      , ""
      , "fn portOf(listener: Int) -> Int {"
      , "  match socketPort(listener) { case Ok(found) => found"
      , "    case Err(_) => 0 }"
      , "}"
      , ""
      , "fn gather(token: Int, held: Str) -> Str {"
      , "  match socketReceiveWithin(token, 64, 2000) { case Ok(Some(chunk)) => match chunk.toText() { case Some(text) => gather(token, held + text)"
      , "      case None => held + \"?\" }"
      , "    case Ok(None) => held + \".\""
      , "    case Err(why) => held + why }"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  print(show(socketSend(9, \"a\".toBytes())) + show(socketReceive(9, 4)) + show(socketReceive(9, 0)) + show(socketClose(9)) + show(socketFinish(9)) + show(socketPeer(9)) + show(socketPort(9)) + show(tcpAccept(9)))"
      , "  print(show(tcpConnectWithin(\"127.0.0.1\", 1, 0)) + show(socketSendWithin(9, \"a\".toBytes(), 0)) + show(socketReceiveWithin(9, 4, 0)))"
      , "  match tcpListen(\"127.0.0.1\", 0, 4) { case Ok(listener) => {"
      , "      let port = portOf(listener)"
      , "      print(display(port > 0) + display(listener))"
      , "      let server = spawnThread(fn() -> () { echo(listener) })"
      , "      match tcpConnect(\"127.0.0.1\", port) { case Ok(open) => {"
      , "          let peer = match socketPeer(open) { case Ok(named) => named.startsWith(\"127.0.0.1:\")"
      , "            case Err(_) => false }"
      , "          print(display(open > listener) + display(peer) + show(socketSend(open, \"hello\".toBytes())))"
      , "          print(gather(open, \"\") + show(socketReceiveWithin(open, 4, 0)) + show(socketSend(open, \"x\".toBytes())) + show(socketClose(open)) + show(socketClose(open)))"
      , "        }"
      , "        case Err(why) => print(why) }"
      , "      match server { case Ok(token) => print(show(joinThread(token)))"
      , "        case Err(why) => print(why) }"
      , "      match tcpConnectWithin(\"127.0.0.1\", port, 2000) { case Ok(idle) => print(show(socketReceiveWithin(idle, 4, 30)) + show(socketReceive(idle, 4)) + show(socketClose(idle)))"
      , "        case Err(why) => print(why) }"
      , "      print(show(socketClose(listener)) + show(tcpAccept(listener)))"
      , "    }"
      , "    case Err(why) => print(why) }"
      , "  0"
      , "}"
      ]
    , "Err(\"the endpoint is closed\")Err(\"the endpoint is closed\")Ok(Some(0x))Ok(())Err(\"the endpoint is closed\")Err(\"the endpoint is closed\")Err(\"the endpoint is closed\")Err(\"the endpoint is closed\")\nErr(\"operation timed out\")Err(\"the endpoint is closed\")Err(\"the endpoint is closed\")\ntrue1\ntruetrueOk(())\nhello!.Err(\"operation timed out\")Err(\"the endpoint is closed\")Ok(())Ok(())\nOk(())\nErr(\"operation timed out\")Err(\"the endpoint is closed\")Ok(())\nOk(())Err(\"the endpoint is closed\")\n" )
  , ( "gzip and bare streams: round trips, levels, limits and refusals", program
      [ "fn back(packed: Result[Bytes, Str], bare: Bool) -> Str {"
      , "  match packed { case Ok(found) => match (if bare { inflateRaw(found, 1000000) } else { gzipDecompress(found, 1000000) }) { case Ok(plain) => match plain.toText() { case Some(text) => display(text.length()) + \":\" + text.take(12)"
      , "        case None => \"?\" }"
      , "      case Err(why) => why }"
      , "    case Err(why) => why }"
      , "}"
      , ""
      , "fn kind(found: Result[Bytes, Str]) -> Str {"
      , "  match found { case Ok(_) => \"opened\""
      , "    case Err(why) => if why.startsWith(\"Codec.Compression.Zlib: compressed data stream format error\") { \"format\" } else if why.startsWith(\"Codec.Compression.Zlib: premature end of compressed data stream\") { \"premature\" } else { why } }"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  let words = \"the quick brown fox jumps over the lazy dog. \".repeat(200)"
      , "  let plain = words.toBytes()"
      , "  print(back(gzipCompress(plain, 6, 4096), false) + \" \" + back(deflateRaw(plain, 9, 64), true) + \" \" + back(gzipCompress(\"\".toBytes(), 0, 16), false) + \" \" + back(deflateRaw(plain, 1, 1), true))"
      , "  match gzipCompress(plain, 6, 4096) { case Ok(packed) => print(display(packed.length() < plain.length()) + show(packed.slice(0, 3)) + show(gzipDecompress(packed, 100)) + kind(inflateRaw(packed, 1000000)) + kind(gzipDecompress(packed.slice(0, 40), 1000000)))"
      , "    case Err(why) => print(why) }"
      , "  print(show(gzipCompress(plain, 10, 4096)) + show(gzipCompress(plain, -1, 4096)) + back(deflateRaw(plain, 6, 0), true) + kind(gzipDecompress(\"nonsense\".toBytes(), 100)) + kind(inflateRaw(\"\".toBytes(), 100)) + show(gzipDecompress(plain, -1)))"
      , "  let packer = gzipCompress"
      , "  let opener = gzipDecompress"
      , "  print(show(packer) + show(opener) + back(packer(\"abc\".toBytes(), 6, 16), false))"
      , "  0"
      , "}"
      ]
    , "9000:the quick br 9000:the quick br 0: 9000:the quick br\ntrue0x1f8b08Err(\"decompressed output limit exceeded\")formatpremature\nErr(\"invalid compression level\")Err(\"invalid compression level\")9000:the quick brformatprematureErr(\"negative decompression limit\")\n<builtin gzipCompress><builtin gzipDecompress>3:abc\n" )
  , ( "child programs: pipes, an environment and a directory, waiting and stopping", program
      [ "fn text(found: Result[Option[Bytes], Str]) -> Str {"
      , "  match found { case Ok(Some(chunk)) => match chunk.toText() { case Some(words) => words"
      , "      case None => \"?\" }"
      , "    case Ok(None) => \"<end>\""
      , "    case Err(why) => why }"
      , "}"
      , ""
      , "fn whole(child: Int, held: Str) -> Str {"
      , "  match childReadChunk(child, 64) { case Ok(Some(chunk)) => match chunk.toText() { case Some(words) => whole(child, held + words)"
      , "      case None => held + \"?\" }"
      , "    case Ok(None) => held"
      , "    case Err(why) => held + why }"
      , "}"
      , ""
      , "fn refused(found: Result[(), Str]) -> Str {"
      , "  match found { case Ok(_) => \"written\""
      , "    case Err(why) => display(why.endsWith(\"hPutBuf: illegal operation (handle is closed)\")) }"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  print(show(runProgram(\"/bin/sh\", [\"-c\", \"echo out; echo err >&2; exit 3\"], \"\")))"
      , "  print(show(runProgram(\"/bin/cat\", [], \"fed\\nlines\\n\")))"
      , "  match runProgram(\"/nowhere/at/all\", [], \"\") { case Ok(found) => print(show(found))"
      , "    case Err(why) => print(display(why.contains(\"/nowhere/at/all\"))) }"
      , "  match spawnProgram(\"/bin/cat\", []) { case Ok(child) => {"
      , "      print(display(child) + show(childWriteChunk(child, \"one\\n\".toBytes())) + show(childCloseInput(child)) + show(childCloseInput(child)))"
      , "      print(text(childReadChunk(child, 64)).replace(\"\\n\", \"|\") + text(childReadChunk(child, 64)) + text(childReadErrorChunk(child, 64)) + show(childWait(child)) + show(childWait(child)) + refused(childWriteChunk(child, \"x\".toBytes())))"
      , "    }"
      , "    case Err(why) => print(why) }"
      , "  match spawnProgramWith(\"/bin/sh\", [\"-c\", \"echo $SHOWN; pwd\"], [(\"SHOWN\", \"given\")], false, \"/\") { case Ok(child) => print(whole(child, \"\").replace(\"\\n\", \"|\") + show(childWait(child)))"
      , "    case Err(why) => print(why) }"
      , "  match spawnProgram(\"/bin/sleep\", [\"30\"]) { case Ok(child) => print(show(childWaitWithin(child, 10)) + display(match childStop(child) { case Ok(code) => code != 0"
      , "        case Err(_) => false }))"
      , "    case Err(why) => print(why) }"
      , "  print(show(childWait(99)) + show(childStop(99)) + show(childCloseInput(99)) + text(childReadChunk(99, 4)) + show(childWaitWithin(99, 1)))"
      , "  0"
      , "}"
      ]
    , "Ok((3, \"out\\n\", \"err\\n\"))\nOk((0, \"fed\\nlines\\n\", \"\"))\ntrue\n1Ok(())Ok(())Ok(())\none|<end><end>Ok(0)Ok(0)true\ngiven|/|Ok(0)\nOk(None)true\nErr(\"this token names no started program\")Err(\"this token names no started program\")Err(\"this token names no started program\")this token names no started programErr(\"this token names no started program\")\n" )
  , ( "time rendering and reading, and watching for a stop request", program
      [ "fn main() -> Int {"
      , "  let moment = 1700000000123"
      , "  print(show(formatTime(\"%Y-%m-%dT%H:%M:%SZ\", moment, \"utc\")) + show(formatTime(\"%a %A %b %B %d %e %j %y %C %G %V %u %w\", moment, \"utc\")))"
      , "  print(show(formatTime(\"%I %l %p %P %M %S %q %s %Z %z %% %n%t|%D|%F|%T|%R|%c\", moment, \"utc\")) + show(formatTime(\"%Y\", -62135596800000, \"utc\")) + show(formatTime(\"%Q\", moment, \"utc\")))"
      , "  print(show(formatTime(\"%Y\", moment, \"mars\")) + show(formatTime(\"plain\", 0, \"utc\")) + show(formatTime(\"%\", 0, \"utc\")) + show(formatTime(\"%Y-%m-%d\", 253402300800000, \"utc\")))"
      , "  print(show(parseTime(\"%Y-%m-%dT%H:%M:%SZ\", \"2023-11-14T22:13:20Z\")) + show(parseTime(\"%Y-%m-%d\", \"1969-12-31\")) + show(parseTime(\"%d %b %Y %H:%M\", \"05 Mar 2001 07:08\")) + show(parseTime(\"%s\", \"86400\")))"
      , "  print(show(parseTime(\"%Y-%m-%d\", \"2023-02-30\")) + show(parseTime(\"%Y\", \"year\")) + show(parseTime(\"%Y-%m-%d\", \"2023-11-14 trailing\")) + show(parseTime(\"%H:%M %p\", \"11:30 PM\")) + show(parseTime(\"%Y %j\", \"2024 366\")))"
      , "  let shown = formatTime"
      , "  let read = parseTime"
      , "  print(show(shown) + show(read) + show(shown(\"%H\", 3600000, \"utc\")) + show(read(\"%Y\", \"1970\")))"
      , "  print(show(signalStopRequested()) + show(signalWatchStop()) + show(signalWatchStop()) + show(signalStopRequested()))"
      , "  0"
      , "}"
      ]
    , "Ok(\"2023-11-14T22:13:20Z\")Ok(\"Tue Tuesday Nov November 14 14 318 23 20 2023 46 2 2\")\nOk(\"10 10 PM pm 13 20 123000000000 1700000000 UTC +0000 % \\n\\t|11/14/23|2023-11-14|22:13:20|22:13|Tue Nov 14 22:13:20 UTC 2023\")Ok(\"1\")Ok(\".123\")\nOk(\"2023\")Ok(\"plain\")Ok(\"%\")Ok(\"10000-01-01\")\nOk(1700000000000)Ok(-86400000)Ok(983776080000)Ok(86400000)\nErr(\"the text does not fit the pattern %Y-%m-%d\")Err(\"the text does not fit the pattern %Y\")Err(\"the text does not fit the pattern %Y-%m-%d\")Ok(84600000)Ok(1735603200000)\n<builtin formatTime><builtin parseTime>Ok(\"01\")Ok(0)\nfalsetruetruefalse\n" )
  , ( "time reading retains signed magnitudes and rounds after applying the offset", program
      [ "fn main() -> Int {"
      , "  print(show(parseTime(\"%-Y\", \"300000000\")))"
      , "  print(show(parseTime(\"%-Y\", \"-300000000\")))"
      , "  print(show(parseTime(\"%-Y-%m-%d %H:%M:%S%Q\", \"584556019-04-03 14:25:51.615\")))"
      , "  print(show(parseTime(\"%-Y-%m-%d %s%Q\", \"900000000000000-02-29 -1.9995\")))"
      , "  print(show(parseTime(\"%-Y-%m-%d\", \"300000000-02-30\")))"
      , "  print(show(parseTime(\"%-Y-%m-%d %H:%M:%S%Q %z\", \"300000000-01-01 00:00:00.0015 +0001\")))"
      , "  print(show(parseTime(\"%-Y-%m-%d %H:%M:%S%Q\", \"584556019-04-03 14:25:51.6155\")))"
      , "  0"
      , "}"
      ]
    , "Ok(9467023432780800000)\nOk(-9467147767219200000)\nOk(18446744073709551615)\nOk(0)\nErr(\"the text does not fit the pattern %-Y-%m-%d\")\nOk(9467023432780740002)\nErr(\"the text does not fit the pattern %-Y-%m-%d %H:%M:%S%Q\")\n" )
  , ( "long time fields keep a padded value and a fraction's leading digits", program
      [ "fn main() -> Int {"
      , "  print(show(parseTime(\"%Y\", \"0000000000000000000000000000000000000002023\")))"
      , "  print(show(parseTime(\"%-Y\", \"-0000000000000000000000000000000000000000001\")))"
      , "  print(show(parseTime(\"%s%Q\", \"1.000000000000000000000000000000000000000000001\")))"
      , "  print(show(parseTime(\"%s\", \"00000000000000000000000000000000000000000000086400\")))"
      , "  print(show(parseTime(\"%Y-%m-%d\", \"2023-000000000000000000000000000000000000000011-14\")))"
      , "  print(show(parseTime(\"%-Y\", \"1000000000000000000000000000000000000000000000000\")))"
      , "  0"
      , "}"
      ]
    , "Ok(1672531200000)\nOk(-62198755200000)\nOk(1000)\nOk(86400000)\nErr(\"the text does not fit the pattern %Y-%m-%d\")\nErr(\"the text does not fit the pattern %-Y\")\n" )
  , ( "wide instants round-trip through time rendering", program
      [ "fn roundTrip(pattern: Str, text: Str) -> () {"
      , "  match parseTime(pattern, text) {"
      , "    case Ok(value) => {"
      , "      let _ = print(show(formatTime(\"%Y-%m-%d %H:%M:%S%Q | %s\", value, \"utc\")))"
      , "    }"
      , "    case Err(message) => { let _ = print(message) }"
      , "  }"
      , "}"
      , "fn main() -> Int {"
      , "  roundTrip(\"%-Y-%m-%d %H:%M:%S%Q\", \"584556019-04-03 14:25:51.615\")"
      , "  roundTrip(\"%-Y-%m-%d %H:%M:%S%Q\", \"-300000000-01-01 00:00:00.001\")"
      , "  roundTrip(\"%-Y-%m-%d %H:%M:%S%Q\", \"-292275055-05-16 16:47:04.192\")"
      , "  roundTrip(\"%s%Q\", \"-1.999\")"
      , "  0"
      , "}"
      ]
    , "Ok(\"584556019-04-03 14:25:51.615 | 18446744073709551\")\nOk(\"-300000000-01-01 00:00:00.001 | -9467147767219200\")\nOk(\"-292275055-05-16 16:47:04.192 | -9223372036854776\")\nOk(\"1969-12-31 23:59:59.999 | -1\")\n" )
  , ( "epoch seconds reach both limits of the native millisecond carrier", program
      [ "fn main() -> Int {"
      , "  print(show(parseTime(\"%s%Q\", \"18446744073709551.615\")))"
      , "  print(show(parseTime(\"%s%Q\", \"-18446744073709552.385\")))"
      , "  print(show(parseTime(\"%s%Q\", \"18446744073709551.6155\")))"
      , "  print(show(parseTime(\"%s%Q\", \"-18446744073709552.3845\")))"
      , "  print(show(parseTime(\"%-Y\", \"9000000000000000\")))"
      , "  0"
      , "}"
      ]
    , "Ok(18446744073709551615)\nOk(-18446744073709551615)\nErr(\"the text does not fit the pattern %s%Q\")\nErr(\"the text does not fit the pattern %s%Q\")\nErr(\"the text does not fit the pattern %-Y\")\n" )
  , ( "secured connections: closed tokens, budgets and far ends that never prove themselves", program
      [ "fn hangUp(listener: Int) -> () {"
      , "  match tcpAccept(listener) { case Ok(peer) => {"
      , "      let _ = socketReceive(peer, 4096)"
      , "      let _ = socketClose(peer)"
      , "    }"
      , "    case Err(_) => {} }"
      , "}"
      , ""
      , "fn portOf(listener: Int) -> Int {"
      , "  match socketPort(listener) { case Ok(found) => found"
      , "    case Err(_) => 0 }"
      , "}"
      , ""
      , "fn main() -> Int {"
      , "  print(show(tlsSend(7, \"ab\".toBytes())) + show(tlsSendWithin(7, \"a\".toBytes(), 0)) + show(tlsReceive(7, 4)) + show(tlsReceive(7, 0)) + show(tlsReceiveWithin(7, -1, 5)) + show(tlsReceiveWithin(7, 4, 0)))"
      , "  print(show(tlsPeer(7)) + show(tlsClose(7)) + show(tlsCloseWithin(7, 0)) + show(tlsUpgradeWithin(7, \"localhost\", 50)) + show(tlsConnectWithin(\"127.0.0.1\", 1, 0)))"
      , "  match tcpListen(\"127.0.0.1\", 0, 4) { case Ok(silent) => {"
      , "      print(show(tlsConnectWithin(\"127.0.0.1\", portOf(silent), 60)))"
      , "      match tcpConnect(\"127.0.0.1\", portOf(silent)) { case Ok(plain) => {"
      , "          print(show(tlsUpgradeWithin(plain, \"localhost\", 60)) + show(socketSend(plain, \"x\".toBytes())) + show(tlsUpgradeWithin(plain, \"localhost\", 60)))"
      , "        }"
      , "        case Err(why) => print(why) }"
      , "      print(show(socketClose(silent)))"
      , "    }"
      , "    case Err(why) => print(why) }"
      , "  match tcpListen(\"127.0.0.1\", 0, 4) { case Ok(plain) => {"
      , "      let server = spawnThread(fn() -> () { hangUp(plain) })"
      , "      print(show(tlsConnectWithin(\"127.0.0.1\", portOf(plain), 5000)))"
      , "      match server { case Ok(token) => print(show(joinThread(token)))"
      , "        case Err(why) => print(why) }"
      , "      let again = spawnThread(fn() -> () { hangUp(plain) })"
      , "      match tcpConnect(\"127.0.0.1\", portOf(plain)) { case Ok(open) => print(show(tlsUpgradeWithin(open, \"localhost\", -1)) + show(socketClose(open)))"
      , "        case Err(why) => print(why) }"
      , "      match again { case Ok(token) => print(show(joinThread(token)))"
      , "        case Err(why) => print(why) }"
      , "      print(show(socketClose(plain)))"
      , "    }"
      , "    case Err(why) => print(why) }"
      , "  0"
      , "}"
      ]
    , "Err(\"the secured connection is closed\")Err(\"the secured connection is closed\")Err(\"the secured connection is closed\")Ok(Some(0x))Ok(Some(0x))Err(\"the secured connection is closed\")\nErr(\"the secured connection is closed\")Ok(())Ok(())Err(\"the plain connection is closed\")Err(\"operation timed out\")\nErr(\"operation timed out\")\nErr(\"operation timed out\")Err(\"the endpoint is closed\")Err(\"the plain connection is closed\")\nOk(())\nErr(\"HandshakeFailed Error_EOF\")\nOk(())\nErr(\"HandshakeFailed Error_EOF\")Ok(())\nOk(())\nOk(())\n" )
  ]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

standardInputPrograms :: [(String, ByteString.ByteString, Text, Text)]
standardInputPrograms =
  [ ( "lines and repeated EOF"
    , TextEncoding.encodeUtf8 ("first\r\n\n" <> finalLine)
    , source
    , "Ok(Some(\"first\r\"))\nOk(Some(\"\"))\nOk(Some(\"" <> finalLine <> "\"))\nOk(None)\nOk(None)\n"
    )
  , ( "persistent malformed input"
    , ByteString.pack [111, 107, 10, 255, 10]
    , source
    , "Ok(Some(\"ok\"))\n" <> Text.replicate 4 (invalidByte "255")
    )
  , ( "truncated input at EOF"
    , ByteString.pack [226, 130]
    , source
    , Text.replicate 5 (invalidByte "226")
    )
  ]
 where
  finalLine = "café\0" <> Text.replicate 512 "x"
  invalidByte byte =
    "Err(\"<stdin>: hGetLine: invalid argument (cannot decode byte sequence starting from " <> byte <> ")\")\n"
  source = Text.unlines
    [ "module Main"
    , "fn main() -> Int {"
    , "  print(show(readLine()))"
    , "  let next = readLine"
    , "  print(show(next()))"
    , "  print(show(next()))"
    , "  print(show(readLine()))"
    , "  print(show(readLine()))"
    , "  0"
    , "}"
    ]
