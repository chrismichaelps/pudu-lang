---
type: module
path: "@root/lib/Std/Diff.pudu"
fidelity: Active
tags: [module, stdlib, diff, text, algorithms]
aliases: [Std Diff]
---
# Std Diff

## Purpose

Compute line-by-line and sequence differences using Myers $O(ND)$ difference algorithm,
generate standard Unified Diff formats with configurable context, and calculate Levenshtein edit distance metrics.
Essential for assertion diffs, CLI tools, revision tracking, and text analytics.

## Interface

### Types
- `DiffOp[T] = Keep(T) | Insert(T) | Delete(T)`: Elementary edit script operation.
- `DiffHunk = { oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, lines: Array[Str] }`: Grouped unified diff hunk.

### Differencing
- `diffLines(oldText: Str, newText: Str) -> Array[DiffOp[Str]]`: Computes the minimal edit script transforming lines of `oldText` to `newText`.
- `diffTokens(oldTokens: Array[Str], newTokens: Array[Str]) -> Array[DiffOp[Str]]`: Computes minimal edit script across token sequences.
- `unifiedDiff(oldPath: Str, newPath: Str, oldText: Str, newText: Str, contextLines: Int) -> Str`: Formats differences in standard Unified Diff format with `---`, `+++`, and `@@ -l,s +l,s @@` headers.

### Metrics
- `levenshtein(s1: Str, s2: Str) -> Int`: Computes the minimum number of single-character edits (insertions, deletions, substitutions) required to change `s1` into `s2`.
- `similarity(s1: Str, s2: Str) -> Float`: Normalized similarity score from `0.0` (completely different) to `1.0` (identical), calculated as $1.0 - \frac{\operatorname{levenshtein}(s_1, s_2)}{\max(|s_1|, |s_2|)}$.

## Algorithm and boundaries

Uses Eugene Myers' $O((N + M) D)$ greedy longest common subsequence (LCS) algorithm,
where $N$ and $M$ are input sequence lengths and $D$ is the size of the minimal edit script.
For near-identical texts (the common case in version control and testing), $D \ll N$, executing in near-linear time.
Unified diff formatting aggregates modified spans with surrounding unchanged context lines into standard hunks.
A hunk side that holds no lines — an insertion's old side or a deletion's new side, which occurs with
zero context — names the line the change follows, one before where it would begin, so
`@@ -2,0 +3,2 @@` inserts after old line 2 exactly as `patch` applies it. The rendered text is gathered
as pieces and joined once.
Lines are split once on the break character, so the scan does not re-walk the text per character.
For `unifiedDiff`, a last line with no break after it is compared as a distinct line: adding or
removing only the final newline is a change, and the unterminated side's line is followed by
`\ No newline at end of file`, as `patch` reads it. `diffLines` still returns the plain lines.

## Grill Log

- **Q:** Why include both Myers diff and Levenshtein distance?
  **A:** Myers diff is optimized for line-oriented structured text and source code with hunk rendering; Levenshtein distance provides character-level edit counts and similarity scoring for fuzzy matching and typo detection.
- **Q:** How does `unifiedDiff` handle completely identical inputs?
  **A:** Returns an empty string `""`, allowing callers to test `diff.length() == 0` directly for equality.
- **Q:** Start an empty hunk side at the position where the change begins?
  **A:** No. _Rationale:_ the unified format numbers an empty side by the line it follows, and a
  start one too high makes `patch` apply the change a line late. _Rejected:_ the tracker position as
  written for non-empty sides.
- **Q:** Treat `"a"` and `"a\n"` as the same lines in a unified diff? **A:** No. _Rationale:_ the
  texts differ, and an empty diff tells a caller they are equal while `patch` would leave the file
  unchanged. _Rejected:_ returning `""` for a final-newline-only change; a marker without a distinct
  compared line, which cannot place the change in a hunk.

## Referenced by

[[src/Std/_MOC]] · [[Std Test]] · [[architecture/STDLIB]]
