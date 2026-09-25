---
type: script
path: "@root/website/scripts/packages/github.mjs"
fidelity: Active
tags: [website, packages, build, github]
aliases: [Package snapshot GitHub client]
---
# Package Snapshot GitHub Client

The only code in the snapshot generator that talks to GitHub. `json(path)` and `pages(path)` read the
REST API; `archive(path)` downloads a tarball. Every JSON request is **conditional**. The client keeps
the last `ETag` and body for each URL (loaded from and saved to the cache directory) and sends
`If-None-Match`. A `304 Not Modified` answer reuses the stored body, and authenticated `304` answers do
not count against GitHub's rate limit.

It counts requests, `304` answers, and archive downloads for the build summary. It also records
`x-ratelimit-remaining` from each answer so the generator can stop refreshing before the budget is
exhausted. When a search answer is rate limited and the reset is under 90 seconds away, it waits
for the reset once and retries.

See [[Package snapshot generator]] · [[Package snapshot cache]] · [[Package topic discovery]].

## Grill Log

- **Q:** Cache bodies or only ETags? **A:** Both. _Rationale:_ a `304` carries no body, so the stored
  body is what the generator reads.
- **Q:** Treat a search rate limit as fatal? **A:** Only after one wait for a reset under 90 seconds.
  _Rationale:_ the search limit resets each minute, and splitting discovery issues several searches.

Resolved Grill Log: only GET requests to the configured API are cached, the token never enters the
cache file, and a failed answer is never stored.
