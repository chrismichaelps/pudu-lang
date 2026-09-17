# Pudu in GitHub Linguist

GitHub's language bar and its code highlighting come from
[Linguist](https://github.com/github-linguist/linguist), and Linguist counts only the
languages it lists. Pudu is not listed yet, so a repository's `.pudu` files are left out of
its language statistics. What the bar shows is the code that implements the language, not
the Pudu written in it.

## What is already in place

- **`.gitattributes`** names every `*.pudu` file as Pudu. Linguist ignores an override that
  names a language it does not know, so today the line changes nothing. From the deployment
  that lists Pudu, every `.pudu` file is counted and highlighted without another commit. The
  generated API catalogue and release document are marked `linguist-generated`, so they are
  folded in diffs and left out of the statistics.
- **`language.yml`** is the entry Pudu adds to Linguist's `lib/linguist/languages.yml`.
- **The grammar** is `editors/vscode/syntaxes/pudu.tmLanguage.json`, the same TextMate
  grammar the editor extension uses, with the scope `source.pudu`.
- **The samples** are real programs from this repository: two standard-library modules and two
  website modules. They are listed in `scripts/linguist.py`, and Linguist does not accept
  tutorial programs.

CI runs `scripts/linguist.py check --pudu <compiler>`. It fails when the entry, the grammar,
the samples, and `.gitattributes` stop agreeing, or when a sample no longer compiles.

## When the submission can be made

Linguist lists a language only once it is used well beyond one project. For an extension
that appears many times in one repository, that means **at least 2,000 files indexed by
GitHub code search in the last year**, not counting forks, spread across many different
owners. A pull request that does not meet that bar is closed without review.

Measure it with:

```bash
python3 scripts/linguist.py usage
```

The script exits `0` once the bar is met and `2` while it is not. It needs `gh` signed in,
because code search requires authentication.

## Making the submission

When `usage` reports that the bar is met, run these steps:

```bash
git clone https://github.com/github-linguist/linguist
python3 scripts/linguist.py prepare linguist
```

`prepare` inserts the entry at its sorted place in `languages.yml` and copies the samples into
`samples/Pudu/`. It changes nothing else. Then, inside the Linguist clone:

```bash
script/add-grammar https://github.com/chrismichaelps/pudu-lang
script/update-ids
bundle exec rake test
```

Open the pull request with Linguist's template filled in, and include:

- a link to the code search results for `path:*.pudu`;
- that the samples are licensed Apache-2.0, the licence of this repository;
- that `#6686fc` is the brand colour the Pudu website uses.

After the pull request is merged, GitHub picks the change up with its next Linguist release.
Repository statistics are recalculated on the next push.
