---
type: module
path: "@root/scripts/uikit-coverage.mjs"
fidelity: Active
aliases: [UIKit Coverage Inventory]
---
# UIKit Coverage Inventory

## Purpose and interface

Read the UIKit headers of the installed iOS simulator SDK and the iOS host sources under `packages/pudu/v0.1/cbits/pudu_ios_*`, and report which platform classes and accessibility traits the host realizes. Node core APIs only. Exports pure functions for [[UIKit Coverage Tests]]: `inventory(headers)` classifies every `@interface Name : Super` declaration by its nearest known ancestor into gestures (UIGestureRecognizer), feedback (UIFeedbackGenerator), controls (UIControl) and views (UIView, excluding controls), and collects `UIAccessibilityTrait*` constants other than `UIAccessibilityTraitNone` as traits; `measure(inventory, hostSource)` marks a name covered when it occurs as a whole identifier in the host sources; `render(report)` produces the table; `update(page, block)` replaces the single `uikit-coverage` marker block in [[Pudu Native iOS UI]]. The CLI accepts `--report`, `--write` or `--check`. The SDK path comes from `xcrun --sdk iphonesimulator --show-sdk-path`, using `PUDU_XCRUN` when set.

## Contract and failure behavior

Names in each category are sorted. The rendered block records the SDK name it was measured against. `--write` rewrites the block. `--check` fails when the installed SDK is the recorded one and the block is stale; when the installed SDK differs it prints the classes and traits the recorded block does not know and succeeds, so a new Xcode shows its additions without breaking unrelated work. A missing SDK, a missing host directory, an empty category, or missing, duplicate or reversed markers fail without modifying files. All bytes outside the block are preserved.

## Resolved Grill Log

- **Q:** Keep the inventory as a hand-written sentence? **A:** No; the table is measured from the SDK headers so a claim cannot outlive the code.
- **Q:** Count a class covered because a Pudu view names the concept? **A:** No; only an identifier in the host sources counts, since that is where the platform class is created.
- **Q:** Fail the check on a different SDK? **A:** No; report the difference and succeed. The block is rewritten when the tested Xcode moves in [[Native Platform Adoption]].
- **Q:** Include view controllers? **A:** No; presentation is tracked by the feature table, and this inventory stays with classes placed in the view tree, recognizers, generators and traits.

## Dependencies and consumers

[[Pudu Native iOS UI]] · [[iOS Host Adapter]] · [[iOS Simulator CI]]

## Referenced by

[[src/_MOC]] · [[UIKit Coverage Tests]] · [[Pudu Native iOS UI]]
