// The playground's painter against the fixture the website's Pudu painter is
// also checked with, so the documentation and the playground colour code alike.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const here = new URL(".", import.meta.url);
const source = readFileSync(new URL("../public/assets/playground/text/syntax.js", here), "utf8");
const { colour } = await import(`data:text/javascript,${encodeURIComponent(source)}`);
const cases = JSON.parse(readFileSync(new URL("../test/fixtures/syntax.json", here), "utf8"));

test("the fixture covers every case the Pudu painter is held to", () => {
  assert.ok(cases.length >= 12);
});

for (const [index, { input, html }] of cases.entries()) {
  test(`the playground paints fixture case ${index} as recorded`, () => {
    assert.equal(colour(input), html);
  });
}
