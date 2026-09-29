// Where along the banner's edge the pudu may stand, in pixels from the
// stage's left side.

import { EDGE_CLEARANCE, HERD_GAP, SPOT_SPREAD, SPOT_TRIES } from "../config/constants.js";
import { between } from "../motion/timing.js";

// Pixels between the spots a scan of the edge tries.
const SCAN_STEP = 4;

export function range(pudu) {
  const low = EDGE_CLEARANCE;
  const high = Math.max(low, pudu.stage.clientWidth - pudu.actor.offsetWidth - EDGE_CLEARANCE);
  return { low, high };
}

/// How far `x` keeps the pudu from the nearest other pudu of its herd beyond
/// the gap they need, in pixels; negative when they would overlap, and
/// unbounded for a pudu alone.
export function roomAt(pudu, x) {
  const width = pudu.actor.offsetWidth;
  let room = Infinity;
  for (const other of pudu.herd ?? []) {
    if (other === pudu) continue;
    const apart = Math.abs(x + width / 2 - (other.x + other.actor.offsetWidth / 2));
    room = Math.min(room, apart - (width + other.actor.offsetWidth) / 2 - HERD_GAP);
  }
  return room;
}

/// A random spot clear of the rest of the herd and well away from `avoid`
/// when there is room for that. When chance finds none, the edge is scanned
/// for one; a crowded edge with no clear spot keeps the pudu where it is, so
/// two pudus never overlap.
export function spot(pudu, avoid = null) {
  const { low, high } = range(pudu);
  const spread = (high - low) * SPOT_SPREAD;
  const far = (x) => avoid === null || Math.abs(x - avoid) >= spread;
  for (let tries = 0; tries < SPOT_TRIES; tries += 1) {
    const candidate = between(low, high);
    if (roomAt(pudu, candidate) >= 0 && far(candidate)) return candidate;
  }
  const clear = [];
  for (let x = low; x <= high; x += SCAN_STEP) if (roomAt(pudu, x) >= 0) clear.push(x);
  const distant = clear.filter(far);
  if (distant.length > 0) return distant[Math.floor(Math.random() * distant.length)];
  if (clear.length > 0) return clear[Math.floor(Math.random() * clear.length)];
  return avoid ?? low;
}

/// Lays a herd out along the edge at even steps, the big pudu at a random
/// place among them, so every pudu starts clear of the others.
export function layOut(herd) {
  const order = herd.slice(1);
  order.splice(Math.floor(Math.random() * herd.length), 0, herd[0]);
  const widths = order.reduce((sum, member) => sum + member.actor.offsetWidth, 0);
  const { low } = range(herd[0]);
  const span = herd[0].stage.clientWidth - 2 * low;
  const step = order.length > 1 ? (span - widths) / (order.length - 1) : 0;
  let x = order.length > 1 ? low : spotAt(herd[0], between(0, 1));
  for (const member of order) {
    place(member, x);
    x += member.actor.offsetWidth + step;
  }
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
