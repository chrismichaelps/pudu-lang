{-| @Pudu.Eval.Sort.Module — a stable sort by a caller's comparison -}
module Pudu.Eval.Sort
  ( sortWith
  ) where

{-| Sort by a comparison that says whether its first argument goes before its
    second, keeping elements it calls equal in the order they arrived.

    Natural merge sort. The input is first cut into the runs it already holds:
    a stretch where no element goes before the one ahead of it, or a stretch
    where every element goes before the one ahead of it, which is turned
    around; only the second kind may be reversed without disturbing equal
    elements. Runs are then merged in pairs, round after round, until one is
    left. Input that is already ordered, or ordered backwards, costs one pass
    and one comparison per element; unordered input costs a merge sort.

    The comparison runs in the caller's monad because in the evaluator it is a
    program's own function, which may fail or perform effects. -}
sortWith :: Monad m => (a -> a -> m Bool) -> [a] -> m [a]
sortWith before items = runsOf [] items >>= mergeAll
 where
  mergeAll runs = case runs of
    [] -> pure []
    [single] -> pure single
    _ -> mergePairs [] runs >>= mergeAll

  mergePairs done runs = case runs of
    first : second : rest -> do
      merged <- merge [] first second
      mergePairs (merged : done) rest
    _ -> pure (reverse done <> runs)

  -- The merged prefix is gathered reversed, so each step is a constant-size
  -- frame however long the runs are.
  merge gathered left right = case (left, right) of
    ([], _) -> pure (reverse gathered <> right)
    (_, []) -> pure (reverse gathered <> left)
    (l : ls, r : rs) -> do
      rightFirst <- before r l
      if rightFirst then merge (r : gathered) left rs else merge (l : gathered) ls right

  runsOf found remaining = case remaining of
    [] -> pure (reverse found)
    [single] -> pure (reverse ([single] : found))
    first : second : rest -> do
      falling <- before second first
      if falling
        then descending found [first] second rest
        else ascending found [first] second rest

  -- An ascending run is gathered reversed and turned around when it ends.
  ascending found gathered current rest = case rest of
    next : later -> do
      falls <- before next current
      if falls
        then runsOf (reverse (current : gathered) : found) rest
        else ascending found (current : gathered) next later
    [] -> pure (reverse (reverse (current : gathered) : found))

  -- A strictly descending run is gathered front-first, which reverses it.
  descending found gathered current rest = case rest of
    next : later -> do
      falls <- before next current
      if falls
        then descending found (current : gathered) next later
        else runsOf ((current : gathered) : found) rest
    [] -> pure (reverse ((current : gathered) : found))
