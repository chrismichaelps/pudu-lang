---
type: module
path: "@root/lib/Std/Ui/Live.pudu"
fidelity: Active
domain: "[[Standard Library]]"
subsystem: "[[architecture/STDLIB]]"
tags: [module, stdlib, ui, live, hydration]
aliases: [Std Ui Live]
---
# Std Ui Live
## Purpose
Hold a screen on the server, send what changed, and take back what the viewer did.
## Interface
A session: the component, the screen last sent, and what the viewer is permitted to send. The first
answer, which is a whole page. What a viewer's event produces: the changes, and the session that
follows. Encoding changes and decoding an event, so both ends agree on a message. Whether an event
is one the component declared, and what happens to one that is not. What a dropped connection
leaves, and rejoining from it.
## Governance and algorithm
**There is one renderer and it is here.** The viewer is never asked to reproduce a screen, so there
is no second render to disagree with the first — the failure that dominates the hydrating model is
not rare here, it is not representable. What crosses after the first response is the difference
between two renders, both computed on this side from state this side holds. The reasoning is in
[[architecture/WEB]].

**An event the component did not declare is discarded, not dispatched.** What arrives is text from
whoever is on the other end, and the other end is not the page this server rendered — it is whatever
is speaking the protocol. A session names the events it accepts and anything else is dropped with a
count kept, so a page under attack is visible rather than merely wrong.

**A session is a value, so a screen can be driven without a connection.** A test builds one, gives
it events, and reads the changes, which is the same path a real viewer takes with the transport
removed.

**A dropped connection loses the screen, not the state.** What a viewer is is a state and a
component; the connection is how it was being watched. Rejoining renders from the state and sends a
whole page rather than a difference, because the two ends no longer agree about what is on screen
and sending a difference against an unknown screen produces a wrong one that renders plausibly.

**Nothing here reads a clock or a socket.** Producing the next screen from an event is a pure
function; carrying it is [[Std Http Server Socket]]'s work. That separation is what lets every rule
above be checked by comparing values.
## Grill Log
- **Q:** Send a difference when a viewer rejoins, since the state is known? **A:** No. _Rationale:_
  the state being known is not the question — what the viewer's screen currently shows is, and after
  a drop that is unknown. A difference against an unknown screen produces a wrong one that renders
  plausibly. _Rejected:_ resuming with a difference.
- **Q:** Dispatch whatever event arrives and let the component ignore what it does not know?
  **A:** No. _Rationale:_ the component's update function is written against the events the program
  has, and handing it arbitrary text makes every component responsible for its own filtering,
  differently. _Rejected:_ open dispatch.
- **Q:** Keep the state for a viewer who has gone, in case they return? **A:** Not decided here.
  _Rationale:_ how long is a property of what the screen is for — a form half-filled deserves
  minutes and a dashboard deserves none — and a duration chosen here would be every program's.
  _Rejected:_ a fixed retention.
- **Q:** Send the state alongside the markup so the viewer could re-render? **A:** No. _Rationale:_
  that is the arrangement whose costs this design exists to avoid: the content crosses twice and the
  two renders can disagree. _Rejected:_ serialising state into the page.
## Referenced by
[[src/Std/_MOC]] · [[Std Ui]] · [[Std Http Server Socket]] · [[Std Html]] · [[architecture/WEB]]
