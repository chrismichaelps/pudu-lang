---
type: module
path: "@root/test/sum-owners.mjs"
fidelity: Active
grammar: "[[grammar/pudu]]"
tags: [module, test, runtime, nominal]
aliases: [Sum Owner Gate]
---
# Sum Owner Gate

`node test/sum-owners.mjs <optimized-compiler>` checks same-named sums and variants across
modules in both evaluators and import orders. Direct/generic/retained calls and folded constants
retain defining owners and captures, including cold/warm product reuse. Custom Ok/Err-labelled
async results stay intact. Native/source JSON node equality and variant display remain stable.
Wrong receiver types retain a positioned diagnostic. Scratch programs use subprocess deadlines
and are removed after every outcome.

Resolved Grill Log: assert observable output and independent type refusal; do not assert a private
owner encoding. Keep #761 open for named payloads and remaining evidence audits.

## Referenced by

[[src/_MOC]] · [[Positional Sum Owner Delivery]] · [[Eval Value]]

The gate also checks unequal dynamic-erased values from distinct module declarations. Resolved Grill Log: erased static views do not erase runtime identity.
