---
type: module
path: "@root/website/src/View/Packages/State.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages State]
---
# Website Package Data States

Shared native UI for package data lists. Empty results use a bordered banner with a title and
explanation. A next-page control includes a hidden live loading status that the scroll enhancement
shows during a request. Populated lists retain their content while more rows load.

See [[architecture/PACKAGES]] · [[website View Packages Catalog]] · [[website Package Discussion]].

## Grill Log

- **Q:** Replace the page with a spinner while more results load? **A:** No; keep the loaded rows
  visible and put the loading status beside the next-page action. _Rationale:_ readers can keep
  reading while the next bounded request is pending.

Resolved Grill Log: every list has an accessible empty, loading, or loaded presentation, and a
normal next-page link remains available without script.
