---
type: module
path: "@root/lib/Std/Yaml/Block.pudu"
fidelity: Active
tags: [module, stdlib, yaml]
aliases: [Std Yaml Block]
---
# Std Yaml Block
## Purpose and interface
Internal physical-line retention and block scalar decoding for [[Std Yaml]]. `Line` retains
indentation, content, physical number, scalar membership and newline termination. `lines`
returns structural lines plus untouched scalar content or a tab/bad-indentation problem at its physical line.
`marker` recognizes literal/folded clip/strip/keep markers; `scalar` consumes scalar lines
and returns decoded text and the next structural position. Invalid starting positions are
clamped to the retained line range and return empty text; unsupported headers also return
empty text without consuming lines.
## Algorithm
Normalize CRLF. Detect scalar headers after comment removal and quote-aware key scanning,
including direct list scalars and compact list mappings. Retain blank lines while a scalar
is open, even when unindented, and do not interpret content hashes or document separators.
The first nonblank content line establishes indentation; preserve relative indentation and
trailing spaces. Leading all-space lines cannot exceed the first nonblank content indentation;
otherwise return BadIndent at the first offending blank line. Literal scalars preserve each physical newline. Folded scalars replace
ordinary adjacent text line breaks with spaces, preserve paragraph boundaries and breaks
around more-indented lines. Strip removes trailing breaks, clip keeps at most one, keep
retains every break. An EOF without a newline does not invent one.
## Grill Log
- **Q:** Can a list scalar consume the next list item? **A:** No. _Accepted:_ explicit
  scalar membership ends at the owning indentation, independent of subsequent parsing.
- **Q:** Are blank and comment-like lines syntax in a scalar? **A:** No. _Accepted:_ raw
  content and physical breaks remain data until folding and chomping are applied.
## Referenced by
[[Std Yaml]] · [[src/Std/_MOC]]
