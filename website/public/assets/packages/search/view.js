import { LIST_CLASS, MESSAGES } from "./constants.js";
import { matchRange, plural } from "./text.js";

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/** A text with its first match of the query wrapped in `mark`. */
function highlighted(className, text, query) {
  const node = element("span", className);
  const range = matchRange(text, query);
  if (!range) {
    node.textContent = text;
    return node;
  }
  node.append(text.slice(0, range[0]), element("mark", "", text.slice(range[0], range[1])), text.slice(range[1]));
  return node;
}

function avatar(source, tone, size) {
  const mark = element("span", "package-avatar package-avatar-fallback");
  mark.dataset.tone = String(tone);
  mark.setAttribute("aria-hidden", "true");
  mark.style.width = mark.style.height = `${size}px`;
  if (source) {
    const image = element("img", "package-avatar-image");
    image.src = source;
    image.alt = "";
    image.width = image.height = size;
    image.addEventListener("error", () => image.remove(), { once: true });
    mark.append(image);
  }
  return mark;
}

let rowCount = 0;

function row(kind, href, parts, hint) {
  const link = element("a", `package-suggest-row package-suggest-${kind}`);
  link.href = href;
  link.id = `package-suggest-row-${++rowCount}`;
  link.setAttribute("role", "option");
  link.setAttribute("aria-selected", "false");
  link.tabIndex = -1;
  link.dataset.kind = kind;
  link.append(...parts);
  if (hint) link.append(element("span", "package-suggest-hint", hint));
  return link;
}

function handleRow(held, query) {
  const identity = element("span", "package-suggest-identity");
  identity.append(highlighted("package-suggest-name", held.handle, query));
  if (held.name) identity.append(element("span", "package-suggest-detail", held.name));
  return row("handle", held.href, [avatar(held.avatar, held.tone, 24), identity, element("span", "package-suggest-meta", plural(held.projects, "project", "projects"))], MESSAGES.openHint);
}

function projectRow(held, query) {
  const name = element("span", "package-suggest-name");
  name.append(element("span", "package-owner", held.handle), element("span", "package-slash", " / "), highlighted("package-suggest-project", held.project, query));
  const identity = element("span", "package-suggest-identity");
  identity.append(name, element("span", "package-suggest-detail", held.description));
  const link = row("project", held.href, [avatar(held.avatar, held.tone, 24), identity, element("span", "package-suggest-meta", held.latest)], MESSAGES.projectHint);
  link.dataset.filter = held.name;
  return link;
}

function declarationRow(held, query) {
  const mark = element("span", "package-symbol-mark", held.mark);
  mark.title = held.kind;
  mark.setAttribute("aria-hidden", "true");
  const name = element("span", "package-suggest-name");
  name.append(element("span", "package-symbol-module", `${held.module}.`), highlighted("", held.name, query));
  const identity = element("span", "package-suggest-identity");
  identity.append(name, element("span", "package-suggest-detail", `${held.project} ${held.version}`));
  return row("declaration", held.href, [mark, identity, element("code", "package-suggest-signature", held.signature)]);
}

let groupCount = 0;

function group(title) {
  const node = element("div", "package-suggest-group");
  const label = element("div", "package-suggest-heading", title);
  label.id = `package-suggest-group-${++groupCount}`;
  node.setAttribute("role", "group");
  node.setAttribute("aria-labelledby", label.id);
  node.append(label);
  return node;
}

/**
 * The listbox for one answer, and its selectable rows in order. The footer
 * link to the full results page appears when that page holds more.
 */
export function suggestionList(answer, query, listId) {
  const list = element("div", LIST_CLASS);
  list.id = listId;
  list.setAttribute("role", "listbox");
  list.setAttribute("aria-label", "Package suggestions");
  const rows = [];
  const addSection = (title, entries, build) => {
    if (!entries.length) return;
    const section = group(title);
    for (const entry of entries) {
      const link = build(entry, query);
      rows.push(link);
      section.append(link);
    }
    list.append(section);
  };
  addSection("Owners", answer.handles, handleRow);
  addSection("Projects", answer.projects, projectRow);
  addSection(answer.filter ? `Declarations in ${answer.filter}` : "Declarations", answer.declarations, declarationRow);
  const shown = answer.projects.length + answer.declarations.length;
  const total = answer.totals.projects + answer.totals.declarations;
  if (query.trim() && total > shown) {
    const more = row("more", answer.more, [element("span", "package-suggest-more", `All ${plural(total, "result", "results")} for “${query.trim()}”`)], MESSAGES.openHint);
    rows.push(more);
    list.append(more);
  }
  return { list, rows };
}

export function summary(answer) {
  const count = answer.handles.length + answer.projects.length + answer.declarations.length;
  return count ? `${plural(count, "suggestion", "suggestions")}. Use the arrow keys to choose.` : MESSAGES.empty;
}
