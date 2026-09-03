---
type: module
path: "@root/lib/Std/App/Locale.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, internationalization, messages]
aliases: [Std App Locale]
---
# Std App Locale
## Purpose
Say the same thing in the language the reader asked for, and know when you cannot.
## Interface
A locale: a language and, where it matters, the place. Reading one from text, and choosing among the
ones a program has from what a request asked for. A catalogue: what a program can say, in each
language it says it. Looking a message up, with the places it falls back to. Filling the parts a
message leaves open. Choosing among a message's forms by a number. Asking a catalogue what it is
missing against the language it was written in.
## Governance and algorithm
**A message that is missing is reportable, not silent.** Every catalogue can be asked what it lacks
against the language it was written in, and the answer is a list. The ordinary arrangement — fall
back quietly to the original language — means a missing translation ships, reaches a reader, and is
found by that reader rather than by the program that shipped it. Falling back still happens, because
showing nothing is worse; what is added is that the gap can be found before it is deployed.

**A number chooses among forms by the language's own rule, not by comparing with one.** English has
two forms and a rule anybody would guess. Others have three or four, and the rule that picks them is
not "one or not one" — a translator given only a singular and a plural cannot write correct Polish,
and a program that asks for those two has decided the translator is wrong. The categories are the
ones the language actually has.

**What is asked for is a list with weights, and the best available answer wins.** A request states
several languages in order of preference. Choosing the first that happens to match ignores the
preference; choosing by weight respects what the reader said. A language with a place falls back to
the language without it before it falls back to the default, so a reader asking for one region's
Spanish gets Spanish rather than English.

**A filled message is text and stays text.** The parts a message leaves open are filled with text,
and what comes out is text — it never becomes markup. A translated string that could carry markup is
a translator, or whoever edited the catalogue, writing into every page that shows it. Putting one in
a page goes through the ordinary text node, which escapes it like anything else.
## Grill Log
- **Q:** Fall back to the original language silently, as is usual? **A:** Fall back, but make the gap
  reportable. _Rationale:_ a silent fallback means the missing translation is found by a reader
  rather than by a build, and that is the whole reason half-translated software ships.
  _Rejected:_ silence; refusing to render, which shows the reader nothing.
- **Q:** Choose a plural form by comparing the number with one? **A:** No. _Rationale:_ that is
  correct for English and wrong for most of the languages a program is translated into, and it
  quietly makes the translator's correct text impossible to write. _Rejected:_ singular and plural
  only.
- **Q:** Take the first language a request lists that is available? **A:** No; take the best by
  weight. _Rationale:_ the list is ordered preference with weights, and ignoring them answers in a
  language the reader ranked lower than one on offer. _Rejected:_ first match.
- **Q:** Let a message carry markup, so a translator can emphasise a word? **A:** No. _Rationale:_
  then whoever edits the catalogue writes into every page that shows it, and a catalogue is edited
  by people who are not reviewing code. A message names the parts left open; a page decides what
  they look like. _Rejected:_ markup in messages.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Html]] · [[Std Http]] · [[architecture/WEB]]
