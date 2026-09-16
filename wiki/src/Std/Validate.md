---
type: module
path: "@root/lib/Std/Validate.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, validation, forms]
aliases: [Std Validate]
---
# Std Validate
## Purpose
Say what is wrong with everything that is wrong, once.
## Interface
A field's name and what was submitted for it. A rule: what a value must be, and what to say when it
is not. The rules for text, for whole numbers, and for a choice among stated options. A rule the
program writes. Checking one field, and checking a form. What checking found, whether it found
anything, the failures for one field, and the failures as a caller receives them. Reading a checked
value out.
## Governance and algorithm
**Every failure is reported, not the first.** A person correcting a form wants the whole list; giving
them one at a time turns a single correction into as many round trips as there are mistakes, and
each round trip is a chance to give up. This is the entire reason the result is a report rather than
a `Result`, which would stop at the first.

**A failure names the field and says what was expected.** Not what was submitted — echoing a
submitted value back into a message is how a message becomes a delivery mechanism, and the sender
already knows what they sent.

**Rules are values and checking is a pure function.** So a form's rules can be listed, compared, and
reused between the place a value arrives and the place it is stored — which is the only way those
two stay in agreement. A rule written twice diverges; a rule that is a value does not.

**Order is the order written.** A field's failures come back in the order its rules were given, and
fields in the order the form declared them, so a message assembled from a report reads the way the
form does.

**Nothing here trims, coerces, or fills in.** A validator that quietly repairs its input is deciding
what the sender meant, and the sender is the only one who knows. Text that should be trimmed is
trimmed before it is checked, by something whose name says so.
## Grill Log
- **Q:** Stop at the first failure, since the value is already unusable? **A:** No. _Rationale:_ the
  value being unusable is not the point; the person fixing it is, and they want the whole list.
  _Rejected:_ short-circuiting on the first failure.
- **Q:** Include the submitted value in the failure, so the caller can see what was read? **A:** No.
  _Rationale:_ the sender knows what they sent, and echoing it is how a message carrying markup gets
  rendered somewhere that did not expect it. _Rejected:_ echoing the input.
- **Q:** Trim text before checking it? **A:** No. _Rationale:_ a validator that repairs its input is
  deciding what the sender meant. Trimming is a step with a name, taken deliberately.
  _Rejected:_ implicit normalisation.
- **Q:** Make a rule able to depend on another field? **A:** Yes, through a rule the program writes
  over the whole form, not through a reference from one field to another. _Rationale:_ a reference
  makes the order fields are checked in significant, and then a report depends on a declaration
  order nobody thought was load-bearing. _Rejected:_ cross-field references inside a field's rules.
## Referenced by
[[src/Std/_MOC]] · [[Std App]] · [[Std Http Server Reply]] · [[architecture/WEB]]
