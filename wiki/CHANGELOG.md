---
type: changelog
tags: [changelog]
---

# Changelog

## 2026-11-14 — iOS navigation contract (#920)

- [[Native iOS Navigation]] specifies application-owned route state, UIKit transition completion, and native page sheets. The stack implementation branch adds duplicate-ID validation, stale-pop reduction, and the ordered route snapshot encoder. Mounted route commits reuse body IDs across in-place edits and retire replaced bodies after publishing the snapshot. The shared component API belongs to Pudu Foundation UI. The UIKit adapter now applies mounted route snapshots and reports completed native pops to the Pudu model. Simulator coverage checks that unchanged completions and programmatic pops produce no native event. Native page sheets share the mounted stack allocator and report the dismissed instance to Pudu. The replacement smoke case verifies that an old dismissal callback leaves the latest sheet visible.

## 2026-11-14 — iOS scrolling and keyboard avoidance (#919)

- `Scroll(View)` mounts a vertical root viewport with one reconciled child. UIKit constrains root content to the safe area, resizes it for the docked keyboard and reveals the focused field ([[Native iOS Scrolling Delivery]]). Generated iOS apps enable ProMotion timing hints and the iOS spec sets variable-refresh acceptance criteria.

## 2026-11-14 — Native application bundles (#916)

- `pudu build --native --target ios-simulator-arm64 --app` writes a signed simulator application with the embedded iOS host ([[Native App Delivery]]). Publication refuses occupied output paths.
