// Building page nodes from text. Text is always set as text.

export function element(tag, className = "", text = "") {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text) node.textContent = text;
  return node;
}

export function paragraph(className, text) {
  return element("p", className, text);
}

export function isApplePlatform() {
  return /Mac|iPhone|iPad/.test(navigator.userAgentData?.platform || navigator.platform || navigator.userAgent);
}

export function focusWithoutScrolling(node) {
  if (document.activeElement !== node) node.focus({ preventScroll: true });
}

export function readStored(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

export function writeStored(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // A browser that keeps nothing still works; the value is simply not kept.
  }
}
