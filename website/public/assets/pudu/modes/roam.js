// The home banner: the pudu turns up somewhere along the edge, looks about,
// and ducks out of sight; it moves to its next spot only while hidden.

import { CURIOUS_TILT, POSE, ROAM, TIMING } from "../config/constants.js";
import { exclaim, flick, hold, look, rise, sink, sniff, tilt } from "../motion/moves.js";
import { between, chance, pick, wait } from "../motion/timing.js";
import { place, spot } from "../stage/place.js";
import { blinking } from "./blinking.js";

const holdLook = () => wait(between(ROAM.holdMin, ROAM.holdMax));

const BEATS = [
  async (pudu) => {
    await look(pudu, -1);
    await holdLook();
  },
  async (pudu) => {
    await look(pudu, 1);
    await holdLook();
  },
  async (pudu) => {
    await look(pudu, 0);
    await holdLook();
  },
  async (pudu) => {
    await tilt(pudu, pick([CURIOUS_TILT, -CURIOUS_TILT]));
    await holdLook();
    await tilt(pudu, 0);
  },
  (pudu) => flick(pudu, pick(["left", "right"])),
  (pudu) => sniff(pudu),
];

async function beats(pudu) {
  const count = Math.round(between(ROAM.beatsMin, ROAM.beatsMax));
  let last = null;
  for (let index = 0; index < count; index += 1) {
    let beat = pick(BEATS);
    while (beat === last) beat = pick(BEATS);
    last = beat;
    await beat(pudu);
  }
  await look(pudu, 0);
}

const ENTRANCES = [
  (pudu) => rise(pudu),
  async (pudu) => {
    await rise(pudu, POSE.eyes, TIMING.riseSlow);
    await look(pudu, -1);
    await holdLook();
    await look(pudu, 1);
    await holdLook();
    await look(pudu, 0);
    await rise(pudu);
  },
  async (pudu) => {
    await rise(pudu, POSE.up, TIMING.rise * 0.6);
    await exclaim(pudu);
  },
];

async function doubleTake(pudu) {
  await sink(pudu, POSE.hidden, TIMING.duckFast);
  await wait(between(420, 680));
  await rise(pudu, POSE.up, TIMING.rise * 0.7);
  exclaim(pudu);
  await flick(pudu, "left");
  await wait(between(700, 1000));
}

export async function roam(pudu) {
  hold(pudu, POSE.hidden);
  place(pudu, spot(pudu));
  blinking(pudu);
  await wait(ROAM.firstEntrance);
  for (;;) {
    await pudu.visible();
    await pick(ENTRANCES)(pudu);
    await beats(pudu);
    if (chance(ROAM.doubleTake)) await doubleTake(pudu);
    await sink(pudu);
    await wait(between(ROAM.hiddenMin, ROAM.hiddenMax));
    place(pudu, spot(pudu, pudu.x));
  }
}
