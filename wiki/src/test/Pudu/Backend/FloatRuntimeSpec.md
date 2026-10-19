---
type: module
path: "@root/test/Pudu/Backend/FloatRuntimeSpec.hs"
fidelity: Active
aliases: [Native Floating Runtime Tests]
grammar: "[[grammar/haskell]]"
---
# Native Floating Runtime Tests

## Purpose and interface

Export floatRuntimeProperties :: [(String,IO Property)]. Compile actual
RuntimePart selection through [[Native Runtime Dependencies]], honoring PUDU_CC
and requiring a C11 compiler. Use the real runtime prelude, not fixture headers
that might conceal missing selected dependencies.

## Evidence contract

Compare representative and seeded raw-bit print lines with locked GHC show,
including signed zeros, infinities, NaN payloads, extrema, decimal-layout edges
and widened Float32 values. Require exact status/stdout/stderr, unique catalogue
names, known ordered floating prerequisites and retained notice bytes. Printing
alone must exclude floating arithmetic/target headers. Execute minimal public
floating helper closures through the actual production catalogue.

Instrument fwrite/fflush after the real prelude. Verify one complete buffered
line and one flush for success, zero/partial write failures and flush failures;
subsequent source-independent continuation must still execute. POSIX launchers
close stdout/stderr/both with default/ignored/blocked SIGPIPE. Check ordinary
continuation and a later real fatal diagnostic against the existing process
contract. Explicitly retain pending Windows pipe evidence; no false skip of
output, closure or instrumentation properties. Run Clang/GCC, ASan/UBSan and
full clean gates. Fixed returned properties are not repeated independent IO.

## Resolved Grill Log

- **Q:** Test only the isolated formatter? **A:** Select actual RuntimePart entries via the production dependency facade.
- **Q:** Infer line atomicity from matching stdout? **A:** Count write/flush calls and inspect the submitted bytes.
- **Q:** Infer process behavior from an inherited ignored signal? **A:** Reset it in an exec launcher and exercise blocked/default/ignored states.

## Dependencies and consumers

[[Native Floating Runtime]] · [[Native Runtime Dependencies]] · [[Backend Runtime]] · [[Pudu Test Cabal Manifest]] · [[Repository Test Runner]]

## Referenced by

[[src/_MOC]] · [[Backend Module Map]] · [[Native Floating Runtime Delivery]]

## Text catalogue (#515)

The integer-compatibility check skips text parts as well as floating ones,
since [[Native Text Runtime]] adds its own dependencies to the facade.
