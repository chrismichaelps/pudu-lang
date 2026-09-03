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
**Escaping text is half of it, and the established engines stop there.** A destination is the other
half: `href="javascript:…"` contains no character escaping touches, and it runs. So a destination is
its own type, obtained only through a call that checked it, and an attribute whose value would be a
program cannot be written — no escaping makes a program safe, so there is nothing to escape it into.
The permitted schemes are a stated set rather than a list of refusals, because the refusals are the
ones somebody thought of and the permissions are the ones that work.

**A layout is a function, not an inheritance rule.** A page inside a shell is `shell(page)`, and a
piece reused across pages is a function returning a view. Template engines grow inheritance,
fragments, and inclusion because their templates are files rather than values; here those are what
functions already are, and they compose without a second mechanism to learn.

## Grill Log
- **Q:** Is escaping text enough? **A:** No, and believing so is where the established engines leave
  a hole. _Rationale:_ a script destination and an event-handler attribute both survive escaping
  untouched, because neither contains a character escaping acts on. A page builder that escapes text
  and takes any string as a destination has closed one door and left the other open. _Rejected:_
  escaping alone; escaping destinations, which does nothing to them.
- **Q:** List the schemes that are refused? **A:** No; state the ones permitted. _Rationale:_ a list
  of refusals covers what somebody thought of, and the next scheme is admitted by default.
  _Rejected:_ a deny list.
- **Q:** Escape an event-handler attribute rather than refusing it? **A:** No. _Rationale:_ its value
  is a program, and no escaping makes a program safe. A page needing behaviour attaches it from a
  script the page loaded. _Rejected:_ escaping handlers; permitting them with a warning.
- **Q:** Add template inheritance and fragments? **A:** No; a layout is a function. _Rationale:_
  those mechanisms exist because templates are files. Views are values, and a function over a value
  already composes. _Rejected:_ an inheritance mechanism.
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
