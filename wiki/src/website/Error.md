---
type: module
path: "@root/website/src/Error.pudu"
fidelity: Active
tags: [website, error]
aliases: [website Error]
---
# Website Error

Defines startup, catalogue, and documentation failures and turns them into concise operator-facing
text without exposing catalogue contents or environment values. `DocsUnreadable(path)` names the
documentation directory or page that could not be read.

Resolved Grill Log: preserve the failed setting or path name, never its secret value.
