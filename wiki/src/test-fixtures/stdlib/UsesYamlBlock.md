---
type: module
path: "@root/test-fixtures/stdlib/UsesYamlBlock.pudu"
fidelity: Active
tags: [module, fixture, yaml]
aliases: [Uses Yaml Block]
---
# Uses Yaml Block
## Purpose and interface
`main` returns zero after complete YAML trees for first-key compact mapping scalars,
list siblings, nested sibling keys, blank lines, comment/document-like content, relative
indentation, trailing spaces, literal/folded paragraphs, clip/strip/keep and EOF behavior.
Includes CRLF, empty blocks, exact tab/bad-indent refusals and helper negative/past-end
positions and unsupported headers; mismatch panics.
## Grill Log
- **Q:** Is scalar projection enough? **A:** No. _Accepted:_ compare complete decoded
  trees so a correct string cannot hide a dropped sibling or list item.
## Referenced by
[[Std Yaml]] · [[Protocol Evaluation Spec]]
