---
type: module
path: "@root/examples/mobile/where/Where.pudu"
fidelity: Active
domain: "[[Pudu Native]]"
tags: [module, example, mobile, native, location, permission]
aliases: [Where Example]
---

# Where Example

## Purpose and interface

A program that shows the device position as the host reports it. It requests the location permission when it starts. When the answer is Granted or Limited, it locates once at precise accuracy and starts tracking at approximate accuracy with a 50 meter distance. On any other permission state it shows no position. Labels report each answer, so a simulator or device run reads the same results the host reports.

The labels, in order:
- `Permission: <State>`: the state the permission module reports.
- `Latitude: <int>`: the latitude in ten-millionths of a degree, or `Latitude: none` before a fix or without one.
- `Longitude: <int>`: the longitude in ten-millionths of a degree, or `Longitude: none` before a fix or without one.
- `Fixes: <count>`: the number of `Located` answers that carried a position.

The program uses [[Std Mobile Location]] for the requests, [[Std Mobile Permission]] for the permission request, [[Std Mobile View]] for the tree and the events, and [[Std Mobile Host]] for the apply and wait calls.

The location permission is declared in the `pudu.toml` beside the program, under `[app.permissions]`, with a reason that states why the position is needed. The build requires that declaration because the program requests the location kind; without it the build fails.

## Simulator expectations

The iOS simulator run starts the application with `PUDU_UI_LOCATION_TEST=1` after a privacy grant for location and a `simctl location set 18.4655,-66.1057` command. It expects the labels `Permission: Granted`, `Latitude: 184655000` and `Longitude: -661057000`, a `Fixes:` label, and a `PUDU_LOCATION` line on standard output. A second run with location revoked expects `Permission: Blocked` and `Latitude: none`. A refused application with accuracy code 7 is reported by the host as `used unknown location accuracy 7`.

## Invariants

- Each label is computed from the model, which is updated only by `Located` answers and the permission state.
- The program never decides a position; it shows the coordinates the host returns.
- Tracking is started only after the permission state is Granted or Limited.

## Negative Logic

- No position is shown while the permission is not Granted or Limited, even when a host would answer one.
- No retry of a `None` answer. A missing fix leaves the coordinate labels at `none`.
- No address, place name or history of positions is kept or shown.
- No background tracking. The program's tracking is tied to its foreground session.

## Dependencies and consumers

Depends on [[Std Mobile Location]], [[Std Mobile Permission]], [[Std Mobile View]], [[Std Mobile Events]], [[Std Mobile Host]] and [[Std Mobile Lifecycle]]. Hosts: [[iOS Host Adapter]] with [[pudu-ios-location]], and the Android host with [[PuduLocation]]. Its fixture-level counterpart is [[Uses Mobile Location]].

## Resolved Grill Log

- **Q:** Why does the example locate once before tracking? **A:** A single precise fix gives the label a value at once. Tracking at approximate accuracy then keeps it current without the cost of precise updates.
- **Q:** Why does the example show the permission state beside the position? **A:** A `none` coordinate has two causes: the permission was not granted, or no fix arrived. The state label tells the reader which one applies.
- **Q:** Why is the location reason in the manifest rather than in the program? **A:** The build reads the declaration to include the location host code. The reason is shown to the person by the platform prompt, so it belongs with the declared permission.

## Referenced by

[[src/examples/_MOC]] · [[Std Mobile Location]] · [[pudu-ios-location]] · [[PuduLocation]] · [[Uses Mobile Location]] · [[About Example]] · [[NATIVE-MOBILE]]
