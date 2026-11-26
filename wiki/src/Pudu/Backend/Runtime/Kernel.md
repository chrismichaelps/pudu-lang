---
type: module
path: "@root/src/Pudu/Backend/Runtime/Kernel.hs"
fidelity: Active
grammar: "[[grammar/haskell]]"
aliases: [Native Kernel Runtime]
---
# Native Kernel Runtime

Export kernelRuntimeParts and kernelRuntimeDependencies: every kernel part
in emission order and each part's prerequisites, gathered from the family
modules under `Runtime/Kernel`. The parts use `pudu_cell`, so they are
emitted after the frame types.

## Resolved Grill Log

One function per part: a program carries only the kernels it calls, and no
unused static function is written.

Resolved Grill Log: `urlKernelParts` (issue #1007) gives the URL part its own function, so a program carries it only when it calls `urlEncodeComponent`.

## Referenced by

[[Backend Frame Program]] · [[Native Runtime Dependencies]] · [[Native Builtin Kernels]]

## Host families (#846)

`hostRuntimeParts` is appended after the CSV family, so host functions may call
the codecs and every earlier family. Resolved Grill Log: each family
follows its prerequisites. [[Native Binary Kernels]] follow the host families
because the binary reader uses their result channel.

Resolved Grill Log: the HTML family follows the text families it calls. [[Native HTML Kernel]]

## Header kernel part (#1021)

`httpKernelParts` from [[Native HTTP Header Kernel]] joins the kernel runtime parts through its own function, as the URL family does, so a program carries the header part only when it calls `httpHeaderPairs`. Its prerequisites are the array, text, text view, text trim and memory failure parts.

Resolved Grill Log: one function per family keeps the part out of programs that never read a header.
