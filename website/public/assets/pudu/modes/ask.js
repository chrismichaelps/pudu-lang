// The donation page: the pudu asks. Ears drooped, head tilted, eyes wide, it
// nods or glances toward the support link now and then; when the link is
// hovered or focused it perks up, hops, and shows a heart.

import { ASK, ASK_TILT, POSE, TIMING } from "../config/constants.js";
import { droop, heart, hold, hop, look, nod, perk, relaxEars, rise, tilt, widen } from "../motion/moves.js";
import { between, pick, wait } from "../motion/timing.js";
import { centre, place, spotAt } from "../stage/place.js";
import { blinking } from "./blinking.js";

async function plead(pudu) {
  await Promise.all([droop(pudu), tilt(pudu, ASK_TILT), widen(pudu), look(pudu, 0)]);
}

async function glanceAt(pudu, target) {
  const at = centre(pudu);
  const box = target.getBoundingClientRect();
  await look(pudu, Math.sign(box.left + box.width / 2 - at.x));
  await wait(ASK.hold);
  await Promise.all([look(pudu, 0), tilt(pudu, ASK_TILT)]);
}

export async function ask(pudu, target) {
  let happy = false;

  const cheer = async () => {
    if (happy) return;
    happy = true;
    await Promise.all([perk(pudu), tilt(pudu, 0), widen(pudu, 1.05), look(pudu, 0)]);
    heart(pudu);
    await hop(pudu);
    await hop(pudu, 6);
  };
  const settle = async () => {
    if (!happy) return;
    happy = false;
    await relaxEars(pudu);
    await plead(pudu);
  };

  if (target !== null) {
    target.addEventListener("pointerenter", cheer);
    target.addEventListener("focus", cheer);
    target.addEventListener("pointerleave", settle);
    target.addEventListener("blur", settle);
    target.addEventListener("click", () => heart(pudu));
  }

  place(pudu, spotAt(pudu, ASK.spotShare));
  hold(pudu, POSE.hidden);
  blinking(pudu, 1.4);
  await wait(ASK.firstEntrance);
  await rise(pudu, POSE.up, TIMING.riseSlow);
  await plead(pudu);

  for (;;) {
    await wait(between(ASK.gestureMin, ASK.gestureMax));
    await pudu.visible();
    if (happy) continue;
    const asking = (it) => nod(it, ASK_TILT);
    const gestures = target === null ? [asking] : [asking, (it) => glanceAt(it, target)];
    await pick(gestures)(pudu);
  }
}
