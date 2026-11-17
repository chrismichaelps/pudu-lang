---
type: module
path: "@root/src/Pudu/Backend/Toolchain/Probe.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain, mobile, probe]
aliases: [Backend Toolchain Probe]
---

# Backend Toolchain Probe

## Purpose and interface

Asks the platform tools what is installed. Discovery only: the module reports facts and
never decides whether they are enough, which is [[Backend Ledger]]'s work.

```haskell
data Runtime = Runtime { runtimeName :: !Text, runtimeRelease :: !Release }
data DeviceFamily = IPhone | IPad | OtherFamily !Text
data DeviceType = DeviceType { deviceTypeName :: !Text, deviceFamily :: !DeviceFamily }
data Inventory = Inventory { inventoryRuntimes :: ![Runtime], inventoryDeviceTypes :: ![DeviceType] }

appleInstalled :: FilePath -> AppleSdk -> Int -> IO (Either ToolchainFailure Installed)
simulatorInventory :: FilePath -> Int -> IO (Either ToolchainFailure Inventory)

parseXcodeVersion :: Text -> Maybe Release
parseRuntimes :: Text -> [Runtime]
parseDeviceTypes :: Text -> [DeviceType]
```

`appleInstalled xcrun sdk seconds` runs `xcrun xcodebuild -version` and
`xcrun --sdk <appleSdkName sdk> --show-sdk-version`, each through
[[Backend Toolchain Process]] with the given deadline. `simulatorInventory xcrun seconds`
runs `xcrun simctl list runtimes` and `xcrun simctl list devicetypes`.

## Algorithm and invariants

- `parseXcodeVersion` reads the first line of the `xcodebuild -version` output. It accepts
  the line `Xcode N.N` and returns the release; any other first line is `Nothing`.
- `parseRuntimes` keeps only the available iOS runtime lines and returns each with its
  release. Unavailable runtimes, other platforms and unknown lines are skipped.
- `parseDeviceTypes` returns each device type line with its name and family: `iPhone`,
  `iPad`, or `OtherFamily` carrying the family text. A family takes two words when the name
  begins with the maker (Apple Watch, Apple TV, Apple Vision), otherwise the first word.
  Unknown lines are skipped.
- Both simulator listings are read as plain text. The parsers are pure and are tested
  against recorded tool output, including unknown lines. The compiler carries no JSON
  dependency for this.
- The SDK version is read from the SDK's own answer and its release is the installed SDK
  for [[Backend Ledger]]'s `assess`.
- The first simulator query uses the same five-minute allowance as the simulator run
  ([[iOS Simulator Run]]), because a cold simulator service can be slow to answer.

## Negative Logic (Prohibited Paths)

- No parser throws. A line that does not match is skipped; a first line that is not an
  Xcode version is `Nothing`.
- An unreadable answer is `ToolchainSdkMissing` naming the command that failed, never a
  guessed version. A tool that exits nonzero, prints nothing, or runs past the deadline
  is unreadable.
- No assessment and no refusal here.
- The plain listing of runtimes does not name the device types each runtime supports, so
  the inventory reports what is installed and does not claim support. The device matrix
  ([[iOS Simulator Run]]) detects an unsupported pair when creation or boot fails and
  reports that as a failure of the family.

## Dependencies and consumers

[[Backend Ledger]], [[Backend Toolchain Process]], [[Backend Native Target]]. Consumed by
[[Backend Toolchain Library]], [[Backend Toolchain App]] and [[Pudu CLI Doctor]].

## Resolved Grill Log

- **Q:** Why a separate module? **A:** Discovery and assessment are different
  responsibilities, and the library builder stays small. A probe that reports facts can be
  tested with recorded output and no Xcode installed. _Rejected:_ probing inside
  [[Backend Toolchain Library]].
- **Q:** Why plain text rather than structured simulator output? **A:** The listing is
  parsed by pure, tested functions and the compiler carries no JSON dependency for it.
  _Rejected:_ `--json` output, which would add a parser and a failure mode.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Backend Toolchain Library]] · [[Pudu CLI Doctor]] · [[Backend Ledger]]
