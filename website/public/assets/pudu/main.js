import { FAWNS, POSE, REDUCED_MOTION, SELECTOR } from "./config/constants.js";
import { draw } from "./art/drawing.js";
import { hold } from "./motion/moves.js";
import { fawnsFor } from "./stage/herd.js";
import { keepInside, layOut, place, roomAt, spotAt } from "./stage/place.js";
import { watchVisibility } from "./stage/visible.js";
import { ask } from "./modes/ask.js";
import { fawn } from "./modes/fawn.js";
import { roam } from "./modes/roam.js";
import { shy } from "./modes/shy.js";

const MODES = { roam, shy, ask };
const RESTING_SHARE = 0.72;

/// A pudu drawn into `stage`, its hooves on a front stage above the banner.
function create(stage, host, className, visible) {
  const actor = document.createElement("div");
  const front = document.createElement("div");
  const frontStage = document.createElement("div");
  actor.className = front.className = className;
  frontStage.className = SELECTOR.frontClass;
  stage.append(actor);
  frontStage.append(front);
  host.append(frontStage);
  return { stage, actor, front, x: 0, gripping: false, following: [], herd: [], parts: draw(actor, front), visible };
}

/// Draws a pudu at rest above the edge, for readers who ask for no motion.
function rest(pudu, x) {
  place(pudu, x);
  hold(pudu, POSE.up);
  pudu.parts.hooves.style.opacity = "1";
}

/// Rests little pudus left to right at the first spots clear of the others; one
/// with no clear spot left is not shown.
function restAlong(little) {
  for (const member of little) member.x = -Number.MAX_SAFE_INTEGER;
  let share = 0;
  for (const member of little) {
    while (share <= 1 && roomAt(member, spotAt(member, share)) < 0) share += FAWNS.restStep;
    if (share > 1) member.actor.style.display = member.front.style.display = "none";
    else rest(member, spotAt(member, share));
    share += FAWNS.restStep;
  }
}

for (const stage of document.querySelectorAll(SELECTOR.stage)) {
  const perform = MODES[stage.dataset.pudu];
  if (perform === undefined) continue;
  const host = stage.closest(SELECTOR.host) ?? stage.parentElement;
  const visible = watchVisibility(host);
  const pudu = create(stage, host, SELECTOR.actorClass, visible);
  const herd = [pudu];
  if (perform === roam) {
    const probe = create(stage, host, SELECTOR.littleClass, visible);
    const count = fawnsFor(stage.clientWidth, pudu.actor.offsetWidth, probe.actor.offsetWidth);
    const little = count > 0 ? [probe] : [];
    if (count === 0) {
      probe.actor.remove();
      probe.front.parentElement.remove();
    }
    while (little.length < count) little.push(create(stage, host, SELECTOR.littleClass, visible));
    herd.push(...little);
  }
  for (const member of herd) member.herd = herd;
  if (window.matchMedia(REDUCED_MOTION).matches) {
    rest(pudu, spotAt(pudu, RESTING_SHARE));
    restAlong(herd.slice(1));
    continue;
  }
  if (herd.length > 1) layOut(herd);
  window.addEventListener("resize", () => herd.forEach(keepInside), { passive: true });
  const target = stage.dataset.puduTarget ? document.querySelector(stage.dataset.puduTarget) : null;
  perform(pudu, target);
  herd.slice(1).forEach(fawn);
}
