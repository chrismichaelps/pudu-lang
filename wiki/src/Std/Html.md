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
`escapeScalar`, `isHandler`, and `isVoidElement` expose the core renderer's authoritative
scalar escaping and syntax/safety predicates to [[Std Html Bounded]].
`whenBuilt(condition, builder: fn() -> Html)` is the deferred counterpart to eager `when`: false
returns an empty fragment without invoking the callback, while true invokes it exactly once and
returns the typed view it built.
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
- **Q:** Change eager `when` to accept a callback? **A:** No; that would break existing callers and
  change evaluation timing. `whenBuilt` is separately named and additive.
- **Q:** Invoke a false callback and discard its result? **A:** No; the entire point is to avoid
  constructing optional work. False returns `Fragment([])` before the callback is called.
- **Q:** Call a true callback more than once to inspect or copy it? **A:** No; it is invoked exactly
  once and its typed `Html` result is returned unchanged.
## Referenced by
[[src/Std/_MOC]] · [[Std Ui]] · [[Std Http Server Reply]] · [[architecture/STDLIB]] ·
[[2026-09-20-bounded-ssr-slots]] · [[2026-09-20-deferred-html-builders]]

## Fragment rendering

`renderChunks` collects rendered text fragments in document order; render joins them once.
An explicit cursor-frame stack appends opening, child fragments and closing markup to one persistent
array instead of recursing once per element or materializing each child subtree. The active child
collection and its next index stay in local cursor state. Descending suspends only that parent cursor,
and returning uses the array's constant-time `pop`; traversal never slices the pending stack and
never schedules all siblings eagerly. `document` seeds the writer with the `<!DOCTYPE html>\n`
prefix before joining. [[Std Html Build]] prepends its distinct compact `<!DOCTYPE html>` fragment
to `renderChunks` before the one final join, avoiding a second copy of the materialized body.

`renderChunks` retains its existing fragment boundaries: opening tag, each accepted formatted
attribute, opening terminator, text/trusted content, and closing tag remain separate chunks. The
current public surface exposes those chunks to SSR preparation, so coalescing them here would be an
API change and belongs in the opt-in plan compaction work rather than this renderer. Attribute
formatting therefore continues to produce one fragment per accepted attribute; the scheduling and
document-prefix changes are the measured optimization in this slice.

`escape(content)` delegates directly to the native `content.escapeHtml()` builder-backed built-in,
eliminating intermediate string loops and replacements. Attribute rendering, escaping, void-element
syntax and trusted markup behavior are unchanged. This is buffered rendering, not socket streaming;
view depth no longer consumes evaluator call frames.

[[Std Html Bounded]] uses the same cursor-frame traversal and serialization rules. It counts UTF-8
width from each scalar before retaining output and expands text one escaped scalar at a time, so a
rejected large text or trusted node stops without encoding or escaping its complete output. Element
names, ordered accepted attributes, attribute values, terminators, and closing tags pass through the
same incremental budget admission; handler attributes remain omitted. Successful bounded output
joins to exactly the same bytes as `render`, but its internal fragment grouping is not the public
`renderChunks` grouping contract.

The pre-change no-optimization baseline used a focused program with depth 1,600, width 1,200, and
40 attributes. `pudu explain` reported 358,532 evaluator steps; the host RTS reported
2,336,078,616 allocated bytes, 3,868,920 bytes maximum residency, and 0.855 seconds elapsed. The
cursor traversal reported 312,954 steps, 1,994,412,360 allocated bytes, 3,398,968 bytes maximum
residency, and 0.644 seconds elapsed: reductions of 12.7%, 14.6%, 12.1%, and 24.7% respectively.
These figures are a local same-build comparison point, not portable performance guarantees.

Resolved Grill Log:
- **Q:** Keep the existing serialized output while removing repeated subtree joins? **A:** Yes; expose fragments for SSR composition without promising bounded-memory transport.
- **Q:** Why delegate `escape` to `content.escapeHtml()`? **A:** Pudu's native string `escapeHtml()` uses a builder fast path in Haskell that skips unescaped text in blocks, avoiding repeated string scans, regexes, or five sequential `.replace()` calls in Pudu script.
- **Q:** Why stream attributes directly into the chunk array with `appendAttributes`? **A:** Every HTML element previously allocated a separate `pieces: Array[Str]`, formatted attributes into it, and called `.join("")` to create an intermediate attribute string. Appending directly to the document chunk stream removes two allocations and one string concatenation per element.
- **Q:** Keep recursive traversal because ordinary pages are shallow? **A:** No. Page depth can come from program data, and a renderer must not stop the application merely because a valid value is deeply nested. An explicit work stack preserves exact output order without consuming one evaluator frame per node. _Rejected:_ a documentation-only nesting limit; catching the evaluator failure after it occurs.
- **Q:** Coalesce public chunks to reduce the fragment count? **A:** No in this slice. _Rationale:_
  `renderChunks` is consumed as a prepared SSR boundary, and changing its grouping would mix an
  observable API decision into an internal scheduling repair. _Rejected:_ silently joining opening
  syntax or text runs; duplicating traversal for `render` and `renderChunks`.
- **Q:** Keep slicing the pending stack because the sequence shares structure? **A:** No. _Rationale:_
  the runtime confirms slicing is logarithmic while `pop` is constant time, and cursor frames also
  bound scheduled sibling work. _Rejected:_ claiming a full-array copy; retaining repeated slices.
- **Q:** Count a text node after calling `escapeHtml()`? **A:** No for bounded rendering. A single
  refused node could already have traversed and allocated its full escaped output. The bounded writer
  admits each scalar or fixed escape expansion before retaining it and stops at the first overflow.
- **Q:** Convert a complete trusted string to `Bytes` merely to count it? **A:** No; scalar UTF-8
  width is counted incrementally, so rejection does not allocate a complete encoded copy of caller-
  supplied trusted markup.
- **Q:** Change `renderChunks` fragment boundaries to share the bounded implementation? **A:** No;
  those boundaries are public and consumed by preparation. `Std.Html.Bounded.render` is additive
  and promises output and exact length, not identical chunk grouping.
