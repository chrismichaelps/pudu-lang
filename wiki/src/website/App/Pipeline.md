---
type: module
path: "@root/website/src/App/Pipeline.pudu"
fidelity: Active
tags: [website, application, mediator]
aliases: [website App Pipeline]
---
# Website App Pipeline

The registrations both mediators share, in order: the `pudu-lang-mediator` logging recorder as the
outermost open behavior (a debug event when a message starts, an information or warning event when it
ends, with its elapsed milliseconds), an `Alarm` open exception action that writes an error event for
every failure that is a fault rather than an answer (a crash, a missing or mismatched route), and the
validation registrations of [[website App Rules]].

Resolved Grill Log: an expected answer (`NotFound`, `Invalid`, a refused program) is not an error and
is logged at warning by the recorder only; a fault is logged at error once by the alarm. _Rejected:_
logging inside each handler (repeated, and easy to forget on a new route).
