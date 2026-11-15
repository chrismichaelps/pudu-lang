---
type: module
path: "@root/src/Pudu/Backend/Ledger.hs"
fidelity: Active
subsystem: "[[Backend]]"
grammar: "[[grammar/haskell]]"
tags: [module, backend, toolchain, mobile, ledger]
aliases: [Backend Ledger]
---

# Backend Ledger

## Purpose and interface

The pure ledger of platform toolchain facts: the minimum and tested Xcode, the
deployment target, the store rules with their effective dates and sources, and the
platform capabilities with the SDK each one needs ([[Native Platform Adoption]]).
Pure: no process, path, environment or clock. The caller supplies the day.

```haskell
data Release = Release { releaseParts :: ![Int] }
parseRelease :: Text -> Maybe Release
renderRelease :: Release -> Text

data StoreRule = StoreRule
  { ruleStore :: !Text, ruleXcode :: !Release, ruleSdk :: !Release
  , ruleFrom :: !Day, ruleSource :: !Text }
data Capability = Capability
  { capabilityName :: !Text, capabilitySdk :: !Release, capabilityPurpose :: !Text }
data Ledger = Ledger
  { ledgerPlatform :: !Text, ledgerMinimumXcode :: !Release, ledgerTestedXcode :: !Release
  , ledgerDeployment :: !Release, ledgerRules :: ![StoreRule]
  , ledgerCapabilities :: ![Capability] }

appleLedger :: Ledger
data Purpose = Development | Distribution
data Installed = Installed { installedXcode :: !Release, installedSdk :: !Release }

data Finding
  = XcodeBelowMinimum !Release !Release
  | XcodeUntested !Release !Release
  | StoreRuleMissed !StoreRule
  | StoreRuleDue !StoreRule !Int

assess :: Ledger -> Day -> Purpose -> Installed -> [Finding]
isRefusal :: Finding -> Bool
capabilityStates :: Ledger -> Release -> [(Capability, Bool)]
ledgerTriple :: Ledger -> Text -> Bool -> Text
```

`XcodeBelowMinimum` carries the installed and the minimum release. `XcodeUntested`
carries the installed and the tested release. `StoreRuleDue` carries the rule and the
whole days until it takes effect. Each finding carries the values its message needs;
no finding carries text.

## Algorithm and invariants

- `Release` is a non-empty list of non-negative integers, compared numerically part by
  part, with a missing trailing part equal to zero. `26.0` equals `26`; `26.10` is
  greater than `26.9`. `parseRelease` accepts only digits separated by single dots.
  `renderRelease` writes the parts joined by dots with no padding.
- `appleLedger` holds the iOS facts: minimum Xcode 26.0, tested Xcode 26.6, deployment
  target 15.0. Its store rule is the requirement that apps be built with Xcode 26 and
  the iOS 26 SDK, effective 2026-04-28, with source
  `https://developer.apple.com/news/upcoming-requirements/`. Its capability list holds
  two rows: `glass-material`, which needs SDK 26.0 (glass realization of materials on
  iOS 26 or later, see [[iOS Host Material]]), and the fold posture, which needs SDK 27.1
  (the iPhone Duo hinge).
- The App Store minimum deployment target (iOS 13, effective 2026-09-09) constrains the
  deployment target, not the toolchain, so it is not a `StoreRule`. The ledger test asserts
  that `ledgerDeployment` meets it.
- `assess ledger day purpose installed` returns findings in this order: the toolchain
  findings first, then one finding per store rule in ledger order.
- Toolchain findings:
  - `XcodeBelowMinimum` when the installed Xcode is older than `ledgerMinimumXcode`.
  - `XcodeUntested` when the installed Xcode's major and minor numbers are greater than
    the tested release's major and minor numbers. The patch part is ignored.
- Store rule findings, for a rule whose `ruleXcode` or `ruleSdk` the installed toolchain
  does not reach:
  - `StoreRuleMissed` when `ruleFrom` is on or before the day.
  - `StoreRuleDue days` when `ruleFrom` is after the day and `days` is at most 90.
    A rule taking effect exactly 90 days away is due. A rule 91 days away is not reported.
  - A rule the installed toolchain meets yields no finding.
- `isRefusal`: `XcodeBelowMinimum` is always a refusal. `StoreRuleMissed` is a refusal for
  `Distribution` and a warning for `Development`. `XcodeUntested` and `StoreRuleDue` are
  warnings. The purpose decides refusal only for `StoreRuleMissed`; the caller passes
  the purpose to `assess` so that the finding already reflects it.
- `capabilityStates` pairs each capability with whether the given SDK release reaches
  `capabilitySdk`.
- `ledgerTriple ledger arch simulator` is `<arch>-apple-ios<deployment>` for a device and
  `<arch>-apple-ios<deployment>-simulator` for a simulator. The deployment is rendered
  with `renderRelease`, so `arm64` and the ledger's `15.0` give `arm64-apple-ios15.0`.

## Negative Logic (Prohibited Paths)

- No IO, no clock read, no environment read. The day is an argument.
- The ledger never guesses a future rule. A rule absent from `ledgerRules` is not
  reported, however likely it is.
- A capability absent from `ledgerCapabilities` is unavailable. Presence in the list is
  the only way a capability is known.
- No message text, no diagnostic code and no span here. [[Diagnostic Native]] owns the
  codes and wording; this module decides only what holds.
- No separate data file. A ledger read from disk at run time is refused by design, because
  the ledger must be the one the compiler was tested against.

## Dependencies and consumers

`time`, `text`, `containers`. Consumed by [[Backend Toolchain Probe]],
[[Backend Toolchain Library]], [[Backend Toolchain App]], [[Backend Native Target]],
[[Pudu CLI Doctor]] and [[Backend Ledger Spec]].

## Resolved Grill Log

- **Q:** Why data in a module rather than a file read at run time? **A:** The ledger
  ships with the compiler that was tested against it; a typed value cannot be malformed.
  _Rejected:_ a JSON or TOML file beside the compiler, which could drift from the tests
  and need a parser that can fail at run time.
- **Q:** Why kinds rather than message text? **A:** Codes and wording belong to
  [[Diagnostic Native]]; the ledger decides only what holds. _Rejected:_ findings that
  carry rendered text, which would couple the decision to the presentation.
- **Q:** Why does the App Store deployment floor not appear as a store rule? **A:** A
  store rule here names the toolchain that must build the app. The deployment floor
  constrains a value the compiler writes, so it is checked as a fact about the ledger.
  _Rejected:_ a rule with empty Xcode and SDK fields, which would make the type lie.
- **Q:** Why is `XcodeUntested` a warning? **A:** New Xcode releases must keep building on
  the day they ship; the warning asks for the suite to run and the version to be recorded.
  _Rejected:_ refusing newer toolchains.

## Referenced by

[[src/Pudu/Backend/_MOC]] · [[Native Platform Adoption]] · [[Backend Toolchain Probe]] · [[Pudu CLI Doctor]]
