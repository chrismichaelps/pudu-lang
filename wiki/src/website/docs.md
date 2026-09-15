---
type: content
path: "@root/website/docs"
fidelity: Active
tags: [website, documentation, content]
aliases: [website documentation pages]
---
# Website documentation pages

The language documentation is Markdown in `website/docs/`, rendered on the server by
[[website View Docs]]: introduction, basics, types, control flow, errors, ownership and references,
traits and methods, concurrency, the standard library, and tooling.

Each page follows [[grammar/pudu]] and [[architecture/SEMANTICS]] as the language is implemented, not
as it is planned: where the interpreter does not yet do what the semantics describe, the page says so
and shows what works. Every fenced `pudu` block that begins with `module` is a complete program; each
one was checked and run, and each `main` answers 0 (the test example answers its passed count).

Known limitation recorded on the ownership page and in [[First Release Readiness]]: assigning through
a reference is accepted by the checker and refused by the evaluator, so the page shows returning the
changed value instead.

Resolved Grill Log: the private book was not used as a source, because it is gitignored and must not
be published. The pages are written from the distilled grammar, the semantics, and running programs.
