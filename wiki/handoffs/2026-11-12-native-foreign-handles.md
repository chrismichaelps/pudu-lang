---
type: handoff
status: ACTIVE
issue: 853
aliases: [Native Foreign Handles Delivery]
---
# Native Foreign Handles Delivery

Language Architect → Backend Engineer → Test Engineer. This continuation
uses `feature/853-native-foreign-handles` from `dev` after #852. The backend
scope is checked handle identity and release metadata, typed call wrappers,
boxed carriers, and controlled teardown. The test scope is [[Backend Foreign
Programs]] for differential cases and [[Backend Text Leak Tests]] for counted
ownership cases. Independent Language Architect and Forensic Guardian reviews
follow validation.

[[Native Foreign Call Sites]] governs the emitted boundary. Call preparation
validates text and resolves the invoked symbol and release symbol before
checking claims or entering the library. The existing native run gate covers
liveness through the call. Claims belong to the run and teardown drains them
before entry result or fatal diagnostic reporting. Output slots stay with #854.

## Validation

The focused differential groups and all eight counted programs pass. Window
and Snake build with the existing raylib 6 bindings. Successful macOS runs
match interpreter stdout, stderr and exit status. One Window attempt failed
during GLFW monitor initialization; two native retries completed with 180
frames and empty stderr. The full optimized gate is running.

The layout and Core vocabulary prerequisite is tracked in PR #865.

## Exact next action

Check the optimized repository gate and record its outcome on the handle pull request.

## Referenced by

[[handoffs/_MOC]] · [[Native Foreign Call Sites]] · [[Native Emission Coverage]]
