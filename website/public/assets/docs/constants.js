// What the page's contents follow while it is read.

// The contents' links to the page's own sections.
export const SECTION_LINKS = ".docs-toc a[href^='#']";

// How far below the top of the window a heading counts as the one being read:
// clear of the space a heading scrolled to by its link stops at.
export const READING_LINE_PX = 96;

// How close to the end of the page counts as the end, where the last section
// is the one being read even when its heading cannot reach the reading line.
export const END_SLACK_PX = 2;

// What a link to the section being read says it is.
export const CURRENT = "location";

// A code block's copy button, shipped hidden until this script can copy.
export const CODE_COPY = ".code-copy";

// The block a copy button belongs to, and the code it copies.
export const CODE_FIGURE = ".code-figure";
export const CODE_TEXT = "pre code";

// What the button says after copying, or when the clipboard refused, and for how long.
export const COPIED_LABEL = "Copied";
export const COPY_FAILED_LABEL = "Select the text to copy";
export const COPIED_MILLIS = 1800;
