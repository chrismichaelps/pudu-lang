// Panels that float over the page: the completion list and the tooltips.

import { element } from "./nodes.js";

const MARGIN = 8;

// A panel added to the page, removed again when `signal` ends the editor.
export function createFloating(className, signal, role = "tooltip") {
  const node = element("div", className);
  node.setAttribute("role", role);
  node.hidden = true;
  document.body.appendChild(node);
  signal.addEventListener("abort", () => node.remove(), { once: true });
  return node;
}

// Show a panel at `x` and `below` in the window, kept inside it; when it does
// not fit below, it ends at `above` instead.
export function placeFloating(node, x, below, above) {
  node.hidden = false;
  node.style.left = "0px";
  node.style.top = "0px";
  const box = node.getBoundingClientRect();
  const left = Math.max(MARGIN, Math.min(x, window.innerWidth - box.width - MARGIN));
  let top = below;
  if (top + box.height > window.innerHeight - MARGIN && above - box.height >= MARGIN) top = above - box.height;
  top = Math.max(MARGIN, Math.min(top, window.innerHeight - box.height - MARGIN));
  node.style.left = `${left + window.scrollX}px`;
  node.style.top = `${top + window.scrollY}px`;
}

export function hideFloating(node) {
  node.hidden = true;
}
