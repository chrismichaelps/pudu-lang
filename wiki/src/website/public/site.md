---
type: stylesheet
path: "@root/website/public/site.css"
fidelity: Active
tags: [website, css, responsive, accessibility]
aliases: [website stylesheet]
---
# Website Stylesheet

Defines the white, Pudu-blue visual system, local Nunito family, responsive documentation layout,
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

Resolved Grill Log: the mobile menu is CSS plus native HTML disclosure, not a hidden checkbox or
script-only control. Desktop and mobile navigation are mutually hidden from both layout and the
accessibility tree, and no viewport gains horizontal overflow at 200 percent text zoom.

Text is set in Nunito, served as WOFF2 (44 KiB a face, against 130 KiB as TrueType), with the regular and bold faces preloaded from every page's head. Until they arrive a `Nunito Fallback` face draws local Arial (or Helvetica, or Roboto) scaled and with its ascent and descent overridden to Nunito's measured metrics — size-adjust 102.38% regular and 97.85% bold, taken from each face's advance widths over English letter frequencies — so the swap moves no line: measured on the home page, a chapter, and the playground at 412 and 1350 pixels, every heading, paragraph, toolbar, and pane is at the same place in both faces. The masthead logo is a 336×112 WebP (6 KiB) drawn at 168×56 with its size in the markup; the footer mark is 68×65 WebP; the icon is a 64-pixel PNG with a 180-pixel touch icon; link previews get a 1200×630 card. The original logo PNGs stay as the brand page's source art.
