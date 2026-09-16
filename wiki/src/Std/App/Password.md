---
type: module
path: "@root/lib/Std/App/Password.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, passwords, authentication]
aliases: [Std App Password]
---
# Std App Password
## Purpose
Keep a password in a form that proves it later without holding it.
## Interface
The stored form of a password, and making one from a password. Checking a password against a stored
form. Whether a stored form was made with weaker settings than the ones in use now. Reading the
parameters a stored form carries. What a refusal says.
## Governance and algorithm
**The stored form carries the parameters it was made with.** Algorithm, work factor, and salt travel
with the digest. That is the decision everything else depends on: without it, raising the work
factor invalidates every password already stored, so nobody raises it — and the work factor chosen
years ago is the one still protecting the passwords. With it, an old password verifies against its
own parameters and is quietly re-made at the next successful sign-in, so the store improves without
anybody being locked out.

**Every password gets its own salt, from the machine's own entropy.** A shared salt means two people
who chose the same password have the same digest, which turns one guess into a list of accounts. A
salt from a predictable source is not a salt.

**Comparison does not stop at the first difference.** A comparison that returns as soon as two bytes
differ takes a length of time that depends on how much of the digest was right, and that is enough
to find the rest of it a byte at a time. The comparison here takes the same time whatever it is
given.

**Nothing here is reversible and nothing here reads a password back.** There is no call that answers
what a stored form was made from, because there is nothing to answer with. A program that needs to
send somebody their password has a design problem this module will not solve.

**Failing to reach entropy is a failure, not a fallback.** A password stored with a predictable salt
is worse than one not stored at all, because it looks stored. If the machine cannot supply
randomness, making a stored form fails and says so.
## Grill Log
- **Q:** Fix the work factor as a constant, so the stored form is shorter? **A:** No. _Rationale:_
  then raising it invalidates every stored password, so it is never raised, and the number chosen at
  the start is the one still in use when it is no longer enough. _Rejected:_ an implicit work
  factor; a global setting read at verification.
- **Q:** Compare digests with ordinary equality? **A:** No. _Rationale:_ ordinary comparison stops
  at the first difference, and how long it took says how much was right. _Rejected:_ text equality.
- **Q:** Fall back to a clock-derived salt when entropy is unavailable? **A:** No. _Rationale:_ a
  predictable salt is not a salt, and a store full of them looks exactly like a safe one.
  _Rejected:_ any fallback.
- **Q:** Impose a minimum length here? **A:** No. _Rationale:_ what a password must be is policy and
  belongs with the other rules a program states, in [[Std Validate]], where the refusal reaches the
  person who has to fix it. This module's job is to store what it is given.
  _Rejected:_ a built-in policy.
## Referenced by
[[src/Std/_MOC]] · [[Std App Access]] · [[Std Crypto]] · [[Std Random]] · [[Std Validate]]
