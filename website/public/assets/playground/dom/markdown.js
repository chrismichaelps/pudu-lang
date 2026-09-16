// The part of Markdown the language server writes — fenced code, paragraphs,
// and `inline code` — as page nodes. Only painted code is set as HTML, and the
// painter escapes everything it writes.

import { colour } from "../text/syntax.js";
import { element } from "./nodes.js";

const FENCE = /```[a-z]*\n?/;
const INLINE_CODE = /(`[^`]+`)/;
const PARAGRAPH_BREAK = /\n{2,}/;

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
    .filter((block) => block.trim())
    .map((block) => {
      const node = element("p");
      for (const segment of block.split(INLINE_CODE)) {
        if (segment.length > 1 && segment.startsWith("`") && segment.endsWith("`")) {
          node.appendChild(element("code", "", segment.slice(1, -1)));
        } else if (segment) {
          node.appendChild(document.createTextNode(segment));
        }
      }
      return node;
    });
}

// The documentation a protocol value carries, which is text or `{ value }`.
export function documentationText(value) {
  if (typeof value === "string") return value;
  return typeof value?.value === "string" ? value.value : "";
}
