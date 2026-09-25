// The missing page: a lost pudu. It peeks with only its eyes before rising,
// its face follows the pointer, and a pointer or a tap that comes close sends
// it down to reappear at the far end of the edge. Left alone, it searches.

import { POSE, SHY, TIMING } from "../config/constants.js";
import { exclaim, flick, follow, hold, look, rise, sink, sniff } from "../motion/moves.js";
import { between, wait } from "../motion/timing.js";
import { centre, farthestFrom, place, spot } from "../stage/place.js";
import { blinking } from "./blinking.js";

export async function shy(pudu) {
  let pointer = null;
  let lastMove = performance.now();
  let up = false;
  let hiding = false;
  let searching = false;

  const distance = () => {
    if (pointer === null) return Infinity;
    const at = centre(pudu);
    return Math.hypot(pointer.x - at.x, pointer.y - at.y);
  };

  const emerge = async () => {
    await rise(pudu, POSE.eyes, TIMING.riseSlow);
    let calmSince = performance.now();
    while (performance.now() - calmSince < SHY.calmFor) {
      await wait(SHY.tick);
      if (distance() < SHY.calmRadius) calmSince = performance.now();
    }
    await rise(pudu);
    up = true;
  };

  const startle = async () => {
    hiding = true;
    up = false;
    exclaim(pudu);
    flick(pudu, "left");
    flick(pudu, "right");
    await sink(pudu, POSE.hidden, TIMING.duckFast);
    await wait(between(SHY.awayMin, SHY.awayMax));
    place(pudu, pointer === null ? spot(pudu, pudu.x) : farthestFrom(pudu, pointer.x));
    await pudu.visible();
    await emerge();
    hiding = false;
  };

  const react = (event) => {
    pointer = { x: event.clientX, y: event.clientY };
    lastMove = performance.now();
    if (!up || hiding) return;
    if (distance() < SHY.startleRadius) {
      startle();
      return;
    }
    if (searching) return;
    const at = centre(pudu);
    follow(pudu, Math.max(-1, Math.min(1, (pointer.x - at.x) / SHY.lookReach)));
  };

  window.addEventListener("pointermove", react, { passive: true });
  window.addEventListener("pointerdown", react, { passive: true });

  hold(pudu, POSE.hidden);
  place(pudu, spot(pudu));
  blinking(pudu);
  await wait(TIMING.rise);
  hiding = true;
  await emerge();
  hiding = false;

  for (;;) {
    await wait(SHY.tick);
    await pudu.visible();
    if (!up || hiding || performance.now() - lastMove < SHY.idleBeforeSearch) continue;
    searching = true;
    await look(pudu, -1);
    await wait(between(500, 800));
    await look(pudu, 1);
    await wait(between(500, 800));
    await sniff(pudu);
    await look(pudu, 0);
    lastMove = performance.now();
    searching = false;
  }
}
