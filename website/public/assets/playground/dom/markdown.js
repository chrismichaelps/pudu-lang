// The part of Markdown the language server writes — fenced code, paragraphs,
// `inline code`, *emphasis* and **strong** text — as page nodes. Only painted code is set as HTML, and the
// painter escapes everything it writes.

import { colour } from "../text/syntax.js";
import { element } from "./nodes.js";

const FENCE = /```[a-z]*\n?/;
const INLINE_CODE = /(`[^`]+`)/;
const PARAGRAPH_BREAK = /\n{2,}/;
const EMPHASIS = /(\*\*[^*\n]+\*\*|\*[^*\s][^*\n]*\*)/;

export function markdownNodes(text) {
  const nodes = [];
  text.split(FENCE).forEach((piece, index) => {
    const trimmed = piece.replace(/\n+$/, "");
    if (!trimmed.trim()) return;
    if (index % 2 === 1) nodes.push(codeBlock(trimmed));
    else nodes.push(...paragraphs(trimmed));
  });
  return nodes;
}

function codeBlock(text) {
  const pre = element("pre");
  const code = element("code");
  code.innerHTML = colour(text);
  pre.appendChild(code);
  return pre;
}

function paragraphs(text) {
  return text
    .split(PARAGRAPH_BREAK)
    .map((block) => block.trim())
    .filter(Boolean)
    .map((block) => {
      const node = element("p");
      appendEmphasised(node, block);
      return node;
    });
}

// Emphasis is found first, since it may hold inline code: `*function in `Main`*`.
function appendEmphasised(node, text) {
  const parts = text.split(EMPHASIS);
  if (!parts.every(closesItsCode)) {
    appendInline(node, text);
    return;
  }
  for (const part of parts) {
    if (!part) continue;
    if (part.length > 4 && part.startsWith("**") && part.endsWith("**")) {
      appendInline(node.appendChild(element("strong")), part.slice(2, -2));
    } else if (part.length > 2 && part.startsWith("*") && part.endsWith("*")) {
      appendInline(node.appendChild(element("em")), part.slice(1, -1));
    } else {
      appendInline(node, part);
    }
  }
}

// An asterisk inside inline code is not emphasis. Asterisks that pair up
// across code spans, as in `a*b` and `c*d`, leave a piece with an odd number of
// backticks.
function closesItsCode(text) {
  return (text.match(/`/g)?.length ?? 0) % 2 === 0;
}

function appendInline(node, text) {
  for (const segment of text.split(INLINE_CODE)) {
    if (segment.length > 1 && segment.startsWith("`") && segment.endsWith("`")) {
      node.appendChild(element("code", "", segment.slice(1, -1)));
    } else if (segment) {
      node.appendChild(document.createTextNode(segment));
    }
  }
}

// The documentation a protocol value carries, which is text or `{ value }`.
export function documentationText(value) {
  if (typeof value === "string") return value;
  return typeof value?.value === "string" ? value.value : "";
}
