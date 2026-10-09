---
type: module
path: "@root/packages/pudu/v0.1/lib/Std/Db/Admission.pudu"
fidelity: Active
tags: [module, database, admission]
aliases: [Std Db Admission]
---
# Std Db Admission

## Purpose and interface

Own the bounded capacity wait policy below pool ownership. `DEFAULT_WAIT_MILLISECONDS` is 10000; `validWait` accepts 0 through 3600000. `takeWithin` consumes one `Channel[Option[Session.Connection]]` slot or returns a typed failure.

## Algorithm and invariants

Validate before touching the channel. Delegate atomic selection to [[Std Channel]]. Received optional slots retain both present and empty replacement states; Finished becomes Closed; TimedOut becomes AdmissionTimedOut. Channel failures retain their rendered cause as Other. Expiry changes no slot or connection, and performs no reopening or callback. Zero is an immediate probe. The upper bound is a configurable capacity policy, not a work deadline.

## Resolved Grill Log

- **Q:** Interrupt a borrower after dequeue? **A:** No; atomic channel selection transfers ownership exactly once.
- **Q:** Conflate an empty replacement slot with a closed channel? **A:** No; an admitted empty slot is still capacity.
- **Q:** Accept an unlimited or invalid wait? **A:** No; configuration is finite and validated before state access.

## Linkage

Requires [[Std Channel]] and [[Std Db Session]]. Consumed by [[Std Db]] and [[Std Db Postgres]]. Layer five precedes pool ownership at layer six.

## Referenced by

[[src/Std/_MOC]] · [[Std Db]] · [[Application Dependency Layers]] · [[Database Admission Fixture]]
