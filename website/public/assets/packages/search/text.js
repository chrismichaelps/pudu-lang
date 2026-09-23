/**
 * Where a query first occurs in a text, ignoring case, as [start, end), or
 * null. Shape queries such as `Str -> Int` are matched word by word by the
 * server, so only a query without spaces is highlighted.
 */
export function matchRange(text, query) {
  const wanted = query.trim().replace(/^@/, "").toLowerCase();
  if (!wanted || /\s/.test(wanted)) return null;
  const start = text.toLowerCase().indexOf(wanted);
  return start < 0 ? null : [start, start + wanted.length];
}

export function plural(count, one, many) {
  return `${count} ${count === 1 ? one : many}`;
}
