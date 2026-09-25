// The pudu's moves. Each takes the pudu and settles when the move is done;
// the body's offset is in drawing units below the resting pose.

import {
  CURIOUS_TILT,
  EAR,
  EASE,
  EYE_WIDE,
  FACE_TURN,
  GRIP_AT,
  LOOK_TILT,
  POSE,
  TIMING,
  VIEW_HEIGHT,
} from "../config/constants.js";
import { play, to, wait } from "./timing.js";

// The body is an HTML box one drawing tall, so an offset in drawing units is
// a percentage of its own height.
const lift = (offset) => `translateY(${(offset * 100) / VIEW_HEIGHT}%)`;
const ears = (pudu, left, duration, easing) =>
  Promise.all([
    to(pudu.parts.earLeft, `rotate(${left}deg)`, duration, easing),
    to(pudu.parts.earRight, `rotate(${-left}deg)`, duration, easing),
  ]);

/// Sets the body at `offset` at once.
export function hold(pudu, offset) {
  pudu.parts.body.style.transform = lift(offset);
}

/// The hooves come up from behind and settle over the banner's edge.
export function grip(pudu) {
  if (pudu.gripping) return Promise.resolve();
  pudu.gripping = true;
  return play(
    pudu.parts.hooves,
    [
      { opacity: 0, transform: "translateY(-8px) scaleY(.85)" },
      { opacity: 1, transform: "translateY(1.5px) scaleY(.94)", offset: 0.7 },
      { opacity: 1, transform: "none" },
    ],
    { duration: TIMING.grip, easing: EASE.out },
  );
}

/// The hooves lift off the edge and drop out of sight behind it.
export function letGo(pudu) {
  if (!pudu.gripping) return Promise.resolve();
  pudu.gripping = false;
  return play(pudu.parts.hooves, [{ opacity: 1, transform: "none" }, { opacity: 0, transform: "translateY(-6px)" }], {
    duration: TIMING.letGo,
    easing: EASE.in,
  });
}

/// Rises to `offset` from wherever the body is, overshooting a little; at
/// the full height the hooves reach over the edge on the way up.
export async function rise(pudu, offset = POSE.up, duration = TIMING.rise) {
  const body = play(pudu.parts.body, [{ transform: lift(offset - 6), offset: 0.72 }, { transform: lift(offset) }], {
    duration,
    easing: EASE.out,
  });
  if (offset !== POSE.up) return body;
  await wait(duration * GRIP_AT);
  await Promise.all([body, grip(pudu)]);
}

/// Lets go of the edge and sinks to `offset`, out of sight by default.
export async function sink(pudu, offset = POSE.hidden, duration = TIMING.duck) {
  await letGo(pudu);
  await to(pudu.parts.body, lift(offset), duration, EASE.in);
}

/// Short strokes in the site's blue burst from beside the head: surprise.
export function exclaim(pudu) {
  return play(
    pudu.parts.marks,
    [
      { opacity: 0, transform: "scale(.6)" },
      { opacity: 1, transform: "scale(1)", offset: 0.3 },
      { opacity: 0, transform: "scale(1.18)" },
    ],
    { duration: TIMING.marks, easing: EASE.out },
  );
}

/// Two small nods, keeping whatever tilt the head has.
export function nod(pudu, tilt = 0) {
  const at = (drop) => ({ transform: `rotate(${tilt}deg) translateY(${drop}px)` });
  return play(pudu.parts.head, [at(0), at(4), at(0), at(3), at(0)], { duration: TIMING.nod, easing: EASE.inOut });
}

/// Turns the face toward `direction`, from -1 (left) to 1 (right).
export function look(pudu, direction, duration = TIMING.look) {
  stopFollowing(pudu);
  return Promise.all([
    to(pudu.parts.face, `translateX(${direction * FACE_TURN}px)`, duration, EASE.inOut),
    to(pudu.parts.head, `rotate(${direction * LOOK_TILT}deg)`, duration, EASE.inOut),
  ]);
}

/// Eases toward a direction, replacing the previous follow rather than
/// queueing behind it, so a stream of pointer moves stays one motion.
export function follow(pudu, direction) {
  stopFollowing(pudu);
  const options = { duration: TIMING.follow, easing: EASE.out, fill: "forwards" };
  pudu.following = [
    pudu.parts.face.animate([{ transform: `translateX(${direction * FACE_TURN}px)` }], options),
    pudu.parts.head.animate([{ transform: `rotate(${direction * LOOK_TILT}deg)` }], options),
  ];
}

/// Keeps where a follow has got to and ends it, so a later move starts from
/// that pose instead of being overridden by a lingering fill.
function stopFollowing(pudu) {
  for (const running of pudu.following ?? []) {
    running.commitStyles();
    running.cancel();
  }
  pudu.following = [];
}

/// Tilts the head, the way an animal listens.
export function tilt(pudu, degrees = CURIOUS_TILT, duration = TIMING.look) {
  return to(pudu.parts.head, `rotate(${degrees}deg)`, duration, EASE.inOut);
}

export function blink(pudu) {
  return Promise.all(
    pudu.parts.eyes.map((eye) =>
      play(eye, [{ transform: "scaleY(1)" }, { transform: "scaleY(.1)" }, { transform: "scaleY(1)" }], {
        duration: TIMING.blink,
      }),
    ),
  );
}

/// One ear twitches up and settles back where it was.
export function flick(pudu, side = "left") {
  const ear = side === "left" ? pudu.parts.earLeft : pudu.parts.earRight;
  const sign = side === "left" ? 1 : -1;
  return ear.animate(
    [{ transform: `rotate(${sign * EAR.flick}deg)`, offset: 0.35 }, { transform: `rotate(${-sign * 4}deg)`, offset: 0.7 }, {}],
    { duration: TIMING.flick, easing: EASE.out, composite: "add" },
  ).finished;
}

export function sniff(pudu) {
  return play(
    pudu.parts.nose,
    [{ transform: "scale(1)" }, { transform: "scale(1.14,1.08)" }, { transform: "scale(1)" }, { transform: "scale(1.12,1.06)" }, { transform: "scale(1)" }],
    { duration: TIMING.sniff },
  );
}

export function droop(pudu, duration = TIMING.look) {
  return ears(pudu, EAR.droop, duration, EASE.inOut);
}

export function perk(pudu, duration = TIMING.look) {
  return ears(pudu, EAR.perk, duration, EASE.spring);
}

export function relaxEars(pudu, duration = TIMING.look) {
  return ears(pudu, 0, duration, EASE.inOut);
}

export function widen(pudu, scale = EYE_WIDE, duration = TIMING.look) {
  return Promise.all(pudu.parts.wideEyes.map((eye) => to(eye, `scale(${scale})`, duration, EASE.inOut)));
}

/// A small jump from the resting pose and back.
export function hop(pudu, height = 10) {
  return play(
    pudu.parts.body,
    [{ transform: lift(POSE.up) }, { transform: lift(-height), offset: 0.4, easing: EASE.in }, { transform: lift(POSE.up) }],
    { duration: TIMING.hop, easing: EASE.out },
  );
}

/// A heart rises from beside the head and fades.
export function heart(pudu) {
  return play(
    pudu.parts.heart,
    [
      { opacity: 0, transform: "translateY(8px) scale(.5)" },
      { opacity: 1, transform: "translateY(-6px) scale(1)", offset: 0.25 },
      { opacity: 1, transform: "translateY(-14px) scale(1)", offset: 0.7 },
      { opacity: 0, transform: "translateY(-24px) scale(.9)" },
    ],
    { duration: TIMING.heart, easing: EASE.out },
  );
}
