---
type: module
path: "@root/website/src/View/Packages/Source.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Source]
---
# Website Package Source

The code view of a release. A dark sidebar holds the release, a file filter (enhanced by
`assets/packages/source/filter.js`), and the file tree with local per-type icons mapped by extension,
the current file marked. Pudu files reuse the VS Code extension's logo, Markdown and common
configuration/source files have distinct icons, and unknown types use a generic document.
Beside it: a breadcrumb from the package through the file's
directories, then a file card whose header names the file, its language (`LANGUAGES`), line count, and
size, with Copy path and GitHub actions; its body is the numbered, linkable listing (`#L12`),
highlighted by [[website View Packages Highlight]] for `.pudu`, or the rendered document for `.md`, or a
note for a binary file. A `.pudu` module under `src/` is paired with a Declarations outline from the
release's catalogue, each linking to its anchor on the Docs tab. Every file route derives from the
checked snapshot list; an unknown file has no page. GitHub links use the release's immutable commit.
Encoded path segments are decoded before lookup; each file page names its own canonical URL. At
narrow widths the sidebar stacks above the file and the listing scrolls inside its card.

See [[architecture/PACKAGES]] · [[website Service Packages]].

## Grill Log

- **Q:** Highlight in the browser? **A:** On the server, per line. _Rationale:_ pages are prerendered and must read the same without script. _Rejected:_ a client highlighter.
- **Q:** Render Markdown files as source? **A:** As the rendered document. _Rationale:_ a README is read, not reviewed. The raw text stays one click away on GitHub.

Resolved Grill Log: source browsing uses registry-mirrored release bytes, so moved or deleted GitHub tags cannot change the page's content until a new snapshot.
