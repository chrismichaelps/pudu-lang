---
type: handoff
status: IN_REVIEW
issue: 678
aliases: [Lambda Option Try Delivery]
tags: [handoff, delivery, types]
---
# Lambda Option Try Delivery

Fresh feature/678-lambda-option-try from development b230a5d6, found while writing an engine
system as a short lambda. Role transitions: Type Engineer → Test Engineer → independent Language
Architect and Forensic Guardian. `?` on an `Option` inside an unannotated lambda was refused
because the unsolved result was committed to `Result`; [[Type Check Rule]] now takes the carrier
from an operand already typed `Option`.

Evidence: the new property fails without the change (six E3001) and passes with it; Result
lambdas still check and mixed carriers are still refused; 125 type-check property labels pass;
the shipped library and examples check clean. No full gates were run locally, by request.

Exact next action: use Option-propagating lambdas for Ark systems.

## Referenced by

[[handoffs/_MOC]] · [[Type Check Rule]]
