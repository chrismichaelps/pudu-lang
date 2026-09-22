// The handle between the editor and the output, dragged or moved with the
// arrow keys. The split is remembered in this browser.

import { SPLIT } from "../config/constants.js";
import { MESSAGES } from "../config/messages.js";
import { element, readStored, writeStored } from "../dom/nodes.js";

export function bindSplitter({ panes, before, onResize }) {
  const drawn = before.nextElementSibling;
  const handle = drawn?.classList.contains("playground-splitter") ? drawn : element("div", "playground-splitter");
  handle.setAttribute("role", "separator");
  handle.setAttribute("aria-orientation", "vertical");
  handle.setAttribute("aria-label", MESSAGES.resizePanes);
  handle.setAttribute("aria-valuemin", String(SPLIT.min));
  handle.setAttribute("aria-valuemax", String(SPLIT.max));
  handle.tabIndex = 0;
  if (handle !== drawn) before.after(handle);

  function current() {
    return parseFloat(panes.style.getPropertyValue("--split")) || SPLIT.fallback;
  }

  function set(percent, remember) {
    const bounded = Math.max(SPLIT.min, Math.min(SPLIT.max, percent));
    panes.style.setProperty("--split", `${bounded}%`);
    handle.setAttribute("aria-valuenow", String(Math.round(bounded)));
    if (remember) writeStored(SPLIT.storageKey, String(bounded));
    onResize();
  }

  function end(event) {
    if (!handle.hasPointerCapture(event.pointerId)) return;
    handle.releasePointerCapture(event.pointerId);
    handle.classList.remove("is-dragging");
    document.documentElement.classList.remove("is-resizing");
    set(current(), true);
  }

  handle.addEventListener("pointerdown", (event) => {
    event.preventDefault();
    handle.setPointerCapture(event.pointerId);
    handle.classList.add("is-dragging");
    document.documentElement.classList.add("is-resizing");
  });
  handle.addEventListener("pointermove", (event) => {
    if (!handle.hasPointerCapture(event.pointerId)) return;
    const box = panes.getBoundingClientRect();
    set(((event.clientX - box.left) / box.width) * 100, false);
  });
  handle.addEventListener("pointerup", end);
  handle.addEventListener("pointercancel", end);
  handle.addEventListener("keydown", (event) => {
    const step = { ArrowLeft: -SPLIT.step, ArrowRight: SPLIT.step }[event.key];
    if (!step) return;
    event.preventDefault();
    set(current() + step, true);
  });

  const kept = Number(readStored(SPLIT.storageKey));
  set(kept || SPLIT.fallback, false);
}
