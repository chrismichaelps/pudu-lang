---
type: module
path: "@root/src/Pudu/Cli/Doctor.hs"
fidelity: Active
domain: "[[Pudu Program]]"
subsystem: "[[Tooling]]"
grammar: "[[grammar/haskell]]"
tags: [module, cli, doctor, mobile]
aliases: [Pudu CLI Doctor]
---

# Pudu CLI Doctor

## Purpose and interface

Own `pudu doctor --native`: one report of the native platform state, from the ledger
([[Backend Ledger]]) and the installed tools ([[Backend Toolchain Probe]]). The entry
returns the report and its exit status; the executable prints and exits.

```haskell
doctorNative :: [Text] -> IO DoctorRun
data DoctorRun = DoctorRun { doctorLines :: ![Text], doctorStatus :: !Int }
```

The only accepted argument is `--native`. Any other argument list prints usage and exits 2.

## Algorithm and invariants

The report prints one line per item, each finding with its code:

| Line | Content |
| --- | --- |
| Xcode | the installed version, the minimum and the tested release |
| SDK | each of `iphoneos` and `iphonesimulator` with its version |
| Deployment | the deployment target |
| Store rule | each rule as `met`, `due in N days`, or `missed`, with its source |
| Capability | each capability as `available`, or the SDK it needs |
| Simulator | the newest runtime, and each device family it offers with the count of device types |

- The report is built from [[Backend Ledger]]'s `assess` for the device purpose and the
  simulator purpose, so the doctor and the builds never disagree.
- Findings from `assess` print with the codes of [[Diagnostic Native]]: `E6009`, `E6010`,
  `W6011`, `W6012`.
- The exit status is 1 when any finding refuses a Development build, or when no Xcode is
  found. Otherwise it is 0. A warning never raises the status.
- A tool that cannot be read prints its `ToolchainSdkMissing` text in place of the line
  and sets status 1 when the missing item is Xcode.

## Negative Logic (Prohibited Paths)

- No build, no compile and no write. The doctor only reads the state.
- No model table and no guessed device names. The simulator line counts what the tools
  list.
- No second assessment. A status that disagrees with what a build would report is a defect.

## Dependencies and consumers

[[Backend Ledger]], [[Backend Toolchain Probe]], [[Diagnostic Native]], [[Pudu CLI]].
The assessment it prints is tested by [[Backend Ledger Spec]].

## Resolved Grill Log

- **Q:** Why a doctor command when builds already check? **A:** A build reports only what
  blocks it; the doctor shows the whole state before a release or a toolchain upgrade.
  _Rejected:_ asking each build to print the full state, which would bury its output.
- **Q:** Why does a warning not change the status? **A:** A status of 1 means the next
  Development build will not run. Warnings describe work to do, not a blocked build.

## Referenced by

[[src/Pudu/_MOC]] · [[Pudu CLI]] · [[Backend Ledger]] · [[Native Platform Adoption]]
