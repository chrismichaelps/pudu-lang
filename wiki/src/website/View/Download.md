---
type: module
path: "@root/website/src/View/Download.pudu"
fidelity: Active
tags: [website, view, download]
aliases: [website View Download]
---
# Website Download View

Renders the current release's download page. Release facts come from [[website Service Releases]];
the view only arranges them.

- **Hero.** The home page's banner (`hero-banner download-hero`) carries a link pill naming the
  release (`Pre-release` or `Latest`, the version, and its date) to the releases page, the title, one
  line on what an archive holds, and a download button per archive labelled with its operating system
  and size, above a line naming its architecture. The buttons carry `data-platform` (the archive's
  target), and the first is the primary light button. [[Download platform script]] makes the
  reader's platform the primary one and moves it first. Without script every button is shown and
  works.
- **Install.** A section per archive (`download-platform`, `data-platform`) with its architecture, file
  name, size, and the four commands that check the archive's SHA-256, unpack it, put its `bin`
  directory on `PATH`, and run `pudu version`, as a fenced shell block painted and copyable by
  [[website View Markdown]]. The script turns the sections into tabs, showing the reader's platform
  first; without script they stack, each with its own heading.
- **Checksums.** The table of every archive, its size, and its SHA-256.
- **More.** Links to the release notes, the source, the documentation, and, for a platform without
  an archive, building from source.

## Grill Log

- **Q:** Put release metadata in a separate title section? **A:** No; keep the version and
  pre-release notice inside the banner. _Rationale:_ the page identifies the offered release before
  listing archives.
- **Q:** Why the home page's hero rather than the shared page banner? **A:** Downloading is the one
  action this page exists for, as searching and learning are the home page's; the action belongs in
  the banner, where the home page already puts its download button. _Rejected:_ cards below a text
  banner, which put the button a scroll away on a phone.
- **Q:** Detect the platform on the server? **A:** No; the page is prerendered and the same for
  everyone, so a script reorders what is already there. _Rationale:_ without script, or on a platform
  with no archive, every choice is still shown and correct.
- **Q:** Why steps per archive? **A:** Each archive's file names differ; commands that name the real
  file can be copied and run as they stand, where a placeholder must be edited first.

Resolved Grill Log: retain the visible archive checksum and source-owned release metadata; the view only arranges it.
