---
type: module
path: "@root/.github/workflows/ios-simulator.yml"
fidelity: Active
aliases: [iOS Simulator CI]
tags: [module, test, delivery, mobile]
---

# iOS Simulator CI

Run [[iOS Simulator Run]] on an Apple silicon GitHub-hosted macOS runner
for changes to the compiler, its Cabal configuration, or the smoke itself.
Build the compiler with the repository's pinned GHC and Cabal and run the
smoke with `--require-simulator`.

## Resolved Grill Log

- Keep the workflow path-filtered and cancel superseded runs of the same ref.
- Use the runner's Xcode and installed simulator runtimes. A missing runtime
  fails the job so every successful run proves the C foreign call executed.
- Feature pushes run the gate before stacked pull requests target dev.

## Referenced by

[[src/_MOC]] · [[iOS Simulator Run]] · [[Native Mobile Targets Delivery]]
