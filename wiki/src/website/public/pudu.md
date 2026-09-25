---
type: module
path: "@root/website/public/assets/pudu/main.js"
fidelity: Active
tags: [website, frontend, motion, asset]
aliases: [Pudu mascot script]
---
# Pudu Mascot Script

A pudu lives behind a page's banner and peeks over its top edge. [[website View Pudu]] renders an
empty stage before the banner, one layer below it, naming a mode; this script draws the pudu into
the stage and performs that mode. The opaque banner hides whatever sits under its edge, so hiding is
stacking: no mask follows the banner's radius or padding. Only the two front hooves are drawn on a
second stage above the banner: at full height they hook over its edge, with a soft contact shadow on
the banner, which is what makes the pudu read as standing behind the banner rather than floating
over the page. They let go before every descent.

The drawing speaks the logo's language: round geometric shapes, each split at the centre into a
darker left and a lighter right half, in the logo's warm `--tone-1` pair. It is a small, young
pudu: a round head, broad ears set low on the sides with the logo's pink inside, two short antler
nubs, large glossy eyes, pink cheeks, a pale muzzle with a dark nose and a small smile. Colours are
`--pudu-*` tokens in [[website stylesheet]].

## Layers

A lower layer never imports a higher one.

| Layer | Files | Owns |
| --- | --- | --- |
| config | `constants.js` | drawing geometry, poses, timings, radii, selectors |
| art | `drawing.js` | the SVG markup and the lookup of its moving parts |
| motion | `timing.js`, `moves.js` | promise-returning Web Animations, and the pudu's moves: rise, sink, grip, let go, look, follow, tilt, nod, blink, flick, sniff, droop, perk, widen, hop, exclaim, heart |
| stage | `place.js`, `visible.js` | spots along the edge clear of the rounded corners, and waiting while the page is hidden or the banner is off screen |
| modes | `blinking.js`, `roam.js`, `shy.js`, `ask.js` | blinks on their own clock, and one choreography per page purpose |
| root | `main.js` | finds stages, draws, chooses the mode, honours reduced motion |

## Modes

| Mode | Page | Behaviour |
| --- | --- | --- |
| `roam` | home | Enters by popping up, by peeking with its eyes first, or by popping up startled; looks around, tilts its head, blinks, flicks an ear, sniffs; sometimes does a double take; then ducks out of sight and comes up at a different spot. It moves only while fully hidden. |
| `shy` | missing page | Lost: it peeks with only its eyes, then rises; its face follows the pointer; a pointer or a tap within the startle radius sends it down, and it comes back at the spot farthest from the pointer, eyes first, rising only once the pointer keeps its distance. Left alone, it searches left and right. |
| `ask` | donation | Asks: ears drooped, head tilted, eyes wide, with an occasional nod or a glance toward the support link. When the link is hovered or focused it perks up, hops, and shows a heart. |

Short strokes in the site's blue (`--brand`) burst beside the head on a startle or a double take;
they are the only colour the pudu borrows from the page. Blinks run on their own clock in every mode. Under `prefers-reduced-motion: reduce` the pudu is drawn
once, at rest above the edge, and nothing moves. Without script the stage stays empty, and it is
decorative either way (`aria-hidden`).

## Grill Log

- **Q:** A self-animating SVG image, or script? **A:** Script with Web Animations. _Rationale:_ an
  image repeats one fixed loop at one spot; moving between spots, reacting to the pointer and to a
  link, and never repeating the same sequence needs decisions at run time. Each move returns a
  promise, so a choreography reads as the sequence it performs.
- **Q:** Why inline SVG? **A:** Every part is a separate element the moves address, coloured by
  stylesheet tokens, and the page makes one request for the script instead of a second for art.
- **Q:** How does the face turn without a 3D model? **A:** The outline stays and the face group
  (eyes, cheeks, muzzle, nose, mouth) slides toward the look, with a slight tilt of the head: the eye reads
  it as a turn.
- **Q:** A realistic deer, or the round young pudu? **A:** The round young pudu. _Rationale:_ an
  anatomical head with a long face read as a stock illustration beside the logo's soft letters; the
  round head, large eyes, and cheeks carry the site's friendliness, and the nubs and low ears still
  say pudu.
- **Q:** Can the missing page's search hold off a startle? **A:** No. Searching and hiding are
  separate states; a pointer arriving mid-search still sends the pudu down, and only following the
  pointer waits for the search to end.
- **Q:** May the pudu travel with part of it showing? **A:** No. _Rationale:_ a sliver of antler
  gliding along the edge read as a drawing error, not as sneaking; the pudu is either peeking or
  gone, and it changes spots only while hidden.
- **Q:** Why a front layer only for the hooves? **A:** Contact. _Rationale:_ with everything behind
  the banner, the head sat on the edge like a sticker; hooves over the edge and their shadow on the
  banner place the pudu in the same space as the banner, for two small shapes.
- **Q:** What moves on the compositor? **A:** The rise, the duck, and the hop move an HTML box
  holding the drawing, in percentages of its own height. _Rationale:_ WebKit, which every iPhone
  browser uses, repaints an SVG group's transform on every frame, and the stutter showed on
  phones; parts inside the drawing only turn, tilt, blink, and twitch.
- **Q:** Smooth the pointer-follow with a CSS transition? **A:** No. _Rationale:_ when an animation
  commits its end pose to a part that has a transition, WebKit may start the transition again from
  the old pose, which reads as a hitch. Following is a short animation that replaces the previous
  one, and a look commits where the follow got to before starting.
- **Q:** Why pause off screen? **A:** A choreography waits before each act while the tab is hidden or
  the banner is scrolled away, so the page spends nothing on a pudu no one sees.
- **Q:** Why a larger gap above page banners that carry one? **A:** The pudu needs about 55px above
  the edge; a reference page's banner sits 36px under the masthead, so a stage adds its own margin.

See [[website View Pudu]].
