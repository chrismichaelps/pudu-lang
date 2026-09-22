---
type: module
path: "@root/website/src/View/Packages/Frame.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Frame]
---
# Website Package Frame

Shared project banner, avatar, navigation tabs, and install disclosure. The banner identifies the package, includes its description and release, and places the install control near the title. The install panel shows an exact command for the newest available release, version choices, the unversioned command and its 72-hour minimum-age behavior, an import line, and copy controls. It is absent when no installable release exists. Its script enhances native HTML controls. Child source pages may supply their own canonical address.
On a short viewport, the disclosure summary moves above the scrollable panel and names its closing action.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

Resolved Grill Log: a native disclosure keeps the install instructions available when script is unavailable; only published, non-yanked versions are selectable for new installs. The banner and tabs are original Pudu design, while preserving a clear project hierarchy.
