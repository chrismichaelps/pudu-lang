---
type: module
path: "@root/website/src/View/Playground.pudu"
fidelity: Active
tags: [website, playground, view]
aliases: [website View Playground]
---
# Website Playground View

Renders the workspace page: toolbar (Run, Format, Reset, Share, example picker, status, Help, Docs), the gutter, the painted layer beneath the text area, and the output pane. The form is rendered as the fallback of a `Std.Ui.Island` island named `playground`, hydrated eagerly, with `Island.microRuntime` beside it; every control works as a form without a script, and the island's JSON props (`run`, `assist`, `share`, `enabled`, `shareLimit`, `runMillis`) configure the script. An example's page is canonical; runs and shared programs are `noindex`.

Resolved Grill Log: Reset is a link to the example's page, so it works without a script and the script restores the program in place.
