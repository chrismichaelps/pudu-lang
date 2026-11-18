// A Swift type reached only through C entry points, and the Pudu program that
// drives it: an owned object with its release, a scalar call, a callback
// crossing, and text in. Shared by the macOS check and the iOS simulator run.

export const swiftSource = `final class Counter {
  var value: Int64
  init(start: Int64) { value = start }
}

@_cdecl("swift_counter_new")
public func counterNew(_ start: Int64) -> UnsafeMutableRawPointer {
  Unmanaged.passRetained(Counter(start: start)).toOpaque()
}

@_cdecl("swift_counter_release")
public func counterRelease(_ counter: UnsafeMutableRawPointer) {
  Unmanaged<Counter>.fromOpaque(counter).release()
}

@_cdecl("swift_counter_add")
public func counterAdd(_ counter: UnsafeMutableRawPointer, _ amount: Int64) -> Int64 {
  let held = Unmanaged<Counter>.fromOpaque(counter).takeUnretainedValue()
  held.value += amount
  return held.value
}

@_cdecl("swift_counter_each")
public func counterEach(_ counter: UnsafeMutableRawPointer,
                        _ visit: @convention(c) (UnsafeMutableRawPointer?, Int64) -> Int64,
                        _ context: UnsafeMutableRawPointer?) -> Int64 {
  let held = Unmanaged<Counter>.fromOpaque(counter).takeUnretainedValue()
  var total: Int64 = 0
  for index in 0..<held.value { total += visit(context, index) }
  return total
}

@_cdecl("swift_greeting_length")
public func greetingLength(_ name: UnsafePointer<CChar>) -> Int64 {
  Int64(("Hello, " + String(cString: name)).utf8.count)
}
`;

export const swiftExpected = "4\n14\n11";

/** The program, prefixing each printed line, releasing the counter `releases` times. */
export function swiftProgram(library, prefix = "", releases = 1) {
  const label = (text) => (prefix ? `"${prefix} " + ${text}` : text);
  return `module Main

foreign "${library}" {
  type Counter
  callback Visit(context, index: Int64) -> Int64 else -1i64
  fn counterNew symbol "swift_counter_new" (start: Int64) -> owned Counter by counterRelease
  fn counterRelease symbol "swift_counter_release" (counter: Counter) -> ()
  fn counterAdd symbol "swift_counter_add" (counter: Counter, amount: Int64) -> Int64
  fn counterEach symbol "swift_counter_each" (counter: Counter, visit: Visit, context visit) -> Int64
  fn greetingLength symbol "swift_greeting_length" (name: Str) -> Int64
}

fn squared(index: Int64) -> Int64 { index * index }

fn main() -> Int {
  unsafe(foreign) {
    let counter = counterNew(2i64)
    print(${label("display(counterAdd(counter, 2i64))")})
    let visit = Visit(squared)
    print(${label("display(counterEach(counter, visit))")})
    let _gone = visit.unregister()
    print(${label('display(greetingLength("Pudu"))')})
${"    counterRelease(counter)\n".repeat(releases)}  }
  0
}
`;
}
