---
type: module
path: "@root/website/src/Service/LiveSource.pudu"
fidelity: Active
tags: [website, packages, service, github, cache]
aliases: [website Service LiveSource]
---
# Website Service LiveSource

Reads GitHub addresses for [[website Service LivePackages]] and remembers each answer in a bounded
[[Std App IsrCache]] for the life of one function instance. An answer is served from memory while
fresh, refetched once it is not, and served stale for its stale window when the refetch fails.

- `Origin` holds the fetch and the clock as values; `github(token)` is the production origin over
  `Std.Http.Client` (4 s deadline, 2 MB body, two redirects), and tests pass a stand-in.
- `classify` maps only `200` to `Found` and `404` to `Absent`; `403`, `429`, `5xx`, timeouts, and
  unreachable hosts are `Unavailable` and never replace a remembered answer.
- After any `Unavailable`, every address is left alone for 60 seconds (`quietUntil`), so a rate limit
  or outage costs one slow request per window rather than one per page view.
- `GITHUB_TOKEN`, when the platform sets it, is sent only to `https://api.github.com/`; raw file reads
  are public and do not spend the API limit.

See [[website Service LivePackages]] · [[website Web Dynamic]] · [[src/website/_MOC]].

## Grill Log

- **Q:** Cache typed values or GitHub's answers? **A:** Answers, by address, in `Std.App.IsrCache`.
  _Rationale:_ one generic fresh/stale/miss policy serves the search, tags, manifests, and READMEs,
  and the merge stays a pure function of remembered text. _Rejected:_ a second cache type.
- **Q:** Retry a failed request? **A:** No; serve the stale answer and go quiet for a minute.
  _Rationale:_ a reader should never wait on retries; the CDN already revalidates in the background.

Resolved Grill Log: only `200` and `404` speak for a repository; every other outcome falls back to
the remembered answer or the snapshot, and the credential never leaves the API origin.
