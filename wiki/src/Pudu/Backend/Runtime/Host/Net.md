---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Net.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host Sockets]
---
# Native Host Sockets

Export the family's runtime parts and their prerequisites.

Stream endpoints behind their tokens: listening, accepting, connecting, sending every byte, receiving up to a count, ending the sending side, naming the peer and the local port, and closing, as `Pudu.Eval.Socket` answers them.

## Resolved Grill Log

- Share the open-file tokens? No: endpoints are numbered from one in their own run, as the interpreter's socket store numbers them.
- Block the whole program while one endpoint waits? No: every descriptor is non-blocking and a wait gives up the run gate until the descriptor is ready or the budget ends.
- A budget of zero? The operation is not started and answers the time-out; a negative budget never ends.
- A send or receive that runs out of time? The endpoint is closed and its token forgotten, then the time-out is answered.
- A receive of no bytes? It answers an empty run without looking at the token; the peer's end answers nothing there.
- Closing twice or closing an unknown token? Done already.
- A peer that closed while this side writes? The write answers the failure; no signal ends the program.
- Refusal wording? The operation's library name, the failure kind and the system's reason, in the interpreter's layout; a connection names its descriptor.
- Who else dials? [[Native Host TLS]]: `host_socket_dialing` answers a connected descriptor and `host_socket_connecting` keeps it behind a token, so a secured connection never spends a plain token.
- Resolution? Asked of the machine's resolver for a stream address; the first answer is used.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]] · [[Native Host TLS]]
