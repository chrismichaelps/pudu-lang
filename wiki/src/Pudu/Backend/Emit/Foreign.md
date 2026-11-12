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

## Referenced by

[[Backend Frame Program]] · [[Native Foreign Call Sites]]
