// The pudus that share one banner's edge: how many little ones the edge has
// room for, and which companion a pudu turns toward.

import { EDGE_CLEARANCE, FAWNS, HERD_GAP } from "../config/constants.js";

/// How many little pudus the edge holds beside a big one: enough to fill
/// `FAWNS.fill` of what the big one leaves, so there is always room left to
/// move into, and never more than `FAWNS.most`.
export function fawnsFor(stageWidth, bigWidth, littleWidth) {
  const free = stageWidth - 2 * EDGE_CLEARANCE - (bigWidth + HERD_GAP);
  return Math.max(0, Math.min(FAWNS.most, Math.floor((free / (littleWidth + HERD_GAP)) * FAWNS.fill)));
}

const middle = (pudu) => pudu.x + pudu.actor.offsetWidth / 2;

/// The other pudu of the herd nearest to `pudu`, or null for a pudu alone.
export function nearest(pudu) {
  let found = null;
  for (const other of pudu.herd ?? []) {
    if (other === pudu) continue;
    if (found === null || Math.abs(middle(other) - middle(pudu)) < Math.abs(middle(found) - middle(pudu))) found = other;
  }
  return found;
}

/// The look direction from `pudu` toward `other`: -1 for left, 1 for right.
export function toward(pudu, other) {
  return middle(other) < middle(pudu) ? -1 : 1;
}
