---
type: module
path: "@root/website/src/Domain/Playground.pudu"
fidelity: Active
tags: [website, playground, domain]
aliases: [website Domain Playground]
---
# Website Playground Domain

The playground's vocabulary: an `Action` (run or format), an accepted `Submission`, the `Limits` a run may cost, the `Outcome` a run ends with, and the `Question`/`Answer` pair an editor exchanges with the language server. `accept` normalises line breaks, bounds the size, and reads the module name through the module grammar so nothing but a module path can reach the file system. `headline` says how a run ended; `failureOf` tells a program that did not compile from one the evaluator stopped by the leading digit of the first diagnostic code (`E7…` is the evaluator's).

Resolved Grill Log: a program's own status is reported only when no diagnostic explains it; a question about a program that does not yet declare its module is still answered, written as `Main`.
