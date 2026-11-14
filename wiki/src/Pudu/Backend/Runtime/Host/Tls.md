---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Runtime/Host/Tls.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Host TLS]
---
# Native Host TLS

Export the family's runtime parts, their prerequisites and `tlsLibraryMarker`.

Secured connections behind their tokens: connecting, securing a plain endpoint the application protocol agreed to secure, sending every byte, receiving one record, naming the proven host, and closing with the protocol's goodbye, as `Pudu.Eval.Tls` answers them, through the system's TLS library (OpenSSL's interface).

## Resolved Grill Log

- Write the protocol in the runtime text? No: the part includes the system TLS library's header, and the toolchain links that library only for a program whose source includes it. Rejected: a protocol implementation of our own, where a skipped check is silent.
- Can a program turn verification off? No: one client configuration per run verifies the peer against the system's trust store, checks the name the caller gave (an address literal as an address), and speaks nothing older than TLS 1.2. No operand reaches it.
- Share the plain endpoints' tokens? No: secured connections are numbered from one in their own run, as the interpreter's store numbers them. Dialing is shared with [[Native Host Sockets]] through a part that answers a descriptor, so a secured connection never spends a plain token.
- One budget for connecting? Yes: resolution, the connection and the handshake draw on one budget counted from the start. A budget of zero answers the time-out before anything starts; a negative budget never ends.
- A send or receive that runs out of time? The connection is closed and its token forgotten, then the time-out is answered. A close that runs out of time still closes.
- How much does a receive answer? What one record held; the count only says bytes are wanted, and a count of zero or less answers an empty run without looking at the token.
- The far end finished? The first read that finds it answers nothing there, whether or not the far end said goodbye; every read after that answers `PostHandshake Error_EOF`, as the interpreter does.
- Upgrading a plain endpoint? The plain token is forgotten first; a far end that does not prove itself closes the descriptor.
- Another thread closes a connection that is waiting? The waiting operation holds its own reference to the session for the wait, so the session outlives the close.
- Refusal wording? `the secured connection is closed`, `the plain connection is closed`, `operation timed out` and `HandshakeFailed Error_EOF` are the interpreter's own words. A failure of the descriptor is worded as a plain endpoint words it. A refusal the library itself decides (an expired certificate, a name that does not match, an unknown authority) keeps the interpreter's `HandshakeFailed` opening and carries the system library's reason in parentheses, which differs from the interpreter library's reason by design.

## Referenced by

[[Native Host Runtime]] · [[Native Host Services]] · [[Backend Toolchain]] · [[Native Host Sockets]]
