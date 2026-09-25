import { POSE, REDUCED_MOTION, SELECTOR } from "./config/constants.js";
import { draw } from "./art/drawing.js";
import { hold } from "./motion/moves.js";
import { keepInside, place, spotAt } from "./stage/place.js";
import { watchVisibility } from "./stage/visible.js";
import { ask } from "./modes/ask.js";
import { roam } from "./modes/roam.js";
import { shy } from "./modes/shy.js";

const MODES = { roam, shy, ask };
const RESTING_SHARE = 0.72;

for (const stage of document.querySelectorAll(SELECTOR.stage)) {
  const perform = MODES[stage.dataset.pudu];
  if (perform === undefined) continue;
  const host = stage.closest(SELECTOR.host) ?? stage.parentElement;
  const actor = document.createElement("div");
  const front = document.createElement("div");
  const frontStage = document.createElement("div");
  actor.className = front.className = "pudu-actor";
  frontStage.className = SELECTOR.frontClass;
  stage.append(actor);
  frontStage.append(front);
  host.append(frontStage);
  const pudu = {
    stage,
    actor,
    front,
    x: 0,
    gripping: false,
    following: [],
    parts: draw(actor, front),
    visible: watchVisibility(host),
  };
  if (window.matchMedia(REDUCED_MOTION).matches) {
    place(pudu, spotAt(pudu, RESTING_SHARE));
    hold(pudu, POSE.up);
    pudu.parts.hooves.style.opacity = "1";
    continue;
  }
  window.addEventListener("resize", () => keepInside(pudu), { passive: true });
  const target = stage.dataset.puduTarget ? document.querySelector(stage.dataset.puduTarget) : null;
  perform(pudu, target);
}
