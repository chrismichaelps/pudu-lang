---
type: module
path: "@root/packages/pudu/v0.1/src/Pudu/Backend/Emit/Foreign.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Backend Emit Foreign]
---
# Backend Emit Foreign

One wrapper per foreign declaration a program calls (#850). The wrapper takes
the call's E7015 site and the frame cells, converts each cell to the C type the
interpreter's bridge crosses it as, calls through a function pointer of that
exact type resolved once by [[Native Host Foreign]], and converts the answer
back to its cell.

## Interface

- `foreignCall` — the call text at a site, registering a site with E7015 and
  the interpreter's help, and the parts it needs.
- `foreignsOf` — every declaration a module's frames call, each once.
- `foreignWrappers` — their definitions.

## Resolved Grill Log

- **Q:** Where does per-declaration C live? **A:** In the module, after the
  aggregate helpers, from the declarations the frames carry. A call site only
  names its wrapper.
- **Q:** Cast `dlsym`'s object pointer to the function's type? **A:** No; the
  loader answers `void (*)(void)` and the wrapper converts between function
  pointer types, which ISO C allows.

## Text and bytes (#851)

A wrapper taking text receives an E7017 site and validates each `Str` before resolving the function and copies it with a closing nought before dispatch, releasing the copies after the call. A wrapper answering text receives E7024 and E7025 sites, built with the interpreter's words for the declaration's symbol, and copies the answer out before releasing the argument copies, since it may point into one. `Bytes` cross as the lent address of their storage.

## Records (#852)

Record parameters are packed into their structs (with [[Backend Emit Foreign ABI]]) before dispatch, their text fields held for release after the call; a record result is unpacked into a new box before the argument copies are released. `foreignNeeds` gathers, per module, each leaf's conversion and the constructor and release of every record crossed, since both its pack and unpack functions are written.

## Handle crossings (#853)

Validate text, resolve the invoked symbol and any result destructor, then
check handle liveness before entering foreign code. Wrapper identities retain
full checked crossing types and ownership policy. A cached typed destructor
can release a claim during teardown without resolving another symbol. Validate
raw result text before allocating copies, and free argument scratch before
reporting missing or invalid returned text. Select text helper dependencies by
crossing direction. Record codecs still emit both directions.

## Referenced by

[[Backend Frame Program]] · [[Native Foreign Call Sites]]

## Scalar output slots (#854)

Resolved Grill Log: Initialize scalar slots to zero, pass their addresses, and construct the checked result tuple after dispatch.
