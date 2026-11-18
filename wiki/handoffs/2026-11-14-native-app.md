---
type: handoff
status: ACTIVE
issue: 916
aliases: [Native App Delivery]
---

# Native App Delivery

Language Architect → Backend Engineer. Phase 3 of [[Pudu Native]]: `pudu build --app` writes a runnable simulator application. Backend Engineer → Forensic Guardian review covers [[Backend Toolchain App]] and [[iOS Host Adapter]].

## Scope

`pudu build <file> --native --target ios-simulator-arm64 --app` builds the program's static library ([[Backend Toolchain Library]]), links it with the embedded iOS host, writes `Info.plist`, signs the bundle ad hoc and publishes `<Name>.app` by rename. The host source is embedded through [[Native Toolchain Host Sources]] and lives at `cbits/pudu_ios_host.m`. Device targets, Android and occupied output paths are refused.

## Ownership

Backend Engineer owns exclusive bundle publication in [[Backend Toolchain App]] and the output collision regression in [[iOS Simulator Run]]. Independent review is pending.

## Evidence so far

`pudu build --native --target ios-simulator-arm64 --app` built Counter, Form and List; the simulator smoke run installed and launched each: `Count: 3`; `Hello, Ada (subscribed)` and `Hello, stranger`; `3 items`, `Milk 3`, `Milk 1`, `Milk 2`; status 0 every time. Each executable is about 305 KB. `--app` without `--native`, with the device target, and given twice are each refused with their message. The application identifier and property-list properties pass ([[Native App Tests]]).

## Exact next action

After PRs #915 and #918 land, implement the scrolling, safe-area and keyboard-avoidance slice in #919, starting with [[Std Mobile View]] and [[iOS Host Adapter]].

## Referenced by

[[handoffs/_MOC]] · [[Pudu Native]] · [[Backend Toolchain App]] · [[iOS Host Adapter]] · [[iOS Simulator Run]] · [[Native Keyed Lists Delivery]] · [[Native App Tests]]
