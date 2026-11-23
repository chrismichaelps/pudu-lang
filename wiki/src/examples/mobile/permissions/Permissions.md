---
type: module
path: "@root/examples/mobile/permissions/Permissions.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, permission]
aliases: [Permissions Example]
---

# Permissions Example

## Purpose and interface

A program that checks three permissions and asks for one: the camera, the microphone and the contacts. Its own `pudu.toml` declares all three under `[app.permissions]`, each with the reason the person reads. The table of states is shown as three labels, so a simulator or device run reads the state the host reports for each kind.

The labels, in order:
- `Camera: <state>`
- `Microphone: <state>`
- `Contacts: <state>`

Each label reads `checking` until the platform reports the kind, then the name of its state. The program uses [[Std Mobile Permission]] for `check`, `request` and `recorded`, [[Std Mobile View]] for the tree and the `Permissioned` event, and [[Std Mobile Host]] for the apply and wait calls. The program checks all three kinds once, then requests the camera. Each later report updates its label, including reports after the person changes a permission in Settings and returns.

The manifest declares the three kinds, so the build passes. A program that also requested a kind not declared here would be refused at build time with E6014.

## Simulator expectations

The iOS simulator run is scripted by the harness of `test/ios-simulator.mjs`. The harness's `mobileApp` takes a directory argument, so it can build this example, and a privacy preset list, which it applies with `xcrun simctl privacy` before launch:

| Preset | Action | Expected label |
|---|---|---|
| Camera granted | `simctl privacy grant camera` | `Camera: Granted` |
| Microphone revoked | `simctl privacy revoke microphone` | `Microphone: Blocked` |
| Contacts reset | `simctl privacy reset contacts` | `Contacts: NotAsked` |

The run expects `Camera: Granted`, `Microphone: Blocked` and `Contacts: NotAsked`, in that order. The self-test lines `PUDU_PERMISSION <kind> <state>` of [[pudu-ios-permission]] carry the same states.

## Invariants

- Each label is computed from the table, which changes only when the host reports a kind.
- The program never decides a state; it shows the one reported.
- The program asks for the camera only, so the other two kinds are checked and not prompted.

## Negative Logic

- No retry of a Blocked kind. The example shows Blocked and does not prompt again.
- No timer. Labels update when the platform reports.
- No stored state between launches. The table is rebuilt on each launch.

## Dependencies and consumers

Depends on [[Std Mobile Permission]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Env]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-permission]], and the Android host with [[PuduPermission]]. Its fixture-level counterpart is [[Uses Mobile Permission]]. Build check: [[Pudu Backend Permissions]].

## Resolved Grill Log

- **Q:** Why three kinds, with one requested? **A:** Three states cover the outcomes a run must tell apart: a granted kind, a revoked kind that only Settings can allow, and a kind never asked. Requesting one kind shows the prompt path; the other two show that a check does not prompt.
- **Q:** Why does the run use `simctl privacy` rather than tapping the prompt? **A:** A prompt's answer depends on the person, and the run must produce the same state each time. Setting the privacy state before launch gives a fixed answer for each label.
- **Q:** Why is the harness given a privacy preset list instead of a script per case? **A:** The three cases differ only in the privacy action and the expected label. One list keeps each case's action beside its expectation, so the table above can be checked against the harness.

## Referenced by

[[src/examples/_MOC]] · [[Uses Mobile Permission]] · [[pudu-ios-permission]] · [[PuduPermission]] · [[Std Mobile Permission]] · [[Pudu Backend Permissions]] · [[NATIVE-MOBILE]]
