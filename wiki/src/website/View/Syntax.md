---
type: module
path: "@root/website/src/View/Syntax.pudu"
fidelity: Active
tags: [website, view, documentation, highlighting]
aliases: [website View Syntax]
---
# Website View Syntax

Paints a fenced code block on the server, so a prerendered page is coloured before any script runs.
`painted(language, text)` answers the nodes for `pudu`, and for `sh`, `shell`, `bash`, and
`console`. Any other language answers `None`, and the block stays plain text.

**Pudu** is painted exactly as the playground's `text/syntax.js` paints it, with the same `tok-<kind>`
classes and so the same colours: `keyword`, `literal` (`true`, `false`, `null`), `number` (with base
prefixes, `_` separators, exponents, and width suffixes), `string` (and character literals), `escape`
and `interpolation` inside a string, `comment` (`//` and nested `/* */`), `doc` (`///`), `type` (a
capitalised word), `constant` (an all-capitals word of two or more characters), `function` (a word
before `(`), `label` (`@name`), and `operator`. A string and a comment end at the end of a line.

**Shell** paints `#` comments (at a line's start or after a space), quoted text as `string`, `$NAME`
and `${…}` as `interpolation`, options (`-x`, `--name=value`) as `type`, the command word that starts a
command (a line's first word, or the first after `|`, `||`, `&&`, `;`, or `(`) as `function`, and `|`,
`||`, `&&`, `;`, `>`, `>>`, `<`, and `&` as `operator`.

Every run becomes a text node or a `span` holding one, through `Std.Html.Build`, so nothing a block
says can become markup.

See [[website View Markdown]] · [[website stylesheet]].

## Grill Log

- **Q:** Paint in the browser with the playground's script? **A:** On the server. _Rationale:_ pages
  are prerendered and must read the same without script, and painting after load would flash plain
  code first. _Rejected:_ loading `syntax.js` on every documentation page.
- **Q:** How do two painters stay the same? **A:** `website/test/fixtures/syntax.json` holds inputs
  with the HTML `syntax.js` produces; [[website Markdown suite]] checks this painter against it and
  `website/scripts/syntax-parity.test.mjs` checks the playground's, so a change to either fails
  until the fixture is updated deliberately.
- **Q:** Why not reuse [[website View Packages Highlight]]? **A:** It colours package source with
  its own palette and fewer kinds; the documentation promises the playground's look.
