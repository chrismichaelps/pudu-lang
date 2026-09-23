---
type: script
path: "@root/website/public/assets/packages/avatars.js"
fidelity: Active
tags: [website, packages, asset]
aliases: [Package avatar fallback]
---
# Package Avatar Fallback

Keeps the owner's two-tone mark beneath GitHub profile images. If the image fails to load, the
enhancement removes the failed image so the mark is fully visible. Suggestion rows built by
[[Package live search]] remove a failed image the same way when they create it. It handles
images that failed before the module ran and does not fetch or replace account imagery itself.

See [[website View Packages Frame]] · [[website Package List Pagination]].

## Grill Log

- **Q:** Use a generated picture for an unavailable profile image? **A:** No; the owner's mark is a
  two-tone square from the logo's letter pairs with no initials or illustration. _Rationale:_ the
  fallback should not suggest an invented identity, only a stable colour for the owner.

Resolved Grill Log: a successful local or GitHub-hosted avatar covers the placeholder; a failed
image reveals the placeholder without leaving a broken-image glyph.
