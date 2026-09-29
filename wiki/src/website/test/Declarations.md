---
type: module
path: "@root/website/src/Test/Declarations.pudu"
fidelity: Active
tags: [website, tests, api, packages]
aliases: [website declarations suite]
---
# Website Declarations Suite

Checks [[website Domain Declarations]] on a source written the way packages write theirs: an
anchored type, a documented constant, a function whose documentation has a second paragraph and
an examples section, a function header spread over lines with type parameters, a private helper,
documentation separated from its declaration by code, an async function, and an anchored trait.
It pins the module name, every entry's name, kind, signature, and paragraphs in order, text
without a module, and a module without exports.

It also checks `LiveFiles.ofRoot`: the root's file and every file beneath its directory are read,
while suites, examples, tools, a neighbouring root with the same prefix, and non-Pudu files are not.

## Grill Log

- **Q:** Why a suite of its own? **A:** [[website regression suite]] is past the 500-line limit, and
  reading declarations from text is one concern with its own fixture.

## Referenced by

[[website Domain Declarations]] · [[website/_MOC]]
