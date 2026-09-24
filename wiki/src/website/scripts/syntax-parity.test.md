---
type: script
path: "@root/website/scripts/syntax-parity.test.mjs"
fidelity: Active
tags: [website, tests, highlighting]
aliases: [Syntax parity test]
---
# Syntax Parity Test

Runs the playground's `text/syntax.js` over every case in `website/test/fixtures/syntax.json` and
requires the HTML recorded there. [[website Markdown suite]] holds [[website View Syntax]] to the same
fixture, so the documentation and the playground paint Pudu alike; a change to either painter fails
one side until the fixture is updated on purpose. `syntax.js` is a browser module the project does
not mark as one, so the test imports its text as a `data:` module.

See [[website View Syntax]].

## Grill Log

- **Q:** Generate the fixture on every run? **A:** No; it is committed. _Rationale:_ a recorded
  answer is what makes a drift visible; regenerating would follow either painter silently.
