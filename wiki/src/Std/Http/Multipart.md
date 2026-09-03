---
type: module
path: "@root/lib/Std/Http/Multipart.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, http, uploads, forms]
aliases: [Std Http Multipart]
---
# Std Http Multipart
## Purpose
Read a form that carried files, without letting the sender choose where they go.
## Interface
A part: the field it was sent under, what the sender called it, what the sender said it is, and what
it carried. Reading the parts of a body, given what the request said about them. The boundary a
content type names. Finding a part by field, and the fields a form carried. What the sender called a
file, and — separately, and only by asking — a name safe to write to disk. The bounds a read is held
to. What a refusal says.
## Governance and algorithm
**The name a sender gave a file is data, and this module never turns it into a path.** A file
uploaded as `../../etc/passwd` is a file whose name says that; a program that joins it to a
directory has been told where to write by whoever sent it. So the sender's name is answered as what
it is, and a name safe to write is a *different call* that has to be asked for — which is the point,
because a program reaching for a path either says so and gets a safe one, or does not and has
nothing path-shaped to reach for.

The safe name keeps only what follows the last separator of either kind, refuses the names that
are not names, and refuses one that is empty once trimmed. Nothing is unescaped first: what
arrives is what was sent, and undoing an encoding before checking is how a check is bypassed.

**How many parts and how large each may be are bounded before anything is kept.** A body announcing
ten thousand parts is not a form; it is a way to exhaust the memory of whatever reads it. The bound
is applied while reading, not after, because a bound checked afterwards is a bound checked once the
memory is already gone.

**What the sender said a file is, is what the sender said.** A part's declared type is carried
because a program may want it, and is not treated as a fact about the bytes. A program that decides
what to do from that field alone has let the sender choose.

**A body without a boundary, or one whose boundary never appears, is refused.** Not read as a single
part and not read as empty: those are guesses, and a guess about a malformed body is how one reader
sees a form where another sees something else.
## Grill Log
- **Q:** Answer the sender's filename in a form usable as a path? **A:** No — that is the whole
  vulnerability, and it is why the two are separate calls. _Rationale:_ a program that reaches for a
  path should have to say so, and one that does not should have nothing path-shaped in hand.
  _Rejected:_ a single sanitised filename; sanitising in place.
- **Q:** Undo percent-encoding in a filename before checking it? **A:** No. _Rationale:_ decoding
  before checking is how a check is bypassed; what arrives is what was sent. _Rejected:_ decoding
  first.
- **Q:** Trust the part's declared content type? **A:** Carried, never trusted. _Rationale:_ it is a
  claim by the sender, and a program that branches on it alone has let the sender choose the branch.
  _Rejected:_ deciding anything from it here.
- **Q:** Read a body with no boundary as one part? **A:** No. _Rationale:_ a guess about a malformed
  body is how two readers come to disagree about what a request contained. _Rejected:_ lenient
  reading.
- **Q:** Bound the whole body rather than each part? **A:** Both, and each while reading.
  _Rationale:_ a per-part bound alone lets enough parts add up to anything, and a whole-body bound
  alone lets one part be the whole of it. _Rejected:_ one bound; checking after reading.
## Referenced by
[[src/Std/_MOC]] · [[Std Http]] · [[Std Http Server]] · [[Std Http Safe]] · [[ADR-0017 What the Web Layer Refuses]]
