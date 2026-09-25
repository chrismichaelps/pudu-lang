import { bindCopyButtons } from "../clipboard/copy.js";

const PANE = "[data-code-main]";
const LINKS = ".code-tree-link, .code-crumbs a";
const CACHE_SIZE = 12;

const cache = new Map();

function sourceRoot(pathname) {
  const at = pathname.indexOf("/source");
  return at < 0 ? null : pathname.slice(0, at + "/source".length);
}

/** The page for an address, parsed; requests are shared and the most recent are kept. */
function pageFor(url) {
  if (!cache.has(url)) {
    const request = fetch(url, { headers: { Accept: "text/html" } })
      .then((answer) => (answer.ok ? answer.text() : Promise.reject(new Error(`${answer.status}`))))
      .then((text) => new DOMParser().parseFromString(text, "text/html"));
    request.catch(() => cache.delete(url));
    cache.set(url, request);
    if (cache.size > CACHE_SIZE) cache.delete(cache.keys().next().value);
  }
  return cache.get(url);
}

function markCurrent(tree, pathname) {
  for (const link of tree.querySelectorAll(".code-tree-link")) {
    if (new URL(link.href).pathname === pathname) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
}

async function show(view, url, push) {
  const pane = view.querySelector(PANE);
  pane.setAttribute("aria-busy", "true");
  try {
    const page = await pageFor(url);
    const next = page.querySelector(PANE);
    if (!next) throw new Error("no file pane");
    pane.replaceChildren(...next.childNodes);
    bindCopyButtons(pane);
    markCurrent(view, new URL(url).pathname);
    document.title = page.title;
    if (push) history.pushState({ source: url }, "", url);
    const top = view.getBoundingClientRect().top;
    if (top < 0) view.scrollIntoView({ block: "start" });
  } catch {
    location.assign(url);
  } finally {
    pane.removeAttribute("aria-busy");
  }
}

/** Opens files of the source tab in place instead of reloading the page. */
export function bindSourceNavigation(root) {
  const view = root.querySelector(".code-view");
  if (!view || !view.querySelector(PANE)) return;
  const home = sourceRoot(location.pathname);

  function inside(link) {
    const url = new URL(link.href, location.href);
    return url.origin === location.origin && sourceRoot(url.pathname) === home ? url : null;
  }

  view.addEventListener("click", (event) => {
    const link = event.target.closest(LINKS);
    if (!link || event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const url = inside(link);
    if (!url || url.hash) return;
    event.preventDefault();
    if (url.href !== location.href) show(view, url.href, true);
  });
  const warm = (event) => {
    const link = event.target.closest?.(LINKS);
    const url = link && inside(link);
    if (url && !url.hash && url.href !== location.href) pageFor(url.href);
  };
  view.addEventListener("pointerover", warm);
  view.addEventListener("focusin", warm);
  history.replaceState({ source: location.href }, "");
  window.addEventListener("popstate", (event) => {
    if (event.state?.source) show(view, event.state.source, false);
  });
}
