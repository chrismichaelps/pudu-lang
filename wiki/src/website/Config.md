---
type: module
path: "@root/website/src/Config.pudu"
fidelity: Active
tags: [website, config]
aliases: [website Config]
---
# Website Config

Reads host, port, connection limit, catalogue path, package snapshot path (`PUDU_PACKAGES_PATH`), and documentation directory
(`PUDU_DOCS_PATH`, default `website/docs`) from environment variables with checked defaults and typed
errors.

Resolved Grill Log: malformed values fail startup rather than silently disabling a bound.

## Every wrong setting at once

Settings are read as written and checked by `pudu-lang-validator` rules — whole numbers within their
bounds, an `https://` or `http://` origin, a known runner, isolation, log level, and log format, and a
token beside a runner's address — and `load` refuses startup with `SettingsInvalid` naming every wrong
site and playground setting together. `log` carries `PUDU_SITE_LOG_LEVEL` (default `information`),
`PUDU_SITE_LOG_FORMAT` (`text`, `console`, or `json`), and whether the level was set.

Resolved Grill Log: an operator fixes a deployment in one pass rather than one variable per restart.
