---
type: module
path: "@root/website/src/Test/LivePackages.pudu"
fidelity: Active
tags: [website, tests, packages, github]
aliases: [website live packages suite]
---
# Website Live Packages Suite

Checks [[website Service LivePackages]], [[website Service LiveSource]], and the package routes of
[[website Web Dynamic]] against a stand-in GitHub: a table of answers, a switch that takes it down,
a request counter, and a clock the test moves. No test touches the network.

- **Success:** a package published after the build is listed with its tag, commit, dependencies,
  manifest description, README, and a new owner profile; a known package takes new counts and a newer
  release; the function renders the new package's overview, releases, the listing, and the owner.
- **Failure:** a manifest naming another package, an archived repository, and a refused name stay
  out; GitHub down from the start yields exactly the snapshot, and a new package's page is 404.
- **Freshness:** a rebuild inside the listing's window asks GitHub nothing; an expired listing is
  asked once while fresh release answers are reused; a failure serves the remembered index and
  leaves GitHub quiet for a window.
- **Diagnostics/output:** live answers carry the long edge cache, snapshot-only answers the short
  one, and a missing package a 60 s cache with `X-Robots-Tag: noindex`; only 200 and 404 classify
  as answers.

Resolved Grill Log: the stand-in is an injected `Origin`, not a local server, because the cache and
quiet-window policy are the behaviour under test and a clock value makes them deterministic.
