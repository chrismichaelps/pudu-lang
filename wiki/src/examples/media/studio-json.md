---
type: data
path: "@root/examples/media/studio.json"
fidelity: Active
tags: [example, configuration, json, media]
aliases: [Media Studio Example Configuration]
---

# Media Studio Example Configuration

## Purpose and interface

Provide a checked, human-editable workload for the Media Studio. It exercises every current
configuration field while retaining a short real-window run suitable for developer verification.
The file is passed with `--config examples/media/studio.json`.

## Negative logic

- This is not a deployment configuration or a benchmark baseline.
- It contains no machine-specific absolute path and cannot select external programs or libraries.

## Grill Log

- **Q:** Use maximum admitted values? **A:** No. _Rationale:_ that would turn the normal device smoke
  into a long stress run. _Accepted:_ representative values; separate performance presets can be
  added with recorded hardware and percentile criteria.

## Referenced by

[[Media Studio Configuration]] · [[Media Studio Example]]
