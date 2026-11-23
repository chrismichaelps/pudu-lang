---
type: module
path: "@root/examples/mobile/Vault.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, storage]
aliases: [Vault Example]
---

# Vault Example

## Purpose and interface

A program that exercises storage on a phone screen: it counts its launches in plain storage, keeps a token in secure storage and reads it back, and writes then removes a temporary key and reads it back as absent. Labels report each answer, so a simulator or device run reads the same results the host reports.

The labels, in order:
- `Launches: n`: the count of launches. The first launch writes 1 to plain storage; each later launch reads the stored text, parses it with `Num.parseInt`, adds one, and writes the new count back.
- `Token: s3cret`: the secure token, read back after it was written in the same launch. A secure read that finds nothing shows `missing`.
- `Temporary: none`: the answer for a key that was written and then removed. The removal lands before the read, so the read answers absent.

The program uses [[Std Mobile Storage]] for the requests, [[Std Mobile View]] for the tree and the events, [[Std Mobile Host]] for the apply and wait calls, and [[Std Num]] for `parseInt`. A stored count that does not parse, or is negative, counts as zero.

## Simulator expectations

The iOS simulator run launches the application twice. The first launch shows `Launches: 1, Token: s3cret, Temporary: none`. The second launch, with the same simulator data, shows `Launches: 2, Token: s3cret, Temporary: none`. The count is kept by user defaults and the token by the keychain, so both survive the relaunch.

## Invariants

- The launch count is written before the next event is read, so a relaunch sees the count of the previous launch.
- Each label is computed from the model, which is updated only by storage answers.
- The program never decides a platform answer; it shows what the host returns.

## Negative Logic

- No timer and no retry of a missing answer.
- No secret is written to a label or a log. The token is shown only because this example exists to show it survives; a real program would not display a secret.
- No reinstall check in the program itself. Whether a secure value vanishes after an uninstall is a device run, recorded in [[980-storage]].

## Dependencies and consumers

Depends on [[Std Mobile Storage]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Num]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-storage]], and the Android host with [[PuduStore]]. Its fixture-level counterpart is [[Uses Mobile Storage]]; the parser is checked by [[Uses Num Parse]].

## Resolved Grill Log

- **Q:** Why count launches rather than store a timestamp? **A:** A count is one integer that the program reads and writes with no clock. It shows that plain storage kept a value across a relaunch, which is the claim the example makes.
- **Q:** Why read the token in the same launch that wrote it? **A:** The read answers after the write, as the stream order promises. The label proves the write reached the store before the read, not only that an earlier launch wrote it.
- **Q:** Why parse the count with `Num.parseInt`? **A:** The stored text comes from outside the program's own types. A parser that answers `None` rather than stopping lets a damaged value count as zero.

## Referenced by

[[src/_MOC]] · [[Std Mobile Storage]] · [[pudu-ios-storage]] · [[PuduStore]] · [[Uses Mobile Storage]] · [[980-storage]] · [[NATIVE-MOBILE]]
