---
type: stylesheet
path: "@root/website/public/site.css"
fidelity: Active
tags: [website, css, responsive, accessibility]
aliases: [website stylesheet]
---
# Website Stylesheet

**Visual system.** Ink text and primary buttons on surfaces tinted from the soft blue of the logo's
`P` (`--line`, `--soft`, `--paper`, `--code`), with Pudu blue for links and focus. Every page with a
header opens with the dark blue gradient banner (`hero-banner`, and the shorter `page-banner`): home,
the package catalogue, search results, owner profiles, project pages, documentation, API reference,
download, releases, policy, and missing pages. Its diagonal lines and warm corner shape are the
page's one decoration; below it, section titles are sentence case over a two-pixel ink rule, radii
stay at 10px or less, and shadows belong to the banner's search field and to popovers (`--lift`).
A pudu may peek over a banner's top edge from a `pudu-host`, one layer below it; its parts are
filled from the `--pudu-*` tokens, and a small screen draws it smaller ([[Pudu mascot script]]).
The logo's four two-tone pairs (`--tone-0` to `--tone-3` with `-soft` halves) mark owners and draw the
short rule before section labels such as `kind`.

The banner clips its overflow for the corner shape, so suggestion and help panels are fixed-position
and placed by script. A project's banner instead draws its corner as a radial gradient and leaves
overflow visible, so the install disclosure can open below it above the page. Inside a banner,
labels, leads, facts, and links are light; the install panel restores ink text.

API search results and module pages are ledgers too: a monospace name with its kind and module at the
right, the signature beneath without a box, then the summary. The documentation index lists chapters
in two ruled columns rather than cards, and the home page's module list sits under an ink rule in
monospace.

The catalogue is a ledger (mark, identity and description, release, stars) beside a topics and
publishing column that drops below at 900px. Search results reuse the ledger for projects and give
declarations a kind mark, module, project and release, and signature. A project page has the banner
with identity, facts, and the install control, then tabs on one rule with a project search box that
moves above the tabs below 1000px. Every tab opens with the same heading closed by an ink rule. The
overview shows the README as a file beside a hairline-divided facts column; releases give the latest
a block with its command and the rest a ledger table; docs pair a ruled module index with declaration
rows; tickets and contributions are ledgers with state dots, and a detail reads as a post. The source
tab is a light file column beside a file with a monospace header bar, a plain line-number gutter,
and a ruled declarations outline; the pane fades only while a slow file request is outstanding.

**Download page.** The download hero is the home hero's banner with a row of download buttons, one
per archive, each naming its system and, beneath, its architecture and size; on a phone they fill the
row. Install steps are bordered sections that become tabs with a raised selected tab when the script
runs. A three-column row of next steps closes the page and stacks on a phone.

**Code blocks.** Painted Pudu and shell share the playground's `tok-*` colours. A block's copy
button sits in its top-left corner, across from the language label, and stays hidden until the
script enables it.

**Avatars.** While an owner's image is present, its avatar is a neutral square rather than the
two-tone mark, so the mark appears only when there is no image or it failed.

**Package pages at any width.** Below 900px the overview's two columns stack and stretch to the
page, so a README's table, code block, or long word scrolls or wraps inside its own box instead of
widening the page. README images never exceed their column, `md-align-left|center|right` align what
a README centred in HTML, and long unbroken words wrap. The install panel's command rows keep their
copy button on screen, and its version row wraps. Nothing on a package page may widen the page from
280px (a folded phone's cover screen) through phones, unfolded foldables, and tablets; the website
suite asserts the rules that guarantee it.

**Package search box.** A drawn magnifier, a `/` key hint hidden while focused, a `?` query-forms
disclosure, a filter chip in ink, and a suggestion box anchored to the form with section headings,
highlighted matches, a visible selection, key hints on the selected row, and loading, empty, and error
messages. At phone width suggestion rows drop their meta column and the help disclosure hides.

Data lists have distinct loading, empty, and loaded presentations: a live spinner beside the
next-page action, a dashed empty banner on paper, and regular list rows. On narrow screens the install
disclosure is fixed within the viewport; on short screens the native summary remains visible as a
close control above a full-height scrollable panel.

Defines the local Nunito family, responsive documentation layout,
mobile disclosure navigation, code surfaces, result density, and footer. It reserves visible focus,
44-pixel interactive targets, readable line lengths, text zoom, reduced-motion preference, and
high-contrast behavior.
The home search keeps a compact lower margin so the first API guidance remains visually connected
to the query field on desktop and mobile.
Symbol details use compact declaration cards with visible heading hierarchy, readable signature
guidance, and touch-safe module/search actions. The cards retain strong borders in forced-colour mode.
The home page places the shape example beside its explanation and gives the module list a row of its
own as a wrapping grid (`repeat(auto-fill, minmax(200px, 1fr))`) whose names wrap rather than
overflow; side by side, the short example left its column mostly empty and long module names ran out
of a 280-pixel panel. Documentation pages use a sidebar, article, and contents grid that drops the
contents below 1100 pixels and stacks below 760, where the sidebar is replaced by a closed disclosure.
Code blocks use the `--code` surface (`#f2f5ff`) with dark ink, a hairline border, and a language label
in the corner, and scroll horizontally inside themselves; a table cell holding only code does not wrap
it on a wide screen, and on a phone may wrap so the prose column beside it keeps its width. Documentation metadata is a two-column definition list that stacks on a phone. The library index
uses rounded section links and one table per section with child modules separated by middle dots.

A code block with a language label starts its first line below the label, so a long first line is
never covered by it. Prose in a document or a chapter wraps an unbroken word, such as a path joined
with slashes, instead of widening the page. Inline code in API summaries and declaration text takes
the documentation's inline-code style. The home hero's pill and action row carry selectors specific
enough to outrank `.intro p{margin:0}`, which had set both flush against their neighbours. The
footer relies on the page shell's bottom padding rather than adding a margin of its own, and its
bottom links wrap on a 320-pixel screen.

The playground toolbar shares the masthead's side padding (20 pixels, 16 on a phone), so the Run
button lines up with the logo. The diagnostics status is the row's flexible space: it takes what the
controls leave, right-aligned, and shortens with an ellipsis rather than pushing a control onto a
new row. Below 1024 pixels the keyboard hint on Run is left to the Help panel and the button's title,
and the example menu narrows to 170 pixels; on a phone the toolbar is two rows.

Measured at 320, 375, 768, 1024, and 1440 pixels on every page: no page overflows horizontally, and
the playground toolbar is one row from 761 pixels up.

## Grill Log

- **Q:** Keep the gradient banner? **A:** Yes, as every page's header, and nothing else decorated.
  _Rationale:_ the owner chose the banner; confining decoration to it keeps the rest of each page
  plain type, ledgers, and rules.
- **Q:** Warm cream or the logo's soft blue for surfaces? **A:** The soft blue of the `P`.
  _Rationale:_ the owner chose it; it ties every surface to the mark readers already know.
- **Q:** Where does colour come from? **A:** The banner, the `P`'s soft blue on surfaces, and the
  logo's four two-tone pairs for owner marks and section-label rules. _Rationale:_ one recognisable
  source of colour; links and focus remain the only saturated blue in page content.
- **Q:** Primary buttons in blue? **A:** No, in ink. _Rationale:_ blue already means "link"; a dark
  button reads as the one action without competing with inline links.

Resolved Grill Log: the mobile menu is CSS plus native HTML disclosure, not a hidden checkbox or
script-only control. Desktop and mobile navigation are mutually hidden from both layout and the
accessibility tree, and no viewport gains horizontal overflow at 200 percent text zoom.

Text is set in Nunito, served as WOFF2 (44 KiB a face, against 130 KiB as TrueType), with the regular and bold faces preloaded from every page's head. Until they arrive a `Nunito Fallback` face draws local Arial (or Helvetica, or Roboto) scaled and with its ascent and descent overridden to Nunito's measured metrics — size-adjust 102.38% regular and 97.85% bold, taken from each face's advance widths over English letter frequencies — so the swap moves no line: measured on the home page, a chapter, and the playground at 412 and 1350 pixels, every heading, paragraph, toolbar, and pane is at the same place in both faces. The masthead logo is a 336×112 WebP (6 KiB) whose markup states 168×56 for its aspect ratio and which the stylesheet draws 132 pixels wide; the footer mark is 68×65 WebP; the icon is a 64-pixel PNG with a 180-pixel touch icon; link previews get a 1200×630 card. The original logo PNGs stay as the brand page's source art.
