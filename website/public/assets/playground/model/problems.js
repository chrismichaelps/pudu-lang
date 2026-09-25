// The problems the language server reported, kept in step with the text.

import { SEVERITY_ERROR } from "../config/constants.js";
import { changedSpan } from "../text/scan.js";
import { offsetAt, positionAt } from "../text/positions.js";

export function validProblems(list) {
  return (Array.isArray(list) ? list : []).filter(isProblem);
}

function isProblem(entry) {
  const range = entry?.range;
  return (
    typeof entry?.message === "string" &&
    [range?.start?.line, range?.start?.character, range?.end?.line, range?.end?.character].every(Number.isInteger)
  );
}

function offsetsOf(problem, text) {
  const start = offsetAt(text, problem.range.start);
  return { start, end: Math.max(start + 1, offsetAt(text, problem.range.end)) };
}

// The problems after an edit. One wholly before the change keeps its place;
// one wholly after it moves with the text; one that touches the change is about
// text that is gone, and is dropped until the server reports again.
export function shiftProblems(problems, before, after) {
  if (problems.length === 0) return problems;
  const { prefix, oldEnd, delta } = changedSpan(before, after);
  return problems.flatMap((problem) => {
    const { start, end } = offsetsOf(problem, before);
    if (end < prefix) return [problem];
    if (start < oldEnd) return [];
    const range = {
      start: positionAt(after, start + delta),
      end: positionAt(after, Math.min(after.length, end + delta)),
    };
    return [{ ...problem, range }];
  });
}

export function problemsAt(problems, text, offset) {
  return problems.filter((problem) => {
    const { start, end } = offsetsOf(problem, text);
    return offset >= start && offset <= end;
  });
}

// Where the next problem after `caret` starts, wrapping round, or -1.
export function nextProblemOffset(problems, text, caret) {
  const starts = problems.map((problem) => offsetAt(text, problem.range.start)).sort((left, right) => left - right);
  if (starts.length === 0) return -1;
  return starts.find((offset) => offset > caret) ?? starts[0];
}

export function countProblems(problems) {
  const errors = problems.filter((problem) => problem.severity === SEVERITY_ERROR).length;
  return { errors, warnings: problems.length - errors };
}

export function isError(problem) {
  return problem.severity === SEVERITY_ERROR;
}
