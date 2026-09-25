---
type: script
path: "@root/website/public/assets/download/platform.js"
fidelity: Active
tags: [website, download, asset]
aliases: [Download platform script]
---
# Download Platform Script

Enhances [[website View Download]]. It reads the reader's platform from
`navigator.userAgentData.platform` where the browser offers it, and from `navigator.platform` and
the user agent otherwise, and maps it to an archive target: macOS on Apple silicon to `darwin-arm64`,
Linux on x86-64 to `linux-amd64`. When a hero button carries that target it becomes the primary
button and moves first.

The per-archive install sections become tabs: a `tablist` of buttons (`role="tab"`, `aria-selected`,
`aria-controls`) above the sections (`role="tabpanel"`), with the detected platform selected, or the
first when none matches. Arrow keys, Home, and End move between tabs.

Without the script the page is complete: every button and every section is shown.

See [[website View Download]].

## Grill Log

- **Q:** Guess Intel macOS as Apple silicon? **A:** A Mac reports no architecture to a page, and
  every Mac Pudu ships for is Apple silicon; `darwin-arm64` is the only macOS archive. _Rationale:_
  the guess only orders buttons, and the others stay one click away.
