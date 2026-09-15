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
it. Documentation metadata is a two-column definition list that stacks on a phone. The library index
uses rounded section links and one table per section with child modules separated by middle dots. Measured at 1280 and 375 pixels: no page overflows horizontally and no module link
overflows its cell.

Resolved Grill Log: the mobile menu is CSS plus native HTML disclosure, not a hidden checkbox or
script-only control. Desktop and mobile navigation are mutually hidden from both layout and the
accessibility tree, and no viewport gains horizontal overflow at 200 percent text zoom.
