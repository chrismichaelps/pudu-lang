import { bindAvatars } from "./avatars.js?v=1";

export function bindPagination(root = document) {
  const targets = new Map([...root.querySelectorAll("[data-page-items]")].map((list) => [list.dataset.pageItems, list]));
  const next = root.querySelector("[data-page-next]");
  const status = root.querySelector("[data-page-loading]");
  if (!targets.size || !next || !globalThis.IntersectionObserver) return;

  let loading = false;
  const observer = new IntersectionObserver(async (entries) => {
    if (!entries.some((entry) => entry.isIntersecting) || loading) return;
    const url = new URL(next.href, location.href);
    if (url.origin !== location.origin) return;
    loading = true;
    observer.unobserve(next);
    const linkFocused = next === document.activeElement;
    next.setAttribute("aria-busy", "true");
    if (!linkFocused) next.parentElement.hidden = true;
    if (status) status.hidden = false;
    for (const target of targets.values()) {
      target.dataset.state = "loading";
      target.setAttribute("aria-busy", "true");
    }
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" } });
      if (!response.ok) throw new Error(`Page ${response.status}`);
      const page = new DOMParser().parseFromString(await response.text(), "text/html");
      const lists = [...page.querySelectorAll("[data-page-items]")];
      if (!lists.length) throw new Error("No list in the next page");
      let firstAdded = null;
      for (const rows of lists) {
        const target = targets.get(rows.dataset.pageItems);
        if (target) {
          if (!firstAdded) firstAdded = rows.querySelector("a");
          const added = [...rows.children];
          target.append(...added);
          for (const item of added) bindAvatars(item);
        }
      }
      const following = page.querySelector("[data-page-next]");
      if (following) {
        next.href = new URL(following.getAttribute("href"), url).href;
        observer.observe(next);
      } else {
        if (linkFocused && firstAdded) firstAdded.focus();
        next.closest(".package-pagination").remove();
      }
    } catch {
    } finally {
      next.removeAttribute("aria-busy");
      if (next.isConnected) next.parentElement.hidden = false;
      if (status) status.hidden = true;
      for (const target of targets.values()) {
        target.dataset.state = "loaded";
        target.removeAttribute("aria-busy");
      }
      loading = false;
    }
  }, { rootMargin: "240px" });
  observer.observe(next);
}

bindPagination();
