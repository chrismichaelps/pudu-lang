// Lists every repository carrying a topic, past GitHub's 1,000-result cap on
// one search, by splitting the creation-date range until each slice fits.
export const SEARCH_CAP = 1000;
const PAGE_SIZE = 100;
const FIRST_DAY = "2008-01-01";
const DAY_MILLIS = 86400000;

function dayOf(millis) {
  return new Date(millis).toISOString().slice(0, 10);
}

function millisOf(day) {
  return Date.parse(`${day}T00:00:00Z`);
}

/**
 * Every public, unarchived repository with `topic`, most-starred first.
 * `json` is the GitHub client's reader; `warn` receives slices that still
 * exceed the cap on a single day.
 */
export async function discover(json, topic, { from = FIRST_DAY, to = dayOf(Date.now()), warn = () => {} } = {}) {
  const found = new Map();

  async function page(query, number) {
    return json(`/search/repositories?q=${encodeURIComponent(query)}&sort=stars&order=desc&per_page=${PAGE_SIZE}&page=${number}`);
  }

  async function slice(start, end) {
    const query = `topic:${topic} created:${start}..${end}`;
    const first = await page(query, 1);
    const total = first?.total_count ?? 0;
    if (total > SEARCH_CAP && start !== end) {
      const middle = dayOf(Math.floor((millisOf(start) + millisOf(end)) / 2 / DAY_MILLIS) * DAY_MILLIS);
      await slice(start, middle);
      await slice(dayOf(millisOf(middle) + DAY_MILLIS), end);
      return;
    }
    if (total > SEARCH_CAP) warn(`${total} repositories were created on ${start}; only the first ${SEARCH_CAP} are listed`);
    let items = first?.items ?? [];
    for (let number = 2; ; number += 1) {
      for (const item of items) found.set(item.full_name, item);
      if (items.length < PAGE_SIZE || number > SEARCH_CAP / PAGE_SIZE) break;
      items = (await page(query, number))?.items ?? [];
    }
  }

  await slice(from, to);
  return [...found.values()]
    .filter((repository) => !repository.private && !repository.archived)
    .sort((left, right) => (right.stargazers_count ?? 0) - (left.stargazers_count ?? 0) || left.full_name.localeCompare(right.full_name));
}
