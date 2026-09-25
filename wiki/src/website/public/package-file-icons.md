---
type: asset
path: "@root/website/public/assets/packages/files/"
fidelity: Active
tags: [website, packages, assets]
aliases: [Package file icons]
---
# Package File Icons

The source tree uses a local Pudu icon copied from `editors/vscode/icons/pudu-file.png` and SVG
icons for Markdown, TOML, JSON, YAML, JavaScript, CSS, HTML, and text files from
[vscode-icons](https://github.com/vscode-icons/vscode-icons), under its MIT license retained
beside the assets. Unknown file types use the text icon. Files are selected by extension on the
server; the icon is decorative and the adjacent filename remains the accessible label.

See [[website View Packages Source]] · [[website stylesheet]].

## Grill Log

- **Q:** Fetch icons from a remote host when a reader opens a package? **A:** No; ship reviewed
  local assets. _Rationale:_ file navigation works without a third-party icon request.

Resolved Grill Log: the Pudu language mark is the project's own editor icon, while common file
types use an attributed permissive icon set and an explicit fallback.
