---
type: module
path: "@root/lib/Std/Yaml/Quoted.pudu"
fidelity: Active
tags: [module, stdlib, yaml]
aliases: [Std Yaml Quoted]
---
# Std Yaml Quoted
## Purpose and interface
Internal quoted scalar decoding and delimiter scanning for [[Std Yaml]]. `decode` returns
text or `Unterminated`/`Invalid` failures; the private span scanner skips one complete quoted span without
interpreting syntax inside it. A double quoted backslash protects the next character,
and adjacent single quotes represent one quote. `colon`, `comment`, and `pieces` locate
mapping separators, comments and flow commas outside those spans and nested collections.
## Algorithm
Decode the YAML single-line escape vocabulary, including x/u/U fixed-width hexadecimal
Unicode escapes. Require Unicode scalar values, reject unknown or truncated escapes,
missing closing quotes and text after a closer. Single quotes preserve backslashes.
Plain strings pass through unchanged. The caller maps failures to its physical line.
## Grill Log
- **Q:** Reuse JSON decoding? **A:** No. _Rationale:_ YAML has additional escapes and
  single quotes. _Accepted:_ one dedicated scanner shared by structure and scalar decoding.
- **Q:** Replace invalid escapes with text? **A:** No. _Accepted:_ typed refusal;
  Unicode surrogates and values above U+10FFFF cannot name characters.
## Referenced by
[[Std Yaml]] · [[src/Std/_MOC]]
