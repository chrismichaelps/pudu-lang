---
type: content
path: "@root/website/docs"
fidelity: Active
tags: [website, documentation, content]
aliases: [website documentation pages]
---
# Website documentation pages

The language documentation is Markdown in `website/docs/`, rendered on the server by
[[website View Docs]]. It reads as a book, each chapter building on the ones before it:

1. **Starting out** — introduction, getting started, basics, functions, types, numbers.
2. **Working with data** — text, collections, control flow, errors.
3. **Structuring programs** — ownership and references, modules and packages, traits and methods,
   generics, compile time and macros.
4. **Building real software** — testing, files and the system, data formats, HTTP servers and
   clients, concurrency, unsafe and foreign code.
5. **Reference** — the standard library map, tooling.

A file is named `NN-slug.md`; the number orders the chapters and the slug is the address, so
renumbering to insert a chapter changes no link. The introduction ends with this outline.

Each page follows [[grammar/pudu]] and [[architecture/SEMANTICS]] as the language is implemented, not
as it is planned. Every fenced `pudu` block is a complete program named by its `module` line: each was
checked and run with the current compiler, each `main` answers 0, each test module passes under
`pudu test`, and the two-file example in modules and packages was run as a project. Examples that
reach the network or listen on a port do so only behind a flag, so running them as written finishes.
All 107 documentation and playground examples, across 23 chapters, ran on 2026-09-22. A foreign
block's owned handle is shown as a `text` block, because no library the example gate can rely on
hands one back.

Resolved Grill Log: the private book was not used as a source, because it is gitignored and must not
be published. The pages are written from the distilled grammar, the semantics, the standard library's
own signatures, and running programs. An example that failed was corrected in the page rather than
removed, so every chapter keeps the program its prose describes.
