// Keep a page showing the site as it is on disk while `pudu run --watch` runs it.
//
// The site says which start of it is serving. When that moves, the page was
// made by an older start: it reloads, or — when the only change was to
// stylesheets — takes the new styles in place, keeping its scroll position and
// anything typed. While the site is starting again it does not answer, and the
// page keeps asking until it does.

import { POLL_MS, RELOAD_PARAMETER, RETRY_MS, STATE_PATH, STYLE_EXTENSION } from "./constants.js";

const tag = document.querySelector("script[data-start]");
let shown = Number(tag?.dataset.start ?? 0);
let timer = null;

async function ask() {
  timer = null;
  let state;
  try {
    const answer = await fetch(STATE_PATH, { cache: "no-store" });
    state = await answer.json();
  } catch {
    later(RETRY_MS);
    return;
  }
  const start = Number(state.start);
  if (start !== shown) {
    // Only the start just after this page's can be taken in place: across
    // several, a change that needed a reload may be among those not seen.
    if (start === shown + 1 && onlyStyles(state.changed)) {
      swapStyles(start);
      shown = start;
    } else {
      location.reload();
      return;
    }
  }
  later(POLL_MS);
}

function onlyStyles(changed) {
  return Array.isArray(changed) && changed.length > 0 && changed.every((path) => path.endsWith(STYLE_EXTENSION));
}

// Each stylesheet is replaced once its successor has loaded, so the page is
// never shown unstyled in between.
function swapStyles(start) {
  for (const link of document.querySelectorAll('link[rel="stylesheet"]')) {
    const address = new URL(link.href, location.href);
    address.searchParams.set(RELOAD_PARAMETER, String(start));
    const next = link.cloneNode();
    next.href = address.href;
    next.addEventListener("load", () => link.remove(), { once: true });
    link.after(next);
  }
}

function later(delay) {
  if (timer === null && document.visibilityState === "visible") timer = setTimeout(ask, delay);
}

// A tab nobody is looking at asks nothing, and asks at once when shown again.
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") later(0);
  else if (timer !== null) {
    clearTimeout(timer);
    timer = null;
  }
});

later(POLL_MS);
