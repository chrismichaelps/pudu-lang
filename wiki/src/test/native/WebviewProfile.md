---
type: module
path: "@root/test/native/WebviewProfile.cpp"
fidelity: Active
aliases: [Webview Windows Profile Harness]
tags: [module, test, desktop, windows, isolation]
---
# Webview Windows Profile Harness

## Purpose and interface

Exercise Windows storage admission without a renderer. Path cases set `LOCALAPPDATA` inside the
process and call [[Pudu Webview Windows Profile]] directly. Admission cases drive the production
environment completion with counted environment and controller-options doubles from
[[Webview Windows Doubles]] and read the drained event records.

## Cases

| Case | Expected |
| --- | --- |
| Private interface unavailable | `refused … unsupported`, no controller request, view closed |
| Options creation fails, or succeeds with null | `refused … platform`, no ordinary creation |
| Profile-name or private-mode setter fails | `refused … platform`, options released |
| Private mode reads back disabled | `refused … platform` |
| Controller request fails immediately | `refused … platform`, view closed, no `crashed` |
| Named view, ordinary creation fails | `refused … platform` |
| Private success | one request with private mode and a fresh profile name; no ordinary call |
| `LOCALAPPDATA` missing, empty or relative | Platform refusal before realizing |
| `LOCALAPPDATA` longer than the fixed path limit | full value used, not truncated |
| Unnamed and ephemeral views | private folder, distinct profile names |
| Same label twice | same store folder; different labels differ |
| Label `default` | a store folder, not the private folder |
| Planted identity file for another label | Platform refusal |
| Earlier 16-hex layout | never produced; every folder is under `webview\2` |

Each double counts references, so every case also checks that the options, the private
interface and the environment end with the references they started with.

## Grill Log

- **Q:** Why drive the completion directly? **A:** The defects are in admission branches taken
  after the runtime answers. Doubles make each failure deterministic; real storage behavior still
  needs the actual runtime and is recorded separately.
- **Q:** Why set the environment variable in-process? **A:** The production code reads it at call
  time, so each case controls the input without a second program.

## Dependencies and consumers

Uses [[Pudu Webview Windows Host]], [[Pudu Webview Windows Profile]], [[Pudu Webview Windows Environment]] and [[Webview Windows Doubles]]. Run by [[Desktop Webview CI]].

## Referenced by

[[src/_MOC]] · [[Pudu Webview Windows Profile]] · [[Desktop Webview CI]]
