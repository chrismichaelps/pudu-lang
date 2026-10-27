---
type: architecture
aliases: [Native Method Values]
---
# Native Method Values

`text.length`, `items.push` or `m.get` without a call is a value: the
receiver is evaluated once, when the value is made, and kept. Calling the
value runs the method on that receiver. It renders as
`<kind method name>` (`text`, `array`, `map`, `set`, `range`, `character`,
`bytes`), and two method values are equal when they name the same method of
the same kind and their receivers are equal. A failure inside the method
points at the call made through the value.

## Lowering

The member expression's fact is the method's function type. The receiver is
lowered and held in a temporary; the value is a closure over it whose lifted
body is the ordinary method call, lowered by the existing text, array,
keyed, range, char and bytes method lowerings. Those read facts at the
receiver, argument and call spans, so the body is built from synthetic
expressions at fresh spans whose facts are added for this lowering only:
the receiver's checked type, each parameter's, and the method's result.
There is no second implementation of any method.

Keys are `$method:<kind>:<name>:<full CoreFunctionType>`, so one body per
method and signature serves every receiver.

## Failures at the caller

The body's own spans are synthetic, and the interpreter names the call
anyway. A function flagged as blaming its caller reports every failure,
explicit or from a runtime helper, with the location of the value call that
entered its frame (the site [[Native Collection Callables]] already keeps)
and its own code, message and help. Helpers called from it that fail while
it is the active frame are covered by the same rule; user functions it calls
have their own frames and keep their own spans.

## Identity

Method closures carry the method's kind and name in their closure info.
Rendering prints `<kind method name>`; equality compares the site (method
and kind) and then the receiver with the receiver type's equality.

## Resolved Grill Log

- **Q:** Re-implement each method for values? **A:** No; the lifted body is
  the same lowering a direct call gets, fed synthetic expressions.
- **Q:** Why not the reference span for failures? **A:** The interpreter
  reports at the call through the value; the reference may be far away.
- **Q:** Relocate in lowering instead of at report time? **A:** Runtime
  helpers take static sites; only the report knows which frame is running.
- **Q:** When is the receiver evaluated? **A:** Once, when the value is
  made; later changes to the variable it came from are not seen, as in the
  interpreter.

## Evidence and remaining scope

Every method family through values: rendering, equality on equal and
different receivers, receivers with effects, owned receivers released once,
failures at the call through the value, values in records, captures and
generic code; both evaluators, Clang, GCC 15 and ASan/UBSan. Trait and
user-declared methods as values are a separate obligation.

## Referenced by

[[architecture/_MOC]] · [[Native Emission Coverage]] · [[Compiler Lower Body]] · [[Backend Method Value Programs]]

## Trait methods (#646)

A record without a field of that name, or a sum, may be the receiver too: the
lifted body's call reaches the ordinary trait-method dispatch, and the value
renders as `<fn name>` with the `function` kind. `Bot.label` names the
method through its type: a capture-free wrapper whose body is
`Bot.label($1, ...)`, keyed by owner, method and signature, so every
reference compares equal. Both wrappers are uncounted; the implementation
keeps its own counted frame and its own spans for failures.

Resolved Grill Log: the trait-qualified value `Named.label` stays refused
with E6001: the interpreter fails it at run time with an undefined name
(#647), so there is no behaviour to match yet.
