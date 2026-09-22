// Mark, in the page's contents, the section being read.
//
// The contents are ordinary links and work without this. With it, the link to
// the section under the reading line says so as the reader scrolls, which is
// how a long page keeps its place.

import { CURRENT, END_SLACK_PX, READING_LINE_PX, SECTION_LINKS } from "./constants.js";

const sections = [...document.querySelectorAll(SECTION_LINKS)]
  .map((link) => ({ link, heading: document.getElementById(decodeURIComponent(link.hash.slice(1))) }))
  .filter((section) => section.heading);

let marked = null;
let queued = false;
// Where each heading starts and where the page ends, in page coordinates.
// Measured when the page's size changes rather than while it scrolls, so a
// scroll reads nothing from the layout and never makes the browser lay the
// page out in the middle of a frame.
let tops = [];
let end = 0;

function measure() {
  const scrolled = window.scrollY;
  tops = sections.map((section) => section.heading.getBoundingClientRect().top + scrolled);
  end = document.documentElement.scrollHeight;
  schedule();
}

// The last section whose heading is above the reading line; the last section
// of all once the page cannot scroll further; the first before any is reached.
function reading() {
  const scrolled = window.scrollY;
  if (scrolled + window.innerHeight >= end - END_SLACK_PX) return sections.length - 1;
  const line = scrolled + READING_LINE_PX;
  let found = 0;
  while (found + 1 < tops.length && tops[found + 1] <= line) found += 1;
  return found;
}

function mark() {
  queued = false;
  const current = sections[reading()];
  if (current === marked) return;
  marked?.link.removeAttribute("aria-current");
  current?.link.setAttribute("aria-current", CURRENT);
  marked = current;
}

// Scrolling asks many times a frame; the answer is needed once per frame.
function schedule() {
  if (queued) return;
  queued = true;
  requestAnimationFrame(mark);
}

if (sections.length > 0) {
  window.addEventListener("scroll", schedule, { passive: true });
  window.addEventListener("hashchange", schedule);
  // A resize, an image arriving, or a font swapping in moves the headings.
  new ResizeObserver(measure).observe(document.documentElement);
  measure();
}
