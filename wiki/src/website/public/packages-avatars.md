---
type: script
path: "@root/website/public/assets/packages/avatars.js"
fidelity: Active
tags: [website, packages, asset]
aliases: [Package avatar fallback]
---
# Package Avatar Fallback

Keeps the geometric account silhouette beneath GitHub profile images. If the image fails to load,
the enhancement removes the failed image so the neutral silhouette is fully visible. It handles
images that failed before the module ran and does not fetch or replace account imagery itself.

See [[website View Packages Frame]] · [[website Package List Pagination]].

## Grill Log

- **Q:** Use a generated picture for an unavailable profile image? **A:** No; keep a neutral account
  silhouette. _Rationale:_ the fallback should not suggest an invented identity.

Resolved Grill Log: a successful local or GitHub-hosted avatar covers the placeholder; a failed
image reveals the placeholder without leaving a broken-image glyph.
