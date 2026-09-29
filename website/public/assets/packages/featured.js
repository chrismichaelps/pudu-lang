// Refresh the home showcase from live suggest answers.
//
// Each `.home-package[data-package]` card is rendered statically from the
// snapshot. The package listing is the live overlay, so a star or release
// after the build would otherwise leave the two pages disagreeing. For every
// card, one bounded `GET /packages/suggest?q=<name>` is read and only the
// latest/star text is replaced. Failure keeps the snapshot text.

const SELECTOR = ".home-package[data-package]";

function projectOf(payload, name) {
  const projects = Array.isArray(payload?.projects) ? payload.projects : [];
  return projects.find((project) => project?.name === name) ?? null;
}

async function refresh(card) {
  const name = card.getAttribute("data-package");
  if (!name) return;
  const latest = card.querySelector(".home-package-latest");
  const stars = card.querySelector(".home-package-stars");
  if (!latest && !stars) return;
  const response = await fetch(`/packages/suggest?q=${encodeURIComponent(name)}`, {
    headers: { Accept: "application/json" },
  });
  if (!response.ok) return;
  const found = projectOf(await response.json(), name);
  if (!found) return;
  if (latest && typeof found.latest === "string" && found.latest !== "") {
    latest.textContent = found.latest;
  }
  if (stars && Number.isSafeInteger(found.stars)) {
    stars.textContent = String(found.stars);
  }
}

export function bindFeatured(root = document) {
  const cards = [...root.querySelectorAll(SELECTOR)].slice(0, 6);
  for (const card of cards) {
    refresh(card).catch(() => {});
  }
}

bindFeatured();
