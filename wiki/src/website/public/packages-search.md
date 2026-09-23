---
type: script
path: "@root/website/public/assets/packages/search.js"
fidelity: Active
tags: [website, packages, search, accessibility]
aliases: [Package live search]
---
# Package live search

Enhances every package search form (`[data-package-search]`) with a suggestion box read from
`GET /packages/suggest` ([[website View Packages Suggest]]). Without the script each form is an
ordinary GET form to `/packages/search`, which ranks with the same service.

## Layers

Each file is one concern; a lower layer never imports a higher one.

| File | Layer | Holds |
| --- | --- | --- |
| `search/constants.js` | constants | debounce delay, endpoint, messages, class names |
| `search/text.js` | pure text | where a query occurs in a text, for highlighting |
| `search/place.js` | layout | pins a fixed panel under its anchor inside the viewport |
| `search/client.js` | network | one in-flight request per box; an older answer never replaces a newer one |
| `search/view.js` | view | builds rows as DOM nodes from the JSON, inserting every value as text |
| `search/box.js` | feature | one form's state: selection, filter chip, open and closed, keys |
| `search.js` | composition root | binds every form and the page-wide `/` shortcut |

## Behaviour

The input is an ARIA combobox that owns a listbox of labelled groups (owners, projects, package
declarations, standard library); the selected row is its active descendant, so focus stays in the field. No row is
selected until the reader moves the selection, and typing clears it, so keys never act on a row the
reader did not choose or on results from an earlier query. Each row highlights its match. The box
and the help panel are fixed-position and placed under their anchor by `place.js`, because page
banners clip their overflow. A footer links to the full results page when the page holds more than the box shows.

| Key | Effect |
| --- | --- |
| Up / Down | move the selection, wrapping |
| Enter | open the selected row, or submit the form when none is selected |
| Right Arrow on a selected project, with the caret at the end | search inside that project: a chip replaces the query |
| Backspace in an empty field | remove the chip |
| Escape | close the box |
| `/` outside a text field | focus the page's first package search field |

A project page's box is fixed to its project (`data-filter-fixed`): it shows no chip and the filter
cannot be removed. With a filter and an empty field, focusing the field lists that project's
declarations. Loading, empty, and error states are announced through a polite status region; an
error leaves Enter submitting the form.

## Grill Log

- **Q:** Keep parsing the rendered search page? **A:** No. _Rationale:_ it parsed a full document per
  keystroke and broke whenever page markup changed; the JSON endpoint states the contract.
- **Q:** Trap focus like a modal? **A:** No. _Rationale:_ a suggestion box keeps focus in the field
  and uses the combobox pattern so screen readers follow the selection.
- **Q:** Build rows with `innerHTML`? **A:** No. _Rationale:_ every value is package-author text; rows
  are built from nodes and text only.
- **Q:** Take over Tab? **A:** No. _Rationale:_ Tab must always leave the field.
- **Q:** Select the first row automatically? **A:** No. _Rationale:_ Enter would open a row the
  reader never chose, and Right Arrow could not move the caret while editing.

Resolved Grill Log: the enhancement is optional, each request is bounded by the service, stale
answers are discarded, and failure leaves form submission available.
