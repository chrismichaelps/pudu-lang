---
type: script
path: "@root/website/public/assets/packages/avatars.js"
fidelity: Active
tags: [website, packages, asset]
aliases: [Package avatar fallback]
---
# Package Avatar Fallback

Keeps the owner's two-tone mark beneath GitHub profile images. While an image is present the mark's
artwork is hidden (a neutral square shows as it loads), so a slow image never flashes the mark first;
removing a failed image brings the mark back through `:has`. If the image fails to load, the
enhancement removes the failed image so the mark is fully visible. Suggestion rows built by
[[Package live search]] remove a failed image the same way when they create it. It handles
images that failed before the module ran and does not fetch or replace account imagery itself.

See [[website View Packages Frame]] · [[website Package List Pagination]].

## Grill Log

- **Q:** Use a generated picture for an unavailable profile image? **A:** No; the owner's mark is a
  two-tone square from the logo's letter pairs with no initials or illustration. _Rationale:_ the
  fallback should not suggest an invented identity, only a stable colour for the owner.

- **Q:** Why did the mark flash before the image? **A:** The banner image was lazy though always on
  screen, `/packages/avatars/` was revalidated on every view, and the mark painted beneath it.
  _Resolution:_ banner and profile avatars load eagerly with high priority, avatars are cached for a
  day, and the mark shows only without an image (#310).

Resolved Grill Log: a successful local or GitHub-hosted avatar covers the placeholder; a failed
image reveals the placeholder without leaving a broken-image glyph.
