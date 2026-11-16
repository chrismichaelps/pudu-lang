{-| @Test.Backend.ForeignPrograms — foreign calls through typed native call
    sites against the interpreter's bridge: libc values and handles,
    with loader, crossing and ownership refusals. -}
module Pudu.Backend.ForeignPrograms (callbackCaller, optionalHandleLibrary, optionalHandlePrograms, foreignCallbackPrograms, foreignSuccessPrograms, foreignRefusalPrograms, foreignModulePrograms) where

import Data.Text (Text)
import qualified Data.Text as Text

foreignSuccessPrograms :: [(String, Text)]
foreignSuccessPrograms =
  [ ("the C library answers integers, floats and predicates through c", program
      [ "foreign \"c\" version \"1\" {"
      , "  fn absolute symbol \"abs\" (value: Int32) -> Int32"
      , "  fn labs(value: Int64) -> Int64"
      , "  fn pow(base: Float64, exponent: Float64) -> Float64"
      , "  fn sqrt(value: Float64) -> Float64"
      , "  fn isalpha(code: Int32) -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe {"
      , "    print(display(absolute(-42i32)) + \" \" + display(labs(-9000000000i64)) + \" \" + display(pow(2.0, 0.5)) + \" \" + display(sqrt(2.0)))"
      , "    print(display(isalpha(65i32) != 0i32) + \" \" + display(isalpha(49i32)) + \" \" + display(absolute(absolute(-7i32))))"
      , "  }"
      , "  0"
      , "}" ])
  , ("text and lent bytes cross to the C library and text comes back", program
      [ "foreign \"c\" {"
      , "  fn strlen(text: Str) -> Int64"
      , "  fn strchr(text: Str, code: Int32) -> Str"
      , "  fn strnlen(data: Bytes, most: Int64) -> Int64"
      , "  fn memcmp(left: Bytes, right: Bytes, length: Int64) -> Int32"
      , "  fn strerror(code: Int32) -> Str"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe {"
      , "    print(display(strlen(\"héllo\")) + \" \" + display(strlen(\"\")) + \" \" + strchr(\"pudu-lang\", 45i32) + \" \" + display(strerror(2i32).length() > 0))"
      , "    let data = bytesOf([104u8, 105u8, 0u8, 9u8])"
      , "    print(display(strnlen(data, 4i64)) + \" \" + display(strnlen(bytesOf([]), 0i64)) + \" \" + display(memcmp(data, data, 4i64)) + \" \" + display(memcmp(bytesOf([1u8]), bytesOf([2u8]), 1i64) < 0i32))"
      , "  }"
      , "  0"
      , "}" ])
  , ("records come back by value from the C library", program
      [ "type Division = { quot: Int32, rem: Int32 }"
      , "type LongDivision = { quot: Int64, rem: Int64 }"
      , "foreign \"c\" {"
      , "  fn div(numerator: Int32, denominator: Int32) -> Division"
      , "  fn ldiv(numerator: Int64, denominator: Int64) -> LongDivision"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe {"
      , "    let parts = div(17i32, 5i32)"
      , "    print(show(parts) + \" \" + show(div(-17i32, 5i32)) + \" \" + display(parts.quot * 5i32 + parts.rem))"
      , "    print(show(ldiv(9000000000i64, 7i64)))"
      , "  }"
      , "  0"
      , "}" ])
  , ("an owned C stream is usable and its release returns a status", handleProgram streamBindings
      [ "let stream = tmpfile()"
      , "print(display(fputc(65i32, stream)))"
      , "print(display(fclose(stream)))" ])
  , ("a borrowed handle can be passed back to libc", handleProgram messageBindings
      [ "let message = errorMessage(2i32)"
      , "print(display(messageLength(message) > 0u64))" ])
  , ("a scalar slot returns the value written by libc", handleProgram
      [ "fn frexp(value: Float64, out exponent: Int32) -> Float64" ]
      [ "let (fraction, exponent) = frexp(12.0)"
      , "print(show(fraction) + \" \" + show(exponent))" ])
  , ("a floating-point slot uses its declared C width", handleProgram
      [ "fn splitDouble symbol \"modf\" (value: Float64, out integral: Float64) -> Float64" ]
      [ "let (fraction, whole) = splitDouble(12.75)"
      , "print(show(fraction) + \" \" + show(whole))" ])
  , ("foreign slot values write back through an ordinary mutable loan", program
      [ "type State = { mut exponent: Int32 }"
      , "foreign \"c\" { fn frexp(value: Float64, out exponent: Int32) -> Float64 }"
      , "fn measure(value: Float64, target: &mut Int32) -> Float64 {"
      , "  let (fraction, exponent) = unsafe(foreign) { frexp(value) }"
      , "  *target = exponent"
      , "  fraction"
      , "}"
      , "fn main() -> Int {"
      , "  var state = State{exponent: 0i32}"
      , "  let fraction = measure(12.0, &mut state.exponent)"
      , "  print(show(fraction) + \" \" + show(state.exponent))"
      , "  0"
      , "}" ])
  ]

foreignRefusalPrograms :: [(String, Text)]
foreignRefusalPrograms =
  [ ("text holding a nought stops before the call", program
      [ "foreign \"c\" {"
      , "  fn strlen(text: Str) -> Int64"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(display(strlen(\"a\\u{0}b\"))) }"
      , "  0"
      , "}" ])
  , ("a text result the library does not give stops after the call", program
      [ "foreign \"c\" {"
      , "  fn getenv(name: Str) -> Str"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(getenv(\"PUDU_NATIVE_SURELY_UNSET_VARIABLE\")) }"
      , "  0"
      , "}" ])
  , ("a library that does not open stops at the call with every name tried", program
      [ "foreign \"puduabsentlibrary\" version \"3\" {"
      , "  fn nothing(value: Int32) -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(display(nothing(1i32))) }"
      , "  0"
      , "}" ])
  , ("a symbol the library does not export stops at the call", program
      [ "foreign \"c\" {"
      , "  fn absent symbol \"pudu_no_such_symbol_here\" (value: Int32) -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  print(\"before\")"
      , "  unsafe { print(display(absent(1i32))) }"
      , "  0"
      , "}" ])
  , ("a null owned result is refused after the call", handleProgram
      [ "type Stream"
      , "fn fopen(path: Str, mode: Str) -> owned Stream by fclose"
      , "fn fclose(stream: Stream) -> Int32" ]
      [ "print(\"before\")"
      , "fopen(\"\", \"r\")" ])
  , ("an alias cannot use a released stream", handleProgram streamBindings
      [ "let stream = tmpfile()"
      , "let alias = stream"
      , "fclose(stream)"
      , "fputc(65i32, alias)" ])
  , ("an owned stream cannot be released twice", handleProgram streamBindings
      [ "let stream = tmpfile()"
      , "fclose(stream)"
      , "fclose(stream)" ])
  , ("a borrowed message cannot enter its declared release", handleProgram
      (messageBindings <> ["fn ownedMessage symbol \"strerror\" (code: Int32) -> owned Message by messageLength"])
      [ "let message = errorMessage(2i32)"
      , "messageLength(message)" ])
  , ("a missing destructor is refused before a producer can return null", handleProgram
      [ "type Stream"
      , "fn fopen(path: Str, mode: Str) -> owned Stream by missingRelease"
      , "fn missingRelease symbol \"pudu_no_such_stream_release\" (stream: Stream) -> Int32" ]
      [ "print(\"before\")"
      , "fopen(\"\", \"r\")" ])
  , ("borrowed and owned declarations of the same C symbol keep distinct wrappers", handleProgram
      (messageBindings <>
        [ "fn ownedMessage symbol \"strerror\" (code: Int32) -> owned Message by missingRelease"
        , "fn missingRelease symbol \"pudu_no_such_message_release\" (message: Message) -> Int32" ])
      [ "print(display(messageLength(errorMessage(2i32)) > 0u64))"
      , "ownedMessage(2i32)" ])
  ]

streamBindings :: [Text]
streamBindings =
  [ "type Stream"
  , "fn tmpfile() -> owned Stream by fclose"
  , "fn fputc(value: Int32, stream: Stream) -> Int32"
  , "fn fclose(stream: Stream) -> Int32" ]

messageBindings :: [Text]
messageBindings =
  [ "type Message"
  , "fn errorMessage symbol \"strerror\" (code: Int32) -> borrowed Message"
  , "fn messageLength symbol \"strlen\" (message: Message) -> UInt64" ]

{-| Foreign functions another module exports, called through its name and
    an alias: the qualified call reaches the same native call site. -}
foreignModulePrograms :: [(String, [(FilePath, Text)], Text, Text)]
foreignModulePrograms =
  [ ( "foreign functions called through a module qualifier and an alias"
    , [ ("Clib.pudu", Text.unlines
          [ "module Clib", ""
          , "export foreign \"c\" {"
          , "  fn labs(value: Int64) -> Int64"
          , "  fn strlen(text: Str) -> Int64"
          , "  fn strdup(text: Str) -> owned Text by free"
          , "  fn strlen_of symbol \"strlen\" (text: Text) -> Int64"
          , "  fn free(text: Text) -> ()"
          , "  type Text"
          , "}" ]) ]
    , program
        [ "import Clib", "import Clib as C", ""
        , "fn main() -> Int {"
        , "  unsafe(foreign) {"
        , "    print(display(Clib.labs(-9000000000i64)) + \" \" + display(C.strlen(\"pudu\")))"
        , "    let held = C.strdup(\"native\")"
        , "    print(display(Clib.strlen_of(held)))"
        , "    Clib.free(held)"
        , "  }"
        , "  0", "}" ]
    , "9000000000 4\n6\n" ) ]

handleProgram :: [Text] -> [Text] -> Text
handleProgram bindings body = program $
  ["foreign \"c\" {"] <> map ("  " <>) bindings
    <> ["}", "fn main() -> Int {", "  unsafe(foreign) {"]
    <> map ("    " <>) body <> ["  }", "  0", "}"]

program :: [Text] -> Text
program body = Text.unlines (["module Main", ""] <> body)

{-| A library function that calls back: it hands each index below `count`
    to `visit`, with the context it was given, and sums the answers. The test
    executable defines it for the interpreter; a native build carries it. -}
callbackCaller :: Text
callbackCaller = Text.unlines
  [ "int64_t pudu_ffi_each(int64_t count, int64_t (*visit)(void *, int64_t), void *context);"
  , "int64_t pudu_ffi_each(int64_t count, int64_t (*visit)(void *, int64_t), void *context) {"
  , "  int64_t total = 0;"
  , "  for (int64_t index = 0; index < count; ++index) total += visit(context, index);"
  , "  return total;"
  , "}" ]

callbackBindings :: [Text]
callbackBindings =
  [ "foreign \"c\" {"
  , "  callback Visit(context, index: Int64) -> Int64 else 100i64"
  , "  fn each symbol \"pudu_ffi_each\" (count: Int64, visit: Visit, context visit) -> Int64"
  , "}" ]

foreignCallbackPrograms :: [(String, Text)]
foreignCallbackPrograms =
  [ ("a registered function is called back during the foreign call", program $ callbackBindings <>
      [ "fn squared(index: Int64) -> Int64 { index * index }"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let token = Visit(squared)"
      , "    print(display(each(4i64, token)))"
      , "    print(display(each(0i64, token)))"
      , "    print(show(token.unregister()))"
      , "  }"
      , "  0"
      , "}" ])
  , ("a closure registers with what it captured", program $ callbackBindings <>
      [ "fn main() -> Int {"
      , "  let base = 10i64"
      , "  unsafe(foreign) {"
      , "    let token = Visit(fn(index: Int64) -> Int64 { index + base })"
      , "    print(display(each(3i64, token)))"
      , "    let _gone = token.unregister()"
      , "  }"
      , "  0"
      , "}" ])
  , ("a retired registration answers its fallback", program $ callbackBindings <>
      [ "fn doubled(index: Int64) -> Int64 { index * 2i64 }"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let token = Visit(doubled)"
      , "    let _gone = token.unregister()"
      , "    print(display(each(3i64, token)))"
      , "  }"
      , "  0"
      , "}" ])
  , ("a callback's failure fails the foreign call at the callback", program $ callbackBindings <>
      [ "fn broken(index: Int64) -> Int64 { 10i64 / (index - 2i64) }"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let token = Visit(broken)"
      , "    print(display(each(4i64, token)))"
      , "  }"
      , "  0"
      , "}" ])
  ]

{-| A library whose functions take a handle that may be absent: it reads a
    box's value, or answers the fallback when it is handed none. The test
    executable defines it for the interpreter; a native build carries it. -}
optionalHandleLibrary :: Text
optionalHandleLibrary = Text.unlines
  [ "typedef struct { int32_t value; } pudu_ffi_optional_box;"
  , "void *pudu_ffi_optional_new(int32_t value);"
  , "void pudu_ffi_optional_delete(void *box);"
  , "int32_t pudu_ffi_optional_read(void *box, int32_t fallback);"
  , "void *pudu_ffi_optional_new(int32_t value) {"
  , "  pudu_ffi_optional_box *box = malloc(sizeof *box);"
  , "  if (box != NULL) box->value = value;"
  , "  return box;"
  , "}"
  , "void pudu_ffi_optional_delete(void *box) { free(box); }"
  , "int32_t pudu_ffi_optional_read(void *box, int32_t fallback) {"
  , "  return box == NULL ? fallback : ((pudu_ffi_optional_box *)box)->value;"
  , "}" ]

optionalHandleBindings :: [Text]
optionalHandleBindings =
  [ "foreign \"c\" {"
  , "  type Box"
  , "  fn boxNew symbol \"pudu_ffi_optional_new\" (value: Int32) -> owned Box by boxDelete"
  , "  fn boxDelete symbol \"pudu_ffi_optional_delete\" (box: Box) -> ()"
  , "  fn boxRead symbol \"pudu_ffi_optional_read\" (box: Option[Box], fallback: Int32) -> Int32"
  , "}" ]

optionalHandlePrograms :: [(String, Text)]
optionalHandlePrograms =
  [ ("an optional handle crosses as the handle it holds, or as null", program $ optionalHandleBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let box = boxNew(7i32)"
      , "    let held: Option[Box] = Some(box)"
      , "    print(display(boxRead(held, -1i32)) + \" \" + display(boxRead(None, -1i32)))"
      , "    boxDelete(box)"
      , "  }"
      , "  0"
      , "}" ])
  , ("an optional handle that was released is refused before the call", program $ optionalHandleBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let box = boxNew(3i32)"
      , "    boxDelete(box)"
      , "    print(display(boxRead(Some(box), -1i32)))"
      , "  }"
      , "  0"
      , "}" ])
  ]
