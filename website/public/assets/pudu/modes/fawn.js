// A little pudu beside the big one on the home banner. It keeps its own clock:
// it pops up or peeks with its eyes first, glances at its nearest companion,
// looks about, and ducks away; it changes spots only while hidden.

import { CURIOUS_TILT, FAWNS, POSE, TIMING } from "../config/constants.js";
import { flick, hold, hop, look, rise, sink, sniff, tilt } from "../motion/moves.js";
import { between, chance, pick, wait } from "../motion/timing.js";
import { nearest, toward } from "../stage/herd.js";
import { place, spot } from "../stage/place.js";
import { blinking } from "./blinking.js";

const holdLook = () => wait(between(FAWNS.holdMin, FAWNS.holdMax));

async function glance(pudu) {
  const companion = nearest(pudu);
  await look(pudu, companion === null ? pick([-1, 1]) : toward(pudu, companion));
  await holdLook();
}

const BEATS = [
  glance,
  async (pudu) => {
    await look(pudu, pick([-1, 1]));
    await holdLook();
  },
  async (pudu) => {
    await tilt(pudu, pick([CURIOUS_TILT, -CURIOUS_TILT]));
    await holdLook();
    await tilt(pudu, 0);
  },
  (pudu) => flick(pudu, pick(["left", "right"])),
  (pudu) => sniff(pudu),
  async (pudu) => {
    if (chance(FAWNS.hop)) await hop(pudu, 8);
    else await holdLook();
  },
];

async function entrance(pudu) {
  if (!chance(FAWNS.peek)) return rise(pudu, POSE.up, TIMING.rise * 0.8);
  await rise(pudu, POSE.eyes, TIMING.riseSlow);
  await glance(pudu);
  await look(pudu, 0);
  await rise(pudu);
}

export async function fawn(pudu) {
  hold(pudu, POSE.hidden);
  blinking(pudu, FAWNS.blinkPace);
  await wait(between(FAWNS.firstMin, FAWNS.firstMax));
  for (;;) {
    await pudu.visible();
    await entrance(pudu);
    const count = Math.round(between(FAWNS.beatsMin, FAWNS.beatsMax));
    let last = null;
    for (let index = 0; index < count; index += 1) {
      let beat = pick(BEATS);
      while (beat === last) beat = pick(BEATS);
      last = beat;
      await beat(pudu);
    }
    await look(pudu, 0);
    await sink(pudu, POSE.hidden, TIMING.duckFast);
    await wait(between(FAWNS.hiddenMin, FAWNS.hiddenMax));
    place(pudu, spot(pudu, pudu.x));
  }
}
