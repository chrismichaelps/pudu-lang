// node --test website/scripts/packages/discover.test.mjs
import assert from "node:assert/strict";
import test from "node:test";
import { discover, SEARCH_CAP } from "./discover.mjs";

const DAY_MILLIS = 86400000;

function repositories(count) {
  const start = Date.parse("2020-01-01T00:00:00Z");
  return Array.from({ length: count }, (_, index) => ({
    full_name: `owner${index}/pkg${index}`,
    created_at: new Date(start + (index % 1500) * DAY_MILLIS).toISOString(),
    stargazers_count: index,
    private: false,
    archived: index === 7,
  }));
}

/** A search that behaves like GitHub's: `created:A..B`, pages of 100, never past the cap. */
function fakeSearch(all) {
  const asked = [];
  async function json(path) {
    const url = new URL(path, "http://github.test");
    const query = url.searchParams.get("q");
    const [from, to] = /created:(\S+)\.\.(\S+)/.exec(query).slice(1);
    const matched = all.filter((repository) => {
      const day = repository.created_at.slice(0, 10);
      return day >= from && day <= to;
    });
    const page = Number(url.searchParams.get("page"));
    const size = Number(url.searchParams.get("per_page"));
    asked.push(query);
    const visible = matched.slice(0, SEARCH_CAP);
    return { total_count: matched.length, items: visible.slice((page - 1) * size, page * size) };
  }
  return { json, asked };
}

test("lists every repository past the search cap", async () => {
  const all = repositories(2500);
  const search = fakeSearch(all);
  const found = await discover(search.json, "pudu-package", { from: "2020-01-01", to: "2024-12-31" });
  assert.equal(found.length, 2499);
  assert.ok(!found.some((repository) => repository.archived));
  assert.equal(found[0].stargazers_count, 2499);
  assert.ok(search.asked.length > 3);
});

test("a small topic takes one slice", async () => {
  const search = fakeSearch(repositories(40));
  const found = await discover(search.json, "pudu-package", { from: "2020-01-01", to: "2024-12-31" });
  assert.equal(found.length, 39);
  assert.equal(new Set(search.asked).size, 1);
});

test("a single day past the cap is reported, not silently cut", async () => {
  const crowded = Array.from({ length: 1200 }, (_, index) => ({ full_name: `o/p${index}`, created_at: "2021-05-05T10:00:00Z", stargazers_count: 0 }));
  const warnings = [];
  const found = await discover(fakeSearch(crowded).json, "pudu-package", { from: "2021-05-05", to: "2021-05-05", warn: (text) => warnings.push(text) });
  assert.equal(found.length, SEARCH_CAP);
  assert.equal(warnings.length, 1);
});
