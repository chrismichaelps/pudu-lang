---
type: module
path: "@root/website/src/View/Releases.pudu"
fidelity: Active
tags: [website, view, releases]
aliases: [website View Releases]
---
# Website Releases View

Renders the current release's published notes below the shared page banner, with its version, publication date, pre-release state, download action, and canonical GitHub link. Notes pass through [[website View Markdown]].

## Grill Log

- **Q:** Rewrite release notes for this page? **A:** No; render the published notes. _Rationale:_ readers should see the release record that accompanied the archive.

Resolved Grill Log: the page banner introduces the archive history; the release card owns version-specific facts.
