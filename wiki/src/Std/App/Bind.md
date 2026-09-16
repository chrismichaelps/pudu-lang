---
type: module
path: "@root/lib/Std/App/Bind.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, binding, requests]
aliases: [Std App Bind]
---
# Std App Bind
## Purpose
Turn what a request carries into a typed value, and refuse it in a way the sender can act on.
## Interface
Where a field may be read from: the path, the query, a form body, or a JSON body. Reading the fields
a request carries, from one place or from several. Checking them against rules and reading the
values out. The refusal a failed binding becomes, as a response. Reading one bound field as text, a
whole number, a count, or a truth.
## Governance and algorithm
**Where a value came from is stated, not searched for.** A binding that looks in the path, then the
query, then the body, and takes the first hit lets a caller move a value between places to reach a
different code path — and it makes a handler's behaviour depend on an order nobody wrote down. Each
field says where it is read from.

**Checking and reading are one step, and every failure is reported.** The rules come from
[[Std Validate]], so a form's rules are the same value wherever they are used and the refusal names
every field that was wrong rather than the first. A caller correcting a request wants the whole
list.

**A refusal is a status and a list of fields, and it names no values.** What was submitted is not
echoed back — the sender knows what they sent, and echoing it is how a response becomes a place
something they sent gets rendered. The status distinguishes a request whose shape was wrong from one
whose shape was right and whose contents were not, because those are different problems for whoever
sent it.

**A body is read as what its type says it is.** A form and a document are different formats, and
guessing between them by looking at the first character is how a body of one type is read as the
other. A request that states no type has its body read as none rather than as a guess.

**Nothing here reaches a handler.** Binding answers a value or a refusal; what a handler does with
either is the handler's. That keeps this checkable without a request having been served.
## Grill Log
- **Q:** Search several places for a field and take the first found? **A:** No. _Rationale:_ it lets
  a caller move a value to reach a different path, and makes behaviour depend on a precedence nobody
  wrote. _Rejected:_ an implicit search order.
- **Q:** Guess the body format from its first character? **A:** No. _Rationale:_ that is how a form
  is read as a document, and the request already says which it is. _Rejected:_ sniffing the body.
- **Q:** Report the first failure, since the request is already unusable? **A:** No — the same
  reasoning as [[Std Validate]]: the person fixing it wants the whole list. _Rejected:_
  short-circuiting.
- **Q:** Include the submitted value in the refusal so the sender can see what arrived? **A:** No.
  _Rationale:_ they know what they sent, and a response is a place values get rendered.
  _Rejected:_ echoing the input.
## Referenced by
[[src/Std/_MOC]] · [[Std Validate]] · [[Std Http Server Route]] · [[Std Http Server Reply]] · [[architecture/WEB]]
