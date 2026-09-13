---
type: module
path: "@root/lib/Std/Xml.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, xml]
aliases: [Std Xml]
---
# Std Xml
## Purpose
Read and write the XML that envelopes, assertions, feeds, and configuration files are made of:
elements, attributes, text, CDATA, comments, the declaration, the five defined entities, and numeric
character references.
## Interface
Exports `Node` (`Element` or `Content`), `Tag` (name, ordered attributes, children), and `XmlError`;
`decode`; lookup through `attribute`, `elements`, `children`, `child`, `path`, `text`, and
`descendants`; name helpers `localName` and `prefixOf`; construction through `element`,
`withAttribute`, `withChild`, and `withText`; `escape`, `encode`, `render`; and `explain`.
## Governance and algorithm
The reader takes the document's characters once as an array and descends element by element,
dropping comments and processing instructions and holding CDATA exactly as written. Layout-only
whitespace between elements is not content. Namespace prefixes are kept as written rather than
resolved. It reads rather than validates: a document type declaration is refused, because declared
entities are how a document expands to gigabytes or reaches a file on the machine.

Nesting is bounded. Each open element costs a reader recursion and the evaluator bounds call depth,
so an element that would open more than 512 levels deep answers `TooDeep` at the position of its `<`
instead of stopping the program.
## Grill Log
- **Q:** Resolve namespace prefixes against their declarations? **A:** No. _Rationale:_ a reader of
  one endpoint knows its prefixes, and resolution would refuse documents that declare imperfectly.
  _Accepted:_ names as written plus `localName`.
- **Q:** Skip a document type declaration? **A:** No. _Rationale:_ its entities change what the
  document means, and expanding them is the classic amplification and file-disclosure attack.
  _Rejected:_ silently skipping it.
- **Q:** Let element nesting recurse until the evaluator's call limit? **A:** No. _Rationale:_ that
  limit stops the whole program, and deeply nested markup is ordinary hostile input. _Accepted:_ a
  512-level bound answered as `TooDeep`.
## Referenced by
[[src/Std/_MOC]] · [[architecture/STDLIB]]
