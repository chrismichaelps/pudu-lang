---
type: module
path: "@root/lib/Std/App/Session.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, application, sessions, authentication]
aliases: [Std App Session]
---
# Std App Session
## Purpose
Remember who somebody is between requests, without letting anyone else choose the name it is
remembered under.
## Interface
A session: what it is called, who it belongs to, when it began, and when it was last seen. Starting
one for nobody in particular. Signing in, which is the only way a session comes to belong to
somebody. Signing out. Touching one, so an idle bound measures from the last request rather than the
first. Whether one has expired, and which of the two bounds it passed. A set of sessions, and
finding, keeping, and forgetting one. The cookie a session is carried in.
## Governance and algorithm
**Signing in always answers a session with a new name.** There is no call that changes who a session
belongs to while keeping the name it already had, and that absence is the point. The attack this
prevents is the oldest one against sessions: somebody arranges for a victim's browser to hold a name
the attacker already knows, waits for the victim to sign in, and then presents the same name. Every
remedy for it amounts to changing the name at the moment the session gains a privilege — so here
that is not a step to remember, it is the only way the step can be taken.

**A name comes from the machine's own entropy and from nothing else.** Not a counter, not a digest of
who it belongs to, not the time. Any of those lets one name be guessed from another, and a name that
can be guessed is a session that can be taken. Failing to reach entropy fails the sign-in rather
than falling back, for the same reason a predictable salt is worse than none.

**Two bounds, because they answer two questions.** How long a session may live at all bounds how long
a stolen one is useful; how long it may sit unused bounds an unattended screen in an office. A
design with only the first leaves a signed-in screen open all day; one with only the second lets a
session live forever as long as somebody keeps touching it.

**The clock is given, not read.** Every judgement here is a pure function of the session and the
moment it is asked about, so expiry is checked by comparing values rather than by waiting. A module
that read a clock could only be tested by making time pass.

**The store belongs to the program.** Sessions are kept in a value the program holds and can put
wherever it keeps things. Nothing here is global, so two evaluations do not share sessions and a
test does not inherit another's.

**What travels is the name and nothing else.** The cookie carries the name; everything known about
the session stays where the program put it. A cookie carrying the session's contents is a session
whose contents the holder can edit.
## Grill Log
- **Q:** Offer a call that changes who a session belongs to, keeping its name? **A:** No, and that is
  the module's main decision. _Rationale:_ it is the whole of the fixation attack, and every defence
  against it is "issue a new name at that moment". Making it the only way removes the chance to
  forget. _Rejected:_ a `setPrincipal`; regeneration as a separate step a caller must remember.
- **Q:** Derive the name from who it belongs to, so a lookup needs no store? **A:** No. _Rationale:_
  then knowing who somebody is is knowing their session name. _Rejected:_ derived names; sequential
  names; time-based names.
- **Q:** Keep one bound rather than two? **A:** No. _Rationale:_ they answer different questions, and
  either alone leaves the other case open. _Rejected:_ absolute only; idle only.
- **Q:** Read the clock here? **A:** No. _Rationale:_ then expiry can only be tested by waiting, and
  a rule nobody can test cheaply is a rule that goes wrong quietly. _Rejected:_ an internal clock.
- **Q:** Compare names in constant time? **A:** The store is an ordinary map, so lookup is not
  constant time, and this is stated rather than implied. _Rationale:_ a name is a hundred and
  twenty-eight bits from the machine's entropy; guessing one is not a timing problem. Claiming a
  property that is not there is worse than naming the one that is. _Rejected:_ implying more than
  is true.
## Referenced by
[[src/Std/_MOC]] · [[Std App Access]] · [[Std App Password]] · [[Std Http]] · [[Std Random]]
