// The pudu, drawn in the logo's language: round shapes split at the centre
// into a darker left half and a lighter right half. Classes name the parts
// the moves address and the colour tokens the stylesheet fills them with.
// The drawing sits in an HTML `pudu-body`, which is what rises and ducks:
// an HTML transform runs on the compositor, where moving an SVG group
// repaints the drawing on every frame.

const RIGHT_HALF = 'clip-path="url(#pudu-right-half)"';

const HEART =
  "M152 50C141 43 138 35 144 31C148 28 151 30 152 34C153 30 156 28 160 31C166 35 163 43 152 50Z";

const eye = (x) => `<g class="pudu-eye-wide"><g class="pudu-eye">
  <circle class="pudu-ink" cx="${x}" cy="88.75" r="5.6"/>
  <circle class="pudu-shine" cx="${x + 2}" cy="86.6" r="1.8"/>
  <circle class="pudu-shine pudu-shine-soft" cx="${x - 1.9}" cy="91.2" r=".85"/>
</g></g>`;

const twoTone = (shape, dark, light) => `${shape.replace("/>", ` class="${dark}"/>`)}
  ${shape.replace("/>", ` class="${light}" ${RIGHT_HALF}/>`)}`;

export const DRAWING = `<svg viewBox="0 0 200 150" focusable="false">
<defs><clipPath id="pudu-right-half"><rect x="100" y="-60" width="160" height="280"/></clipPath></defs>
<g class="pudu-heart"><path class="pudu-heart-fill" d="${HEART}"/></g>
<g class="pudu-head">
  ${twoTone('<rect x="77.5" y="107.5" width="45" height="88" rx="20"/>', "pudu-fur", "pudu-fur-light")}
  <g class="pudu-ear pudu-ear-left">
    <ellipse class="pudu-fur" cx="57.5" cy="75" rx="21" ry="12.5" transform="rotate(-28 57.5 75)"/>
    <ellipse class="pudu-ear-inner" cx="58.8" cy="75" rx="12.5" ry="6.3" transform="rotate(-28 58.8 75)"/>
  </g>
  <g class="pudu-ear pudu-ear-right">
    <ellipse class="pudu-fur-light" cx="142.5" cy="75" rx="21" ry="12.5" transform="rotate(28 142.5 75)"/>
    <ellipse class="pudu-ear-inner" cx="141.2" cy="75" rx="12.5" ry="6.3" transform="rotate(28 141.2 75)"/>
  </g>
  <rect class="pudu-antler" x="83.8" y="50" width="8.8" height="17.5" rx="4.4" transform="rotate(-12 88.1 58.8)"/>
  <rect class="pudu-antler-light" x="107.5" y="50" width="8.8" height="17.5" rx="4.4" transform="rotate(12 111.9 58.8)"/>
  ${twoTone('<rect x="62.5" y="60" width="75" height="67.5" rx="33.75"/>', "pudu-fur", "pudu-fur-light")}
  <g class="pudu-marks">
    <path d="M147 62L157 53"/><path d="M152 75L164 72"/><path d="M53 62L43 53"/><path d="M48 75L36 72"/>
  </g>
  <g class="pudu-face">
    ${eye(83.75)}
    ${eye(116.25)}
    <ellipse class="pudu-cheek" cx="75" cy="102.5" rx="6.25" ry="3.75"/>
    <ellipse class="pudu-cheek" cx="125" cy="102.5" rx="6.25" ry="3.75"/>
    ${twoTone('<ellipse cx="100" cy="110" rx="18.75" ry="13.75"/>', "pudu-muzzle", "pudu-muzzle-light")}
    <g class="pudu-nose">
      <ellipse class="pudu-ink" cx="100" cy="104.4" rx="6.9" ry="4.75"/>
      <ellipse class="pudu-shine pudu-nose-shine" cx="97.6" cy="103" rx="2.2" ry="1.1"/>
    </g>
    <path class="pudu-mouth" d="M95 119.4Q100 123.1 105 119.4"/>
  </g>
</g>
</svg>`;

const hoof = (leg, tone) => `<g class="pudu-hoof">
  <ellipse class="pudu-contact" cx="${leg + 8}" cy="136.5" rx="10" ry="2.6"/>
  <rect class="pudu-${tone}" x="${leg}" y="110" width="16" height="22" rx="8"/>
  <rect class="pudu-hoof-${tone}" x="${leg - 1}" y="124" width="18" height="12" rx="5.5"/>
  <path class="pudu-toe" d="M${leg + 8} 127V135"/>
</g>`;

// The front hooves hook over the banner's edge, so they are drawn on a layer
// above the banner; everything else stays behind it.
export const FRONT = `<svg viewBox="0 0 200 150" focusable="false">
<g class="pudu-hooves">${hoof(65, "fur")}${hoof(119, "fur-light")}</g>
</svg>`;

/// Draws the pudu into `actor` and its hooves into `front`, and returns the
/// parts the moves address.
export function draw(actor, front) {
  actor.innerHTML = `<div class="pudu-body">${DRAWING}</div>`;
  front.innerHTML = FRONT;
  const part = (name) => actor.querySelector(`.pudu-${name}`);
  return {
    hooves: front.querySelector(".pudu-hooves"),
    marks: part("marks"),
    body: part("body"),
    head: part("head"),
    face: part("face"),
    nose: part("nose"),
    heart: part("heart"),
    earLeft: part("ear-left"),
    earRight: part("ear-right"),
    eyes: [...actor.querySelectorAll(".pudu-eye")],
    wideEyes: [...actor.querySelectorAll(".pudu-eye-wide")],
  };
}
