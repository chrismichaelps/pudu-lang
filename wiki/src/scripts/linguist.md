---
type: script
path: "@root/scripts/linguist.py"
fidelity: Active
tags: [linguist, github, tooling, ci]
aliases: [Linguist Submission]
---
# Linguist Submission

Keeps Pudu's submission to GitHub Linguist buildable from what the repository already has, so the
language bar and code highlighting can name `.pudu` files the day Linguist lists the language.

- `check [--pudu PUDU]` holds `editors/linguist/language.yml`, the grammar at
  `editors/vscode/syntaxes/pudu.tmLanguage.json`, the listed samples, and `.gitattributes` to one
  another: one `Pudu` entry of type `programming` with no `language_id`, a lowercase colour, exactly
  the `.pudu` extension, a grammar whose `scopeName` is the entry's `tm_scope`, samples of at least
  forty lines that compile, and an override naming `*.pudu` as Pudu. CI runs it.
- `usage` asks code search through `gh` for `extension:pudu` and reports indexed files, repositories
  outside this one, and owners against Linguist's bar of 2,000 files across many owners. It exits `0`
  when the bar is met and `2` when it is not.
- `prepare LINGUIST_DIR` inserts the entry into a Linguist clone's `languages.yml` before the first
  name that sorts after it byte for byte, which is the order Linguist's pedantic test asserts, and
  copies the samples into `samples/Pudu/`. Nothing else in the clone changes.

`.gitattributes` names `*.pudu` as Pudu and marks the generated API catalogue and release document
as generated. Linguist ignores an override naming a language it does not list, so the line is inert
until the listing ships and effective from then on without another commit.

Resolved Grill Log:

- **Q:** Open the Linguist pull request now? **A:** No. _Rationale:_ Linguist closes submissions
  below its usage bar unreviewed, and `usage` measured 378 files in one repository. _Rejected:_ an
  outward pull request that cannot be accepted.
- **Q:** Override `.pudu` to an existing language so the bar shows something? **A:** No.
  _Rationale:_ the bar would then report Pudu as another language. _Rejected:_ a mislabelled
  statistic.
- **Q:** Commit copies of the samples and grammar under `editors/linguist/`? **A:** No.
  _Rationale:_ copies drift from the files they copy; `prepare` reads the originals when the
  submission is made. _Rejected:_ a second grammar and second sample set.
- **Q:** Re-sort `languages.yml` after adding the entry? **A:** No. _Rationale:_ a whole-file sort
  with a different collation rewrote 2,600 lines in a trial run. _Rejected:_ any change outside the
  seven lines the entry is.
