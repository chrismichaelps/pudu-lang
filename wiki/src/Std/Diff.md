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
Inspired by Haskell `diff` and Java `diff-utils`.

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

## Grill Log

- **Q:** Why include both Myers diff and Levenshtein distance?
  **A:** Myers diff is optimized for line-oriented structured text and source code with hunk rendering; Levenshtein distance provides character-level edit counts and similarity scoring for fuzzy matching and typo detection.
- **Q:** How does `unifiedDiff` handle completely identical inputs?
  **A:** Returns an empty string `""`, allowing callers to test `diff.length() == 0` directly for equality.

## Referenced by

[[src/Std/_MOC]] · [[Std Test]] · [[architecture/STDLIB]]
