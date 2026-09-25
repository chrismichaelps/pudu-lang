---
type: handoff
status: ACTIVE
issue: 322
tags: [handoff, stdlib, ui, desktop, application]
---

# Desktop Toolkit and Application Framework

## Objective and ownership

Issues #321, #322, and #323 fill standard-library gaps by dependency layer: core modules first
([[Std Cron]], [[Std Stats]], [[Std Dotenv]], [[Std Term]]), then the application framework
([[Std App Problem]], [[Std App Page]], [[Std App Idempotency]], [[Std App Events]],
[[Std App OpenApi]], calendar jobs in [[Std App Work]]), then the desktop toolkit over live input
([[Std Ui Desktop]], [[Std Ui Theme]], [[Std Ui Motion]], [[Std Ui History]], [[Std Ui Virtual]],
[[Std Ui Keymap]], [[Std Ui Controls]], [[Std Ui Navigation]], [[Std Ui Preferences]],
[[Std Ui Menu]], [[Std Ui Gesture]], [[Std Ui Clipboard]]).

Roles: **Standard Library Engineer** for the Pudu modules and fixtures; **Runtime Engineer** for the
desktop adapter and effect primitives ([[Pudu Desktop Adapter]], [[Eval Desktop]]). Review is a
separate pass over source and mirror parity before each merge.

## State

- #321 and #323 are merged and closed. #322 lands through #326, #328, and #329, stacked in that order.
- [[architecture/WEB]] lists every application capability with its joint into `Std.App`;
  [[architecture/NATIVE-UI]] lists every desktop concept with its module and status.

## Validation evidence

- Each partition passed `cabal test all`, `pudu fmt --check`, `pudu lint`, and the API coverage gate
  with no undocumented export; the runtime type-checked under `-Werror` with the macOS flags undefined.
- Live macOS probes: a real window drained input through `desktopInputs`; clipboard text written was
  read back and the previous contents restored.

## Operational note

`pudu check` resolves `Std.*` from the compiler's library root before a worktree's own tree, so a
module changed in another checkout reads stale. Set `PUDU_LIB=<checkout>/packages/pudu/v0.1/lib`.

## Remaining desktop gaps

Grids, list selection, stroked paths and gradients, magnify and rotate gestures, drag and drop
between applications, the native menu bar, export to the platform accessibility tree, text shaping
and input methods, and document and settings spaces.

## Exact next action

Add list selection to [[Std Ui Virtual]]: a `Selection` value (anchor, focus, set) with
single, range, and toggle updates driven by `Screen` events and `Keymap` chords, then mark the row
**Ready** in [[architecture/NATIVE-UI]].

## Referenced by

[[handoffs/_MOC]]
