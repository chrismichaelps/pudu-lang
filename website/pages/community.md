# Community

Pudu is early. It is maintained by one person, which means the fastest way to influence the language
right now is to use it and say what happened.

## Where things happen

Everything is on GitHub.

- **[Issues](https://github.com/chrismichaelps/pudu-lang/issues)** — bugs, and anything the compiler
  told you that you could not act on. A confusing diagnostic is a bug worth reporting.
- **[Discussions](https://github.com/chrismichaelps/pudu-lang/discussions)** — everything that is not
  a bug. [Q&A](https://github.com/chrismichaelps/pudu-lang/discussions/categories/q-a) for how to
  write something, [Ideas](https://github.com/chrismichaelps/pudu-lang/discussions/categories/ideas)
  for proposals before they become issues.
- **[Pull requests](https://github.com/chrismichaelps/pudu-lang/pulls)** — see
  [Contributing](/contributing) first for what a change has to pass.

There is no chat server, forum, or mailing list yet. When there are enough people for one to be worth
reading, this page will say where it is.

## Reporting something that went wrong

The report that gets fixed fastest has three things in it: the program, the command you ran, and what
`pudu` printed. Every diagnostic carries a code such as `E3078`, and quoting it identifies the exact
check that fired.

If the program is large, the useful version is the smallest one that still misbehaves. Reducing it is
often how the cause becomes obvious.

For anything with security consequences, do not open a public issue. [Security](/security) explains
how to report privately and what is in scope.

## Asking a question

Questions are welcome in
[Q&A](https://github.com/chrismichaelps/pudu-lang/discussions/categories/q-a), including ones you
think are obvious. If the documentation led you astray, that is a documentation bug, and saying which
page and what you expected is more useful than the answer itself.

Before asking, the [documentation](/docs) is twenty chapters and every example in it runs as written,
and the [standard library reference](/modules) is searchable by name and by type signature.

## What is most useful right now

Pudu is pre-release, so the most valuable feedback is about friction rather than polish:

- Programs you tried to write and could not, or could only write awkwardly.
- Standard library functions you expected to exist and did not find.
- Diagnostics that told you something was wrong without telling you what to do.
- Anything in the documentation that turned out to be untrue.

Everyone taking part is expected to follow the [Code of Conduct](/conduct).
