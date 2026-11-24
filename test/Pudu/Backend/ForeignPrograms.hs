{-| @Test.Backend.ForeignPrograms — foreign calls through typed native call
    sites against the interpreter's bridge: libc values and handles,
    with loader, crossing and ownership refusals. -}
module Pudu.Backend.ForeignPrograms (callbackCaller, optionalHandleLibrary, optionalHandlePrograms, foreignCallbackPrograms, foreignCrossingLibrary, foreignCrossingPrograms, objectiveCPrograms, objectiveCRefusalPrograms, foreignSuccessPrograms, foreignRefusalPrograms, foreignModulePrograms) where

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
  , ("stored foreign functions retain their crossing identity and can be passed", program
      [ "foreign \"c\" { fn magnitude symbol \"abs\" (value: Int32) -> Int32 }"
      , "fn apply(callable: unsafe(foreign) fn(Int32) -> Int32, value: Int32) -> Int32 {"
      , "  unsafe(foreign) { callable(value) }"
      , "}"
      , "fn main() -> Int {"
      , "  let callable = magnitude"
      , "  print(show(callable))"
      , "  print(display(callable == magnitude))"
      , "  print(display(apply(callable, -3i32)))"
      , "  0", "}" ])
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
  [ ("a stored foreign function blames the indirect call site", program
      [ "foreign \"c\" { fn missing symbol \"pudu_nonexistent_value_symbol\" () -> Int32 }"
      , "fn main() -> Int {"
      , "  let callable = missing"
      , "  print(\"before\")"
      , "  unsafe(foreign) { print(display(callable())) }"
      , "  0", "}" ])
  , ("text holding a nought stops before the call", program
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
        , "    let length = C.strlen"
        , "    print(display(length(\"pudu\")))"
        , "    let held = C.strdup(\"native\")"
        , "    print(display(Clib.strlen_of(held)))"
        , "    Clib.free(held)"
        , "  }"
        , "  0", "}" ]
    , "9000000000 4\n4\n6\n" ) ]

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
  , ("callback tokens render directly and in aggregates and compare by registration", program $ callbackBindings <>
      [ "fn identity(index: Int64) -> Int64 { index }"
      , "fn main() -> Int {"
      , "  let first = Visit(identity)"
      , "  let second = Visit(identity)"
      , "  let same = first"
      , "  print(display(first))"
      , "  print(show((first,)))"
      , "  print(show((first == same, first != second)))"
      , "  print(show((second, 0) < (first, 1)))"
      , "  print(display(setOf([first, second]).size()))"
      , "  0"
      , "}" ])
  , ("a stored callback constructor renders and registers with its declared identity", program $ callbackBindings <>
      [ "fn identity(index: Int64) -> Int64 { index }"
      , "fn main() -> Int {"
      , "  let register = Visit"
      , "  print(show(register))"
      , "  print(display(register == Visit))"
      , "  let token = register(identity)"
      , "  print(show(token))"
      , "  0", "}" ])
  , ("a callback token can be returned from the entry", program $ callbackBindings <>
      [ "fn identity(index: Int64) -> Int64 { index }"
      , "fn main() -> Visit { Visit(identity) }" ])
  , ("a callback token names its declaration in a unary refusal", program $ callbackBindings <>
      [ "fn identity(index: Int64) -> Int64 { index }"
      , "fn main() -> Int {"
      , "  let token = Visit(identity)"
      , "  let invalid = ~{ print(\"registered\")\n token }"
      , "  print(show(invalid))"
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


foreignCrossingLibrary :: Text
foreignCrossingLibrary = Text.unlines
  [ "#include <stdbool.h>"
  , "typedef int64_t (*fixture_visit)(void *, int64_t);"
  , "typedef int64_t (*fixture_finish)(void *);"
  , "static fixture_visit retained_visit;"
  , "static void *retained_context;"
  , "static int32_t run_releases;"
  , "void pudu_ffi_save_visit(fixture_visit visit) { retained_visit = visit; }"
  , "void pudu_ffi_save_context(void *context) { retained_context = context; }"
  , "int64_t pudu_ffi_fire_visit(int64_t value) {"
  , "  return retained_visit == NULL ? -1 : retained_visit(retained_context, value);"
  , "}"
  , "int64_t pudu_ffi_visit_pair(fixture_visit tick, fixture_finish finish, void *context) {"
  , "  return tick(context, 4) + finish(context);"
  , "}"
  , "int64_t pudu_ffi_visit_bytes(int64_t (*visit)(const unsigned char *, uint64_t, void *), void *context) {"
  , "  const unsigned char bytes[] = {3, 0, 9};"
  , "  return visit(bytes, sizeof bytes, context) + visit(NULL, 0, context);"
  , "}"
  , "bool pudu_ffi_mutate_run(int32_t *data, int64_t count) {"
  , "  for (int64_t i = 0; i < count; ++i) data[i] += 10;"
  , "  return data != NULL;"
  , "}"
  , "int32_t *pudu_ffi_return_run(uint64_t *length) {"
  , "  int32_t *data = malloc(2 * sizeof(*data));"
  , "  *length = data == NULL ? 0 : 2;"
  , "  if (data != NULL) { data[0] = 7; data[1] = 11; }"
  , "  return data;"
  , "}"
  , "void pudu_ffi_release_run(void *data) { free(data); ++run_releases; }"
  , "int32_t pudu_ffi_run_releases(void) { return run_releases; }"
  ]

foreignCrossingPrograms :: [(String, Text, Text)]
foreignCrossingPrograms =
  [ ("nullable runs distinguish absent and empty and copy mutations back", program
      [ "foreign \"c\" {"
      , "  fn mutate symbol \"pudu_ffi_mutate_run\" (data: nullable &mut Array[Int32], count: Int64 elements of data) -> Bool"
      , "}"
      , "fn main() -> Int {"
      , "  var items = [1i32, 2i32]"
      , "  var empty: Array[Int32] = []"
      , "  unsafe(foreign) {"
      , "    print(display(mutate(None, 0i64)))"
      , "    print(display(mutate(&mut empty, 0i64)))"
      , "    print(display(mutate(&mut items, 1i64)))"
      , "  }"
      , "  print(show(items))"
      , "  0"
      , "}" ], "false\ntrue\ntrue\n[11, 2]\n")
  , ("a stored foreign function writes a mutable run back through its caller", program
      [ "foreign \"c\" {"
      , "  fn mutate symbol \"pudu_ffi_mutate_run\" (data: &mut Array[Int32], count: Int64 elements of data) -> Bool"
      , "}"
      , "fn main() -> Int {"
      , "  let change = mutate"
      , "  var items = [1i32, 2i32]"
      , "  unsafe(foreign) { print(display(change(&mut items, 1i64))) }"
      , "  print(show(items))"
      , "  0", "}" ], "true\n[11, 2]\n")
  , ("returned runs are copied and released before publication", program
      [ "foreign \"c\" {"
      , "  type Storage"
      , "  fn read symbol \"pudu_ffi_return_run\" (out length: UInt64) -> owned Array[Int32] elements of length by dispose"
      , "  fn dispose symbol \"pudu_ffi_release_run\" (data: Storage)"
      , "  fn releases symbol \"pudu_ffi_run_releases\" () -> Int32"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let before = releases()"
      , "    let (data, count) = read()"
      , "    print(show(data))"
      , "    print(display(count))"
      , "    print(display(releases() - before))"
      , "  }"
      , "  0"
      , "}" ], "[7, 11]\n2\n1\n")
  , ("split callback setup and shared context route through the original token", program
      [ "foreign \"c\" {"
      , "  callback Visit(context, value: Int64) -> Int64 else -1i64"
      , "  callback Finish(context) -> Int64 else -2i64"
      , "  callbacks Delegate {tick: Visit, finish: Finish}"
      , "  fn setVisit symbol \"pudu_ffi_save_visit\" (entry: trampoline Visit)"
      , "  fn setContext symbol \"pudu_ffi_save_context\" (data: context Visit)"
      , "  fn fire symbol \"pudu_ffi_fire_visit\" (value: Int64) -> Int64"
      , "  fn pair symbol \"pudu_ffi_visit_pair\" (tick: trampoline Delegate.tick, finish: trampoline Delegate.finish, data: context Delegate) -> Int64"
      , "}"
      , "type Handlers = { finish: fn() -> Int64, tick: fn(Int64) -> Int64 }"
      , "fn visit(value: Int64) -> Int64 { value + 5i64 }"
      , "fn finish() -> Int64 { 20i64 }"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let token = Visit(visit)"
      , "    setVisit()"
      , "    setContext(token)"
      , "    print(display(fire(3i64)))"
      , "    let delegate = Delegate(Handlers{finish: finish, tick: visit})"
      , "    print(display(pair(delegate)))"
      , "    let _gone = token.unregister()"
      , "    let _alsoGone = delegate.unregister()"
      , "  }"
      , "  0"
      , "}" ], "8\n29\n")
  , ("callback byte runs preserve embedded noughts and null-empty storage", program
      [ "foreign \"c\" {"
      , "  callback Read(data: Bytes, count: UInt64 bytes of data, context) -> Int64 else 100i64"
      , "  fn visit symbol \"pudu_ffi_visit_bytes\" (read: Read, context read) -> Int64"
      , "}"
      , "fn read(data: Bytes, count: UInt64) -> Int64 {"
      , "  if count == 0u64 { 5i64 } else { if data == bytesOf([3u8, 0u8, 9u8]) { 7i64 } else { 0i64 } }"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let token = Read(read)"
      , "    print(display(visit(token)))"
      , "    let _gone = token.unregister()"
      , "  }"
      , "  0"
      , "}" ], "12\n")
  ]

objectiveCBindings :: [Text]
objectiveCBindings =
  [ "foreign \"/System/Library/Frameworks/Foundation.framework/Foundation\" {"
  , "  class StringObject symbol \"NSString\""
  , "  fn allocate selector \"alloc\" on StringObject () -> owned StringObject by release"
  , "  fn initialize selector \"initWithUTF8String:\" (receiver: StringObject, text: Str) -> owned StringObject by release"
  , "  fn copy selector \"copy\" (receiver: StringObject) -> counted StringObject by release"
  , "  fn length selector \"length\" (receiver: StringObject) -> UInt64"
  , "  fn utf8 selector \"UTF8String\" (receiver: StringObject) -> Str"
  , "  fn release symbol \"objc_release\" (receiver: StringObject)"
  , "}" ]

objectiveCPrograms :: [(String, Text, Text)]
objectiveCPrograms =
  [ ("Foundation class lookup, initializer transfer and counted copy", program $ objectiveCBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let uninitialized = allocate()"
      , "    let value = initialize(uninitialized, \"hello\")"
      , "    let duplicate = copy(value)"
      , "    print(display(length(value)))"
      , "    print(utf8(duplicate))"
      , "    release(duplicate)"
      , "    release(value)"
      , "  }"
      , "  0"
      , "}" ], "5\nhello\n")
  , ("an explicit autorelease pool holds a borrowed result until it drains", program $ poolBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let pool = poolPush()"
      , "    let value = stringFrom(\"pooled\")"
      , "    print(utf8(value))"
      , "    poolPop(pool)"
      , "  }"
      , "  0"
      , "}" ], "pooled\n")
  , ("open nested autorelease pools drain innermost first at exit", program $ poolBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let _outer = poolPush()"
      , "    let _inner = poolPush()"
      , "    print(display(length(stringFrom(\"in\"))))"
      , "  }"
      , "  0"
      , "}" ], "2\n")
  , ("a block runs during the call and an escaping block runs from its copy", program $ blockBindings <>
      [ "fn sayNow() -> () {"
      , "  let _shown = print(\"now\")"
      , "  ()"
      , "}"
      , "fn sayLater() -> () {"
      , "  let _shown = print(\"later\")"
      , "  ()"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let queue = queueNew(\"pudu.blocks\", 0u64)"
      , "    let now = Work(sayNow)"
      , "    let later = Work(sayLater)"
      , "    runNow(queue, now)"
      , "    runLater(queue, later)"
      , "    runNow(queue, now)"
      , "    let _later = later.unregister()"
      , "    let _now = now.unregister()"
      , "    queueRelease(queue)"
      , "  }"
      , "  0"
      , "}" ], "now\nlater\nnow\n")
  , ("a framework calls a delegate method that enters its group handler", program
      [ "foreign \"/System/Library/Frameworks/Foundation.framework/Foundation\" {"
      , "  class StringObject symbol \"NSString\""
      , "  class Center symbol \"NSNotificationCenter\""
      , "  type Notice"
      , "  callback Posted(context, note: borrowed Notice) -> ()"
      , "  callbacks Events { posted: Posted }"
      , "  delegate Observer symbol \"PuduConformanceObserver\" for Events { posted \"noticePosted:\" }"
      , "  fn stringFrom selector \"stringWithUTF8String:\" on StringObject (text: Str) -> borrowed StringObject"
      , "  fn center selector \"defaultCenter\" on Center () -> borrowed Center"
      , "  fn observe selector \"addObserver:selector:name:object:\" (receiver: Center, observer: Observer, action: UInt64, name: StringObject, sender: UInt64) -> ()"
      , "  fn post selector \"postNotificationName:object:\" (receiver: Center, name: StringObject, sender: UInt64) -> ()"
      , "  fn selectorNamed symbol \"sel_registerName\" (name: Str) -> UInt64"
      , "}"
      , "type Handlers = { posted: fn(Notice) -> () }"
      , "fn heard(note: Notice) -> () {"
      , "  let _shown = print(\"posted\")"
      , "  ()"
      , "}"
      , "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let events = Events(Handlers{posted: heard})"
      , "    let observer = Observer(events)"
      , "    let name = stringFrom(\"PuduConformanceNotice\")"
      , "    let hub = center()"
      , "    observe(hub, observer, selectorNamed(\"noticePosted:\"), name, 0u64)"
      , "    post(hub, name, 0u64)"
      , "    post(hub, name, 0u64)"
      , "  }"
      , "  0"
      , "}" ], "posted\nposted\n")
  ]

{-| A serial dispatch queue takes blocks through its C interface: a
    synchronous run uses the literal, an asynchronous one keeps a copy. -}
blockBindings :: [Text]
blockBindings =
  [ "foreign \"/usr/lib/libSystem.B.dylib\" {"
  , "  type Queue"
  , "  callback Work(context) -> ()"
  , "  fn queueNew symbol \"dispatch_queue_create\" (label: Str, attributes: UInt64) -> owned Queue by queueRelease"
  , "  fn queueRelease symbol \"dispatch_release\" (queue: Queue) -> ()"
  , "  fn runNow symbol \"dispatch_sync\" (queue: Queue, work: block Work) -> ()"
  , "  fn runLater symbol \"dispatch_async\" (queue: Queue, work: block Work) -> ()"
  , "}" ]

{-| Autorelease pools are ordinary owned handles whose release pops them. -}
poolBindings :: [Text]
poolBindings = init objectiveCBindings <>
  [ "  fn stringFrom selector \"stringWithUTF8String:\" on StringObject (text: Str) -> borrowed StringObject"
  , "  type Pool"
  , "  fn poolPush symbol \"objc_autoreleasePoolPush\" () -> owned Pool by poolPop"
  , "  fn poolPop symbol \"objc_autoreleasePoolPop\" (pool: Pool) -> ()"
  , "}" ]

objectiveCRefusalPrograms :: [(String, Text)]
objectiveCRefusalPrograms =
  [ ("an initialized receiver loses its previous ownership generation", program $ objectiveCBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let old = allocate()"
      , "    let value = initialize(old, \"hello\")"
      , "    print(display(length(value)))"
      , "    print(display(length(old)))"
      , "  }"
      , "  0"
      , "}" ])
  , ("a drained autorelease pool cannot be drained again", program $ poolBindings <>
      [ "fn main() -> Int {"
      , "  unsafe(foreign) {"
      , "    let pool = poolPush()"
      , "    poolPop(pool)"
      , "    poolPop(pool)"
      , "  }"
      , "  0"
      , "}" ])
  ]
