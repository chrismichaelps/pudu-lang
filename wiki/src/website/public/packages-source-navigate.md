---
type: script
path: "@root/website/public/assets/packages/source/navigate.js"
fidelity: Active
tags: [website, packages, source, asset]
aliases: [Package source navigation]
---
# Package Source Navigation

Opens a file in the Source tab without reloading the page. A click on a file-tree link or a path
crumb fetches that file's page, replaces only the file pane (`[data-code-main]`), moves the tree's
current mark, updates the title, and pushes the address; Back and Forward restore the file the same
way. The banner, tabs, tree, filter, and the tree's scroll position stay as they were, so choosing a
file no longer flashes the page.

Hovering or focusing a link starts its request early, and a small cache holds recent answers, so a
chosen file usually appears at once. The pane is marked busy only while a request is outstanding;
the stylesheet fades it after a short delay, so a fast answer shows no loading state. Copy buttons in
the new pane are bound again.

A modified click (new tab or window), a link outside the source tab, a response that is not a page
with a file pane, or any network failure falls back to ordinary navigation to the same address, so
every file keeps its canonical, server-rendered page.

See [[website View Packages Source]] · [[Package install controls]].

## Grill Log

- **Q:** Render files in the browser from raw text? **A:** No; fetch the server-rendered page and take
  its pane. _Rationale:_ highlighting, Markdown, binary previews, and the outline stay in one place.
- **Q:** Use a cross-document view transition alone? **A:** No. _Rationale:_ it still reloads the
  banner, tree, and scripts, and its support varies; replacing the pane removes the reload.

Resolved Grill Log: navigation stays same-origin and inside the project's source paths, falls back to
a full page load on any doubt, and keeps the address bar canonical.
