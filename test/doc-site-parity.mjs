import process from "node:process";

let html = "";
process.stdin.setEncoding("utf8");
for await (const chunk of process.stdin) html += chunk;

const dataMarker = "<script id='pudu-index' type='application/json'>";
const dataStart = html.indexOf(dataMarker) + dataMarker.length;
const dataEnd = html.indexOf("</script>", dataStart);
const scriptStart = html.indexOf("<script>", dataEnd) + "<script>".length;
const scriptEnd = html.indexOf("</script>", scriptStart);
assert(dataStart >= dataMarker.length && dataEnd > dataStart, "embedded index is missing");
assert(scriptStart >= "<script>".length && scriptEnd > scriptStart, "site program is missing");

const indexText = html.slice(dataStart, dataEnd);
const index = JSON.parse(indexText);
index.entries.push({
  name: "missingSignature",
  kind: "function",
  module: "Parity",
  signature: null,
  shape: null,
  doc: ["An intentionally incomplete declaration."],
  span: [0, 0],
});
index.entries.push({
  name: "makeShape",
  kind: "function",
  module: "Parity",
  signature: "Str -> dynamic Parity.Shape",
  shape: {
    arguments: [{form: "con", name: "Str", arguments: [], rendered: "Str"}],
    result: {form: "con", name: "dynamic Parity.Shape", arguments: [], rendered: "dynamic Parity.Shape"},
    constraints: [],
  },
  doc: [],
  span: [0, 0],
});
index.entries.push({
  name: "sizeOfCircle",
  kind: "function",
  module: "Parity",
  signature: "Parity.Circle -> Int",
  shape: {
    arguments: [{form: "con", name: "Parity.Circle", arguments: [], rendered: "Parity.Circle"}],
    result: {form: "con", name: "Int", arguments: [], rendered: "Int"},
    constraints: [],
  },
  doc: [],
  span: [0, 0],
});
const runtimeIndexText = JSON.stringify(index);
const program = html.slice(scriptStart, scriptEnd);

class Element {
  constructor(textContent = "") {
    this.textContent = textContent;
    this.value = "";
    this.children = [];
    this.listeners = new Map();
  }

  append(...children) { this.children.push(...children); }
  replaceChildren(...children) { this.children = children; }
  addEventListener(name, listener) { this.listeners.set(name, listener); }
  focus() {}
}

const elements = new Map([
  ["pudu-index", new Element(runtimeIndexText)],
  ["query", new Element()],
  ["results", new Element()],
  ["count", new Element()],
  ["results-title", new Element()],
  ["search-form", new Element()],
  ["clear", new Element()],
]);
const document = {
  getElementById: id => elements.get(id),
  querySelectorAll: () => [],
  createElement: () => new Element(),
};
const window = {location: {href: "https://docs.pudu.test/?q=unwrapOr"}};
let replacedUrl = "";
const history = {replaceState: (_state, _title, url) => { replacedUrl = String(url); }};
const load = new Function("document", "window", "history", "URL", `${program}\nreturn {parseQuery, ranked};`);
const site = load(document, window, history, URL);

assert(index.entries.length > 100, "fixture did not produce a representative index");
assert(elements.get("query").value === "unwrapOr", "deep-linked query was not restored");
assert(elements.get("results").children.length > 0, "deep-linked query rendered no results");
assert(new URL(replacedUrl).searchParams.get("q") === "unwrapOr", "query URL was not preserved");
elements.get("query").value = "missingSignature";
elements.get("query").listeners.get("input")();
const missingHeading = elements.get("results").children[0]?.children[0]?.children[0];
assert(missingHeading?.children.length === 1, "missing signature was fabricated or failed to render");

const exact = site.ranked("unwrapOr");
const concrete = site.ranked("Int -> Int");
const resultOnly = site.ranked("-> Result[a, e]");
assert(exact[0]?.entry.name === "unwrapOr" && exact[0].score === 0, "exact-name rank diverged");
assert(concrete.length > 0, "concrete type query rendered no results");
assert(resultOnly.length > 0 && resultOnly.every(match => match.score === 60), "result-only rank diverged");
assert(site.ranked("Int ->").length === 0, "incomplete query produced results");
assert(site.ranked("Int -> -> Str").length === 0, "malformed query produced results");
assert(site.parseQuery("你 -> 你")?.kind === "shape", "Unicode query classification diverged");

// A dynamic type is one atom, and an unqualified name matches a qualified
// signature. Both rules live in two implementations — the CLI's and this
// page's — so both are checked here.
const named = list => list.map(match => match.entry.name);
assert(
  named(site.ranked("Str -> dynamic Shape")).includes("makeShape"),
  "a dynamic result was not found by its unqualified trait",
);
assert(
  named(site.ranked("Str -> dynamic Parity.Shape")).includes("makeShape"),
  "a dynamic result was not found by its qualified trait",
);
assert(
  named(site.ranked("Circle -> Int")).includes("sizeOfCircle"),
  "an unqualified query did not match a qualified signature",
);
assert(
  !named(site.ranked("Other.Circle -> Int")).includes("sizeOfCircle"),
  "a query naming the wrong module still matched",
);

assert(site.ranked("Array[".repeat(65) + "Int" + "]".repeat(65) + " -> Int").length === 0, "hostile query depth was admitted");

process.stdout.write(JSON.stringify({entries: index.entries.length - 1, bytes: Buffer.byteLength(html)}) + "\n");

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
