// Where along the banner's edge the pudu may stand, in pixels from the
// stage's left side.

import { EDGE_CLEARANCE, SPOT_SPREAD, SPOT_TRIES } from "../config/constants.js";
import { between } from "../motion/timing.js";

export function range(pudu) {
  const low = EDGE_CLEARANCE;
  const high = Math.max(low, pudu.stage.clientWidth - pudu.actor.offsetWidth - EDGE_CLEARANCE);
  return { low, high };
}

/// A random spot, well away from `avoid` when there is room for that.
export function spot(pudu, avoid = null) {
  const { low, high } = range(pudu);
  const spread = (high - low) * SPOT_SPREAD;
  let candidate = between(low, high);
  for (let tries = 0; avoid !== null && Math.abs(candidate - avoid) < spread && tries < SPOT_TRIES; tries += 1) {
    candidate = between(low, high);
  }
  return candidate;
}

/// The spot at `share` of the way along the edge.
export function spotAt(pudu, share) {
  const { low, high } = range(pudu);
  return low + (high - low) * share;
}

/// The spot farthest from a point given in page coordinates.
export function farthestFrom(pudu, clientX) {
  const { low, high } = range(pudu);
  const left = pudu.stage.getBoundingClientRect().left;
  const away = Math.abs(clientX - (left + low)) > Math.abs(clientX - (left + high)) ? low : high;
  return away + (away === low ? 1 : -1) * between(0, (high - low) * 0.15);
}

/// Moves the pudu to `x` at once; call it only while it is hidden.
export function place(pudu, x) {
  pudu.x = x;
  pudu.actor.style.transform = `translateX(${x}px)`;
  pudu.front.style.transform = `translateX(${x}px)`;
}

/// Keeps the pudu on the edge when the stage narrows.
export function keepInside(pudu) {
  const { low, high } = range(pudu);
  if (pudu.x > high || pudu.x < low) place(pudu, Math.min(high, Math.max(low, pudu.x)));
}

/// The pudu's centre, in page coordinates.
export function centre(pudu) {
  const box = pudu.actor.getBoundingClientRect();
  return { x: box.left + box.width / 2, y: box.top + box.height / 2 };
}
