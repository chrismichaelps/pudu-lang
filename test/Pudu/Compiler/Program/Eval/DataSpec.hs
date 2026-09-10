{-| @Test.Compiler.Program.Eval.DataSpec — collection, memory buffer, flat map, and columnar vector evaluation -}
module Pudu.Compiler.Program.Eval.DataSpec
  ( testDataEvaluation
  ) where

import Pudu.Compiler.Program.Common (runEntry)
import Test.QuickCheck (Property, conjoin, counterexample, (===))

{-| Evaluates data structures, memory layout, flat hash table, and columnar vector programs. -}
testDataEvaluation :: IO Property
testDataEvaluation = do
  collections <- runEntry "test-fixtures/stdlib/UsesList.pudu"
  structures <- runEntry "test-fixtures/stdlib/UsesStructures.pudu"
  orderedMaps <- runEntry "test-fixtures/stdlib/UsesOrderedMaps.pudu"
  relationalMaps <- runEntry "test-fixtures/stdlib/UsesRelationalMaps.pudu"
  cacheAndTrie <- runEntry "test-fixtures/stdlib/UsesCacheAndTrie.pudu"
  graphEdges <- runEntry "test-fixtures/stdlib/UsesGraphEdges.pudu"
  hierarchies <- runEntry "test-fixtures/stdlib/UsesTree.pudu"
  keyed <- runEntry "test-fixtures/stdlib/UsesKeyed.pudu"
  keyedInvariants <- runEntry "test-fixtures/stdlib/KeyedInvariants.pudu"
  bitSetInvariants <- runEntry "test-fixtures/stdlib/UsesBitSet.pudu"
  buffers <- runEntry "test-fixtures/stdlib/UsesBuffer.pudu"
  flatMaps <- runEntry "test-fixtures/stdlib/UsesFlatMap.pudu"
  columnVectors <- runEntry "test-fixtures/stdlib/UsesColumn.pudu"
  hashed <- runEntry "test-fixtures/stdlib/UsesHashMap.pudu"
  dbRows <- runEntry "test-fixtures/stdlib/UsesDbRow.pudu"
  listAll <- runEntry "test-fixtures/stdlib/UsesListAll.pudu"
  mapAll <- runEntry "test-fixtures/stdlib/UsesMapAll.pudu"
  setAll <- runEntry "test-fixtures/stdlib/UsesSetAll.pudu"
  multiMapAll <- runEntry "test-fixtures/stdlib/UsesMultiMapAll.pudu"
  sortedMapAll <- runEntry "test-fixtures/stdlib/UsesSortedMapAll.pudu"
  linkedMapAll <- runEntry "test-fixtures/stdlib/UsesLinkedMapAll.pudu"
  pure $ conjoin
    [ {-| Every export of the list module against a stated answer, naming the
          whole result rather than its length, so a function that answers the
          right shape with the wrong contents fails here. -}
      counterexample
        "every list operation answers what it says it answers"
        (listAll === Just "92")
    {-| Every export of the map and set modules against a stated answer. The
        empty one is asked the same questions as a full one: that is where a
        fold has nothing to fold and an extreme has no answer, and where an
        empty set is a subset of everything and shares a member with nothing. -}
    , counterexample
        "every map operation answers what it says it answers"
        (mapAll === Just "60")
    , counterexample
        "every set operation answers what it says it answers"
        (setAll === Just "53")
    {-| Every export of the multi-map, where counting keys and counting values
        are different questions: a function confusing them would be right only
        when every key held exactly one value. -}
    , counterexample
        "a key holding several values is counted apart from the values"
        (multiMapAll === Just "34")
    {-| Every export of the sorted map. The neighbour lookups are checked at a
        key that is present and one that is not, which is the only case where
        `floor` differs from `lower` and `ceiling` from `higher`. -}
    , counterexample
        "a sorted map answers its neighbours on either side of a key"
        (sortedMapAll === Just "45")
    {-| Every export of the map that remembers the order its keys were first
        put in, checked as a sequence rather than as a set: a function keeping
        the right entries in the wrong order would pass every check that only
        asked what a key holds. The sample is built out of alphabetical order,
        so a map that sorted its keys could not pass by accident. Writing to a
        key already there leaves it where it is, and only `touch` moves it —
        the difference between an order of first appearance and one of
        recency. -}
    , counterexample
        "a map that keeps its insertion order keeps it through every operation"
        (linkedMapAll === Just "41")
    , {-| Reading a result set, checked hardest where a database hurts: a
          column that is not there, a row past the end, a null where a value
          was wanted, and a value of the wrong kind. Answering any of those
          with a default rather than an error is how a report goes quietly
          wrong. -}
      counterexample
        "reading columns, rows, nulls and mistyped values out of a result set"
        (dbRows === Just "25")
    , counterexample
        "a sequence that cannot be empty, a queue with two ends, a heap, and a graph"
        (structures === Just "87")
    {-| The three ordered maps, including the cases easiest to get wrong: a
        boundary landing exactly on an entry, a key that is absent, an empty
        structure, and a re-insertion that must not move anything. Each check
        answers 1, so a shortfall names how many failed. -}
    , counterexample
        "a map with neighbours, a map that remembers its order, and a total map"
        (orderedMaps === Just "38")
    {-| The relational maps, weighted toward the invariants that break quietly:
        a two-way map staying a bijection when a value collides, a multi-map
        never reporting a key whose values ran out, and a partial index staying
        in step with the entries it indexes. Each check answers 1. -}
    , counterexample
        "a map read from both sides, a map of many values, and a map keyed by parts"
        (relationalMaps === Just "42")
    {-| The bounded cache and the prefix trie, weighted toward what is easy to
        get wrong: that a read counts as use and a peek does not, that the
        capacity holds on every write, and that removing a key gives back the
        path it did not share. Each check answers 1. -}
    , counterexample
        "a cache that discards what is unused, and keys reachable by their prefix"
        (cacheAndTrie === Just "42")
    {-| The graph's edge behaviour, checked directly rather than inferred from
        the walks, because a multi-valued map is a reasonable place to
        deduplicate and this one deliberately does not. These held before the
        adjacency became a MultiMap and must hold after. -}
    , counterexample
        "graph edges keep their duplicates, their order, and their lone nodes"
        (graphEdges === Just "15")
    {-| A hierarchy's counting rules, its three orders, its transformations, and
        what search answers when there is nothing to find. Weighted toward what
        a hand-written hierarchy gets wrong: a leaf counted as height zero, a
        traversal that loses child order, a prune that promotes the children of
        a node it removed. Each check answers 1. -}
    , counterexample
        "a tree counts, walks, transforms, and reports where it looked"
        (hierarchies === Just "67")
    {-| The obligations [[ADR-0015]] places on a hash map: a key type whose
        hash tells nothing apart is still kept distinct by its equality, a
        replaced value keeps its position while a re-inserted key takes a new
        one, the two zeros name one key, and four hundred keys with removals
        answer exactly what the ordered map answers. -}
    , counterexample
        "a hash map settles identity by equality and order by insertion"
        (hashed === Just "43")
    , counterexample "the collection module sorts, maps, filters, and joins"
        (collections === Just "41")
    , counterexample "maps, sets, and bit work link together"
        (keyed === Just "30")
    {-| Every promise the keyed runtime makes about order, duplication, and
        absence, so a change to how entries are stored cannot quietly change
        what a map is. Each check answers 1, so a shortfall names how many
        failed. -}
    , counterexample "keyed collections keep their order, uniqueness, and overrides"
        (keyedInvariants === Just "18")
    , counterexample "sparse bitsets keep their cardinality, members, algebra, and bounds"
        (bitSetInvariants === Just "39")
    , counterexample "unboxed contiguous memory buffer operations evaluate"
        (buffers === Just "27")
    , counterexample "flat hash table with control metadata evaluates"
        (flatMaps === Just "31")
    , counterexample "vectorized columnar engine with unboxed storage evaluates"
        (columnVectors === Just "22")
    ]
