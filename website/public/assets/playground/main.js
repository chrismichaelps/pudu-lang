// The playground's editor, assembled.
//
// The page renders the playground as a `pudu-island` whose server-rendered
// content is the whole working form: without this script, its forms run,
// format, share, and open examples, and the server answers each with the page.
// Mounting the island adds what only a script can do — an editor that
// highlights the program, answers as it is written, and runs it in place — on
// top of those same elements, which are never rendered a second time.
//
// The editor is the page's own text area laid over a painted copy of what it
// holds, so selection, undo, input methods, and accessibility tools behave as
// they do in any field. Everything the mount adds outside the island is tied to
// the island's signal and goes when it is removed.

import { DEFAULT_RUN_MILLIS, DEFAULT_SHARE_LIMIT, ISLAND_NAME } from "./config/constants.js";
import { isApplePlatform } from "./dom/nodes.js";
import { createEditing } from "./editor/editing.js";
import { createGeometry } from "./editor/geometry.js";
import { bindKeys } from "./editor/keys.js";
import { createView } from "./editor/view.js";
import { bindExamples } from "./features/examples.js";
import { createOutput } from "./features/output.js";
import { createRunner } from "./features/run.js";
import { bindShare } from "./features/share.js";
import { bindSplitter } from "./features/splitter.js";
import { createStatus } from "./features/status.js";
import { startAssist } from "./lsp/assist.js";
import { offsetAt, positionAt } from "./text/positions.js";

if (window.PuduIslands) {
  window.PuduIslands.register(ISLAND_NAME, mount);
}

function mount(island, props, signal) {
  const parts = {
    form: island.querySelector("#playground-form"),
    source: island.querySelector("#playground-source"),
    highlight: island.querySelector("#playground-highlight"),
    gutter: island.querySelector("#playground-gutter"),
    output: island.querySelector("#playground-output"),
  };
  if (!Object.values(parts).every(Boolean)) return undefined;
  start(parts, props, signal);
  return () => document.documentElement.classList.remove("has-playground-script");
}

function start({ form, source, highlight, gutter, output }, props, signal) {
  const apple = isApplePlatform();
  document.documentElement.classList.add("has-playground-script");

  const status = createStatus(document.getElementById("playground-assist-status"));
  const geometry = createGeometry(source);
  const view = createView({ source, highlight, gutter, code: source.closest(".playground-code"), geometry, status });
  const editing = createEditing({ source, geometry, onMoved: view.schedulePaint });

  const editor = {
    source,
    text: () => source.value,
    caret: () => source.selectionStart,
    hasSelection: () => source.selectionStart !== source.selectionEnd,
    positionOf: (offset, text = source.value) => positionAt(text, offset),
    screenPoint: geometry.screenPoint,
    offsetUnder: geometry.offsetUnder,
    lineHeight: () => geometry.cell.height,
    replaceRange: editing.replaceRange,
    moveCaret: editing.moveCaret,
    showProblems: view.showProblems,
    setAssistNote: status.setNote,
    signal,
  };
  const assist = startAssist(editor, { endpoint: props.assist, enabled: props.enabled === true });

  const outputPane = createOutput(output, {
    onJump: (position) => editing.moveCaret(offsetAt(source.value, position)),
  });
  const runner = createRunner({
    form,
    endpoint: props.run,
    runMillis: Number(props.runMillis) || DEFAULT_RUN_MILLIS,
    editor,
    editing,
    output: outputPane,
  });
  const share = bindShare({
    endpoint: props.share,
    limit: Number(props.shareLimit) || DEFAULT_SHARE_LIMIT,
    editor,
    copyKeys: apple ? "⌘ + C" : "Ctrl + C",
  });
  let previous = source.value;
  const examples = bindExamples({
    form,
    picker: document.getElementById("playground-example"),
    resetLink: document.getElementById("playground-reset"),
    editor,
    signal,
    onReplaced(program) {
      editing.replaceAll(program);
      previous = source.value;
      assist.replaced();
      outputPane.reset();
    },
  });

  source.addEventListener("input", (event) => {
    const inserted = typedCharacter(event, editing.intent());
    view.paint();
    if (source.value === previous) return;
    const before = previous;
    previous = source.value;
    assist.changed(before, previous, inserted);
    examples.changed();
  });
  source.addEventListener("scroll", view.follow, { passive: true });
  source.addEventListener("focus", view.schedulePaint);
  source.addEventListener("blur", view.schedulePaint);
  document.addEventListener("selectionchange", () => {
    if (document.activeElement === source) view.schedulePaint();
  }, { signal });

  bindKeys({ source, assist, editing, act: runner.act });

  form.addEventListener("submit", (event) => {
    const submitter = event.submitter;
    if (submitter?.id === "playground-share") {
      event.preventDefault();
      share.open();
    } else if (submitter?.name === "action") {
      event.preventDefault();
      runner.act(submitter.value);
    }
  });

  document.getElementById("playground-assist-status")?.addEventListener("click", assist.nextProblem);
  showShortcut(document.getElementById("playground-run"), apple ? "⌘↵" : "Ctrl ↵");

  function remeasure() {
    geometry.measure();
    assist.hideAll();
    view.redraw();
  }

  bindSplitter({
    panes: form.querySelector(".playground-panes"),
    before: form.querySelector(".playground-editor"),
    onResize: () => {
      assist.hideAll();
      view.schedulePaint();
    },
  });
  window.addEventListener("resize", remeasure, { signal });
  document.fonts?.ready.then(() => {
    if (!signal.aborted) remeasure();
  });
  remeasure();
}

// The character whose typing this change was, if any. The editor's own changes
// say so themselves. Otherwise the last character inserted decides: typing
// sends one, but an input method or a keyboard macro commits several.
function typedCharacter(event, intent) {
  if (intent !== undefined) return intent;
  if (event.inputType !== "insertText" || typeof event.data !== "string") return null;
  return event.data.slice(-1) || null;
}

function showShortcut(button, keys) {
  if (!button) return;
  const drawn = button.querySelector(".tool-key");
  if (drawn) {
    drawn.textContent = keys;
    return;
  }
  const hint = document.createElement("span");
  hint.className = "tool-key";
  hint.setAttribute("aria-hidden", "true");
  hint.textContent = keys;
  button.append(hint);
}
