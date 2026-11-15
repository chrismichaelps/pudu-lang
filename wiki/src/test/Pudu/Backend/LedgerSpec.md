---
type: module
path: "@root/test/Pudu/Backend/LedgerSpec.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
tags: [module, test, backend, mobile, ledger]
aliases: [Backend Ledger Spec]
---

# Backend Ledger Spec

## Purpose and interface

`backendLedgerProperties :: [(String, IO Property)]` holds [[Backend Ledger]] and the pure
parsers of [[Backend Toolchain Probe]] to their contracts. No platform tool runs: every
check uses fixed values, a fixed day and recorded tool output.

## Algorithm and invariants

- Release parsing and ordering: `26.0` equals `26`; `26.10` is greater than `26.9`;
  malformed text such as `26..0`, `v26` and the empty string is `Nothing`.
- Each finding kind is produced exactly where the ledger says, and its refusal or warning
  status follows the purpose:
  - `XcodeBelowMinimum` is a refusal for both purposes.
  - `XcodeUntested` is a warning for both purposes, compares major and minor only, and is
    not raised for an Xcode equal to the tested release.
  - `StoreRuleMissed` is a refusal for `Distribution` and a warning for `Development`.
  - `StoreRuleDue` is a warning for both purposes.
- The 90-day window: a rule effective 90 days after the day is `StoreRuleDue 90`; 91 days
  yields no finding; 1 day yields `StoreRuleDue 1`; a rule effective on the day is
  `StoreRuleMissed`; a rule the installed toolchain meets yields no finding at any date.
- Finding order: toolchain findings first, then rules in ledger order, each rule once.
- Capability states: the iPhone Duo posture is unavailable on SDK 27.0 and available on
  SDK 27.1; a capability absent from the ledger is never reported.
- Triples from the ledger: `arm64-apple-ios15.0` for a device, and
  `arm64-apple-ios15.0-simulator` for a simulator. Changing the ledger's deployment target
  changes both, so the minimum release is stated once.
- The ledger meets the App Store minimum deployment target (iOS 13).
- Parsers against recorded output:
  - `parseXcodeVersion` accepts `Xcode 26.6` followed by a build line and rejects a first
    line that is not an Xcode version.
  - `parseRuntimes` keeps an available iOS runtime, drops an unavailable one and a macOS
    one, and skips unknown lines.
  - `parseDeviceTypes` assigns `iPhone`, `iPad` and an other family, and skips unknown
    lines.
  - None of the parsers throws on empty input or on input with only unknown lines.
- End-to-end refusal: a fake `xcrun` answers Xcode 25.4 and SDK 18.5. `compileLibrary`
  returns `ToolchainOutsideLedger` carrying `XcodeBelowMinimum 25.4 26.0` and writes nothing.

## Dependencies and consumers

[[Backend Ledger]], [[Backend Toolchain Probe]], [[Pudu CLI Doctor]]. Consumed by
[[Repository Test Runner]].

## Resolved Grill Log

- **Q:** Why fixed days and recorded output? **A:** A test that reads the clock or the
  installed Xcode would pass or fail by machine. The day and the tool text are arguments,
  so the window edges are exact. _Rejected:_ live tool calls in the unit suite; the
  simulator run owns those.
- **Q:** Why test the Duo posture at 27.0 and 27.1? **A:** The capability's only
  observable boundary is its SDK; testing both sides of it shows the comparison is
  numeric.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Ledger]] · [[Repository Test Runner]]
