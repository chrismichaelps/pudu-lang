---
type: changelog
tags: [changelog]
---

# Changelog

## 2026-11-14 — iOS navigation contract (#920)

- [[Native iOS Navigation]] specifies application-owned route state, UIKit transition completion, and native page sheets.

## 2026-11-14 — iOS scrolling and keyboard avoidance (#919)

- `Scroll(View)` mounts a vertical root viewport with one reconciled child. UIKit constrains root content to the safe area, resizes it for the docked keyboard and reveals the focused field ([[Native iOS Scrolling Delivery]]). Generated iOS apps enable ProMotion timing hints and the iOS spec sets variable-refresh acceptance criteria.

## 2026-11-14 — Native application bundles (#916)

- `pudu build --native --target ios-simulator-arm64 --app` writes a signed simulator application with the embedded iOS host ([[Native App Delivery]]). Publication refuses occupied output paths.
