// How the playground paints Pudu text. Painting decides colours, never
// meaning: what a program means comes from the language server.

const KEYWORDS = new Set(
  ("module import export as let var const mut fn async return if else match case for in while loop " +
    "break continue type enum struct trait impl where await task spawn comptime macro unsafe with scope dynamic foreign")
    .split(" "),
);
const LITERALS = new Set(["true", "false", "null"]);

const NUMBER = /^(?:0x[0-9a-fA-F_]+|0b[01_]+|0o[0-7_]+|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?)(?:[iu](?:8|16|32|64|128)|f32|f64|d)?/;
const WORD = /^[A-Za-z_][A-Za-z0-9_]*/;
const CHARACTER = /^'(?:\\.|[^'\\\n])'/;
const LABEL = /^@[a-z_][A-Za-z0-9_]*/;
const OPERATOR = /^(?:=>|->|==|!=|<=|>=|&&|\|\||\.\.=?|[-+*/%=<>!&|^?:.])/;
const CONSTANT = /^[A-Z][A-Z0-9_]+$/;
const BLANK = /[ \t\n]/;
// A token never spans more than a line, so only this much is examined.
const WINDOW = 256;
const HTML_ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" };

export function escapeHtml(text) {
  return text.replace(/[&<>"]/g, (character) => HTML_ESCAPES[character]);
}

// The text as escaped HTML with a class per token, in one pass.
export function colour(text) {
  const parts = [];
  const put = (kind, piece) => {
    if (piece) parts.push(kind ? `<span class="tok-${kind}">${escapeHtml(piece)}</span>` : escapeHtml(piece));
  };
  let index = 0;
  while (index < text.length) {
    index = paintFrom(text, index, put);
  }
  return parts.join("");
}

function paintFrom(text, index, put) {
  const character = text[index];
  if (character === "/" && text[index + 1] === "/") return paintLineComment(text, index, put);
  if (character === "/" && text[index + 1] === "*") {
    const stop = blockCommentEnd(text, index);
    put("comment", text.slice(index, stop));
    return stop;
  }
  if (character === '"') return paintString(text, index, put);
  if (BLANK.test(character)) {
    let stop = index + 1;
    while (stop < text.length && BLANK.test(text[stop])) stop += 1;
    put("", text.slice(index, stop));
    return stop;
  }
  const rest = text.slice(index, index + WINDOW);
  const [kind, token] = tokenAt(rest, character, text[index + (WORD.exec(rest)?.[0].length ?? 0)]);
  put(kind, token);
  return index + token.length;
}

function tokenAt(rest, character, afterWord) {
  let match;
  if (character === "'" && (match = CHARACTER.exec(rest))) return ["string", match[0]];
  if (/[0-9]/.test(character) && (match = NUMBER.exec(rest))) return ["number", match[0]];
  if ((match = WORD.exec(rest))) return [wordKind(match[0], afterWord), match[0]];
  if (character === "@" && (match = LABEL.exec(rest))) return ["label", match[0]];
  if ((match = OPERATOR.exec(rest))) return ["operator", match[0]];
  return ["", character];
}

function wordKind(word, next) {
  if (KEYWORDS.has(word)) return "keyword";
  if (LITERALS.has(word)) return "literal";
  if (/^[A-Z]/.test(word)) return word.length > 1 && CONSTANT.test(word) ? "constant" : "type";
  return next === "(" ? "function" : "";
}

function paintLineComment(text, index, put) {
  const end = text.indexOf("\n", index);
  const stop = end < 0 ? text.length : end;
  const isDoc = text.startsWith("///", index) && !text.startsWith("////", index);
  put(isDoc ? "doc" : "comment", text.slice(index, stop));
  return stop;
}

// Block comments nest, so the end is found by counting.
function blockCommentEnd(text, from) {
  let depth = 0;
  let index = from;
  while (index < text.length) {
    if (text.startsWith("/*", index)) {
      depth += 1;
      index += 2;
    } else if (text.startsWith("*/", index)) {
      depth -= 1;
      index += 2;
      if (depth === 0) return index;
    } else {
      index += 1;
    }
  }
  return text.length;
}

// A string, with its escapes and `{ expression }` interpolations painted apart.
// A string never spans a line, so an unterminated one stops there.
function paintString(text, from, put) {
  let index = from + 1;
  let start = from;
  while (index < text.length && text[index] !== "\n") {
    const character = text[index];
    if (character === "\\") {
      put("string", text.slice(start, index));
      const unicode = text[index + 1] === "u" && text[index + 2] === "{";
      const end = unicode ? text.indexOf("}", index) + 1 || index + 2 : index + 2;
      put("escape", text.slice(index, end));
      index = end;
      start = index;
    } else if (character === "{") {
      put("string", text.slice(start, index));
      const close = text.indexOf("}", index);
      const end = close < 0 || text.slice(index, close).includes("\n") ? index + 1 : close + 1;
      put("interpolation", text.slice(index, end));
      index = end;
      start = index;
    } else if (character === '"') {
      put("string", text.slice(start, index + 1));
      return index + 1;
    } else {
      index += 1;
    }
  }
  put("string", text.slice(start, index));
  return index;
}
