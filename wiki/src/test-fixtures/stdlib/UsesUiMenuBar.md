---
type: module
path: "@root/test-fixtures/stdlib/UsesUiMenuBar.pudu"
fidelity: Active
tags: [module, fixture, ui, menus]
aliases: [Uses Ui Menu Bar]
---

# Uses Ui Menu Bar

## Purpose

Reach `Menu.native` and the menu-bar exports of [[Std Ui Desktop]]. Without a window: records for a
bar with a separator, a submenu, bound and unbound commands, and titles holding tabs; `mod` resolved
to `cmd`; `menu` records decoded as `Chosen` signals, and malformed ones skipped; and a forged session
refused by `install` and `installed`. With `PUDU_DESKTOP_DRIVE=1` a real window installs the bar and
the platform's report must equal `Menu.native`'s records.

## Grill Log

- **Q:** Choose a menu item in the live run? **A:** No. _Rationale:_ choosing needs either a person
  or assistive access to press the item; the path from choice to `Chosen` is the record the pure
  decoder is tested on. _Accepted:_ the live run proves the installed bar.

## Referenced by

[[Std Ui Menu]] · [[Std Ui Desktop]] · [[Pudu Desktop Menu]] · [[Eval Service Spec]]
