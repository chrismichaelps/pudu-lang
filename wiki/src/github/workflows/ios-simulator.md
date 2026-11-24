---
type: module
path: "@root/.github/workflows/ios-simulator.yml"
fidelity: Active
aliases: [iOS Simulator CI]
tags: [module, test, delivery, mobile]
---

# iOS Simulator CI

Run [[iOS Simulator Run]] on the Apple silicon `macos-26` GitHub-hosted runner
for changes to the compiler, its Cabal configuration, or the smoke itself.
Build the compiler with the repository's pinned GHC and Cabal and run the
smoke with `--require-simulator`. Before the smoke, run [[UIKit Coverage Tests]] and the [[UIKit Coverage Inventory]] check against the runner's SDK.

The native-ffi job has a 60-minute timeout and runs as a three-shard matrix (`PUDU_IOS_SHARD` 1/3, 2/3, 3/3). Each shard runs the parts of [[iOS Simulator Run]] whose name hashes to it; one shard boots the iPad matrix. Apps are prebuilt in parallel by [[iOS App Builds]] and cached per shard and commit: an `actions/cache` step restores `~/Library/Caches/pudu-ios-suite` under `ios-apps-<shard>-<sha>`, falling back to the latest cache for that shard.

The workflow path filters include `test/ios-app-builds.mjs`, `test/ios-foreign-apps.mjs` and `examples/mobile/**`, so changes to the suite, its foreign apps or the examples trigger the run.

Build steps restore two caches before `cabal update`. The first holds the cabal store (`~/.local/state/cabal/store` and `~/.cabal/store`), keyed on the hashes of `*.cabal` and `cabal.project*`. The second holds `dist-newstyle`, keyed `ios-dist-<os>-<ref>-<sha>`, restoring from the same ref and then from `refs/heads/dev`. Recompilation is decided by source hashes, so only changed modules compile again.

## Resolved Grill Log

- Keep the workflow path-filtered and cancel superseded runs of the same ref.
- Use a runner image whose default Xcode meets the floor in [[Native Platform Adoption]], and its installed simulator runtimes. An older Xcode or a missing runtime fails the job so every successful run proves the C foreign call executed.
- Feature pushes run the gate before stacked pull requests target dev.
- **Q:** Why 75 minutes? **A:** The device matrix (iPhone and iPad, with the capability run) exceeded 40 minutes on a contended hosted runner while every check passed; caching the cabal store and build tree removes most of the twelve-minute compile. _Rejected:_ dropping the iPad from CI.

## Referenced by

[[src/_MOC]] · [[iOS Simulator Run]] · [[Native Mobile Targets Delivery]] · [[UIKit Coverage Inventory]]
