// What the playground says to a reader, in one place.

export const MESSAGES = Object.freeze({
  running: "Running…",
  formatted: "Formatted.",
  alreadyFormatted: "Already formatted.",
  emptyProgram: "Write a program first, or pick an example.",
  printedNothing: "The program printed nothing.",
  changedWhileFormatting: "The program changed while it was being formatted. Format it again.",
  tooManyRuns: "You have run a lot of programs in a short time. Try again in a moment.",
  badAnswer: "The playground could not finish that request. Try again in a moment.",
  runTimedOut: "The playground took too long to answer. Try again in a moment.",
  offline: "The playground could not be reached. Check your connection and try again.",
  assistPaused: "Editor help is paused for a moment.",
  assistUnavailable: "Editor help is unavailable right now. Running still works.",
  nextProblemHint: "Press F8 to go to the next problem",
  confirmReset: "Reset the editor to the original program? Undo can bring your changes back.",
  confirmExample: "Open the example? The program in the editor will be replaced.",
  shareTooLong: "This program is too long to share as a link. Save it as a file, or share a shorter version.",
  copied: "Copied to the clipboard.",
  copyByHand: (keys) => `Press ${keys} to copy the selected link.`,
  standardOutput: "Standard output",
  standardError: "Standard error",
  resizePanes: "Resize the editor and the output",
  suggestions: "Suggestions",
  problems: (errors, warnings) =>
    [plural(errors, "error"), plural(warnings, "warning")].filter(Boolean).join(", "),
});

function plural(count, noun) {
  if (!count) return "";
  return `${count} ${noun}${count === 1 ? "" : "s"}`;
}
