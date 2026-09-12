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

Resolved Grill Log: the mobile menu is CSS plus native HTML disclosure, not a hidden checkbox or
script-only control. Desktop and mobile navigation are mutually hidden from both layout and the
accessibility tree, and no viewport gains horizontal overflow at 200 percent text zoom.
