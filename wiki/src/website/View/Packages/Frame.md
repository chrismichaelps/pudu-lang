---
type: module
path: "@root/website/src/View/Packages/Frame.pudu"
fidelity: Active
tags: [website, packages, view]
aliases: [website View Packages Frame]
---
# Website Package Frame

Shared project header, owner marks, navigation tabs, package search box, and install disclosure.

The header is a "Package" page banner showing the owner's mark, `@owner / name`, the description,
and a line of facts: the latest
release, the licence when known, and the GitHub star count (shortened by `shortCount` as `1.2k`)
linking to the repository's stargazers. The install control sits beside the title. Beneath, the
tabs (Overview, Source, Docs, Releases, Tickets, Contributions) share one rule with a search box fixed
to the project; below 1000px the box moves above the tabs. Tickets and Contributions are native tabs
backed by the build snapshot. Child source and discussion pages may supply their own canonical
address.

The install panel shows an exact command for the newest available release, version choices, the
unversioned command and its 72-hour minimum-age behavior, an import line, and copy controls. It is
absent when no installable release exists. Its script enhances native HTML controls. On a short
viewport, the disclosure summary moves above the scrollable panel and shows Close; its accessible
name describes the toggle in either state.

**Owner marks.** `avatarSource` prefers the build's local avatar copy, then a GitHub-hosted avatar URL.
Beneath the image sits a mark drawn from the logo: a square split into one of its four two-tone letter
pairs with a round counter. `tone` chooses the pair from the handle, so an owner keeps one colour on
every page and in suggestions. A failed image is removed by the avatar script to expose the mark.
`avatar` loads lazily, for rows; `bannerAvatar` loads eagerly with high priority, for the project
banner and a profile header, which are on screen as the page opens.

**Search box.** `searchBox` is the one package search form: a drawn magnifier, the field, a `/` key
hint, a `?` disclosure listing the query forms and keys, and a submit button. With a filter it
carries a hidden `filter` field and, unless fixed, a clear link; a fixed box (`data-filter-fixed`) is
a project's own. `tabHeading` is the heading every tab opens with (title, lead, optional action, closed by an ink
rule), and `copyable` is the command line with a copy button used by the install panel, the overview,
and releases. `kindMark` is the one table of declaration kind marks, shared by the results page and
the suggestion JSON.

See [[architecture/PACKAGES]] · [[website Service Packages]] · [[Package live search]].

## Grill Log

- **Q:** Host tickets and contributions? **A:** Render GitHub's public records as native read-only tabs and link to GitHub for posting and review. _Rationale:_ discovery stays on the package page while the repository retains the conversation. _Rejected:_ a second writable tracker.
- **Q:** What represents an owner without a usable avatar? **A:** A two-tone mark in one of the
  logo's letter pairs. _Rationale:_ it belongs to Pudu's own identity, stays recognisable at row and
  profile sizes, and invents no initials or illustration.
- **Q:** Give the project its own header style? **A:** No; the site banner, as on every page.
  _Rationale:_ one header across the site; the facts line and install control fit inside it.
- **Q:** One search form per page type? **A:** No; one builder. _Rationale:_ the catalogue, results,
  and project pages must behave identically under the script and without it.

Resolved Grill Log: a native disclosure keeps the install instructions available when script is unavailable; only published, non-yanked versions are selectable for new installs. Every search box submits to the full results page without script.
