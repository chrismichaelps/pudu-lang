---
type: module
path: "@root/test-fixtures/stdlib/UsesYamlQuoted.pudu"
fidelity: Active
tags: [module, fixture, yaml]
aliases: [Uses Yaml Quoted]
---
# Uses Yaml Quoted
## Purpose and interface
`main` returns zero after exact decoded text, quoted key, flow delimiter and comment
assertions, including every single-line YAML escape and doubled single quotes. Failure
assertions require the exact physical line for unknown, truncated, invalid Unicode,
unterminated and trailing-content errors. Plain and quoted numeric kinds remain distinct.
## Grill Log
- **Q:** Test only successful parsing? **A:** No. _Accepted:_ full decoded trees and
  typed line-specific refusal, since this defect silently returned wrong text.
## Referenced by
[[Std Yaml]] · [[Protocol Evaluation Spec]]
