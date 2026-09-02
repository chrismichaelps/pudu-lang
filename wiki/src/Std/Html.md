---
type: module
path: "@root/lib/Std/Html.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, html, view, rendering]
aliases: [Std Html]
---
# Std Html
## Purpose
A page as a value, so that placing text in one cannot place markup in one.
## Interface
A view: an element with a name, attributes, and children; text; a list of views with no element
around them; and a passage the caller has taken responsibility for. Constructors for the elements a
page is mostly made of, and a general one for the rest. Attributes, including the two whose values
are lists — classes and inline style — built rather than spelled. Rendering a view to markup, and
rendering a whole document with its declaration. Escaping text and an attribute value, exported
because a program building markup this module does not cover still needs them.
## Governance and algorithm
Text is text and markup is markup, and the only way to obtain markup is to build a node. That is
the whole design. A template language has to solve escaping repeatedly — and gets it wrong at each
new context — because it lets a string become markup by being interpolated. Here a string cannot
become markup at all, so the failure has no way to occur rather than being prevented by a rule
someone has to remember at every call site.

The one deliberate exception is named so that it cannot be used by accident and cannot be missed in
review: a caller who genuinely has markup — output from a document converter, a fragment from
elsewhere — says so, and the word appears in the source. An escape hatch that is easy to reach is
the same as no escaping; one that must be named is a decision somebody made.

Escaping covers the ampersand first, since escaping it after the others would escape the escapes.
An attribute value escapes both kinds of quote, because which one surrounds a value is not something
the value can know. A void element is written without a closing tag, from a table of the elements
that have none rather than from a rule about their names, because there is no such rule.

A view is inert. Rendering is the only thing that produces text, and it reads nothing outside the
value it was given — so two renders of equal views are equal, and a page can be compared in a test
rather than matched against a pattern.
## Grill Log
- **Q:** Provide interpolation into a markup string? **A:** No. _Rationale:_ that is the mechanism
  every injection failure comes through, and adding it would make escaping a rule to remember
  instead of a property of the type. _Rejected:_ a template string with holes.
- **Q:** Escape on construction rather than on render? **A:** No. _Rationale:_ a view would then
  hold text already transformed, so a view could not be compared against the text it was built
  from, and escaping twice would be possible. _Rejected:_ escaping in the constructor.
- **Q:** Let attributes be an arbitrary map? **A:** They are pairs, ordered. _Rationale:_ order is
  what makes rendering deterministic, and a page that renders differently between runs cannot be
  compared in a test. _Rejected:_ an unordered attribute map.
- **Q:** Validate that an element's children are permitted inside it? **A:** No. _Rationale:_ that
  is a large table which is wrong at the edges and goes stale, and the failure it prevents is a
  page that renders oddly rather than one that is unsafe. _Rejected:_ a content model.
## Referenced by
[[src/Std/_MOC]] · [[Std Ui]] · [[Std Http Server Reply]] · [[architecture/STDLIB]]
