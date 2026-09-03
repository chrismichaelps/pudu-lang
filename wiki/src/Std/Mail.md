---
type: module
path: "@root/lib/Std/Mail.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, mail, smtp]
aliases: [Std Mail]
---
# Std Mail
## Purpose
A message a program sends, in a form that cannot carry more than it says.
## Interface
An address, checked. A message: who it is from, who it is to, who is copied, who is copied without
the others knowing, what it is about, and what it says. Adding each of those. The envelope — every
address a server must be given — and the headers, which are not the same list. Rendering a message
to what goes on the wire. What a refusal says.
## Governance and algorithm
**An address or a subject that could end a header is refused.** A line break in either lets whoever
supplied it write headers of their own: another recipient, another sender, a different subject, or a
whole second message. This is the oldest injection in mail and it is still how bulk mail is sent
through somebody else's contact form. Refused rather than stripped, because stripping guesses at
what was meant and leaves the caller believing their value was used.

**Who is copied without the others knowing is in the envelope and never in the headers.** That is
structural here rather than a rule to remember: the headers are built from the visible recipients
only, and the envelope from all of them. A program cannot write the blind list into the headers by
forgetting something, because nothing it can call does that.

**A line of the body that would end the message is escaped.** The wire format ends a message with a
lone full stop on its own line, so a body containing one would otherwise be truncated there and the
rest read as commands. Every such line gains a second stop, which the receiving end removes.

**A message is a value and is checked without a server.** Whether it is well formed, what its
envelope is, and what goes on the wire are all answered by comparing values, so what a program will
send is inspectable before anything is connected to.

**Nothing here sends.** Sending is a conversation over a connection, with its own failures and its
own need for transport security; keeping it apart means the part where the mistakes are costly is
the part that can be checked exhaustively.
## Grill Log
- **Q:** Strip line breaks from a subject rather than refusing it? **A:** No. _Rationale:_ stripping
  guesses at what was meant and hands back a message the caller believes carries what they gave it.
  A subject that cannot be sent is worth saying so about. _Rejected:_ stripping; encoding the break.
- **Q:** Keep one list of recipients and mark which are blind? **A:** No; the envelope and the
  headers are built separately. _Rationale:_ one list means every place that writes headers has to
  remember to filter it, and the failure — every recipient seeing the blind list — is one nobody
  notices until it has happened. _Rejected:_ a marked list.
- **Q:** Leave escaping the body's full stops to the sender? **A:** No. _Rationale:_ it is a property
  of the wire format rather than of the message, and a caller who has not read that format has no
  reason to know. _Rejected:_ documenting it.
- **Q:** Include sending here? **A:** No. _Rationale:_ the message is where a mistake is silent and
  costly, and it can be checked completely without a network. Mixing the two would make the
  checkable part need a server. _Rejected:_ one module.
## Referenced by
[[src/Std/_MOC]] · [[Std Http Safe]] · [[Std Tls]] · [[Std Validate]]
