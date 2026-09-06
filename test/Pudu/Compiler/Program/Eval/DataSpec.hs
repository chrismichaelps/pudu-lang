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
  pure $ conjoin
    [ counterexample
        "a sequence that cannot be empty, a queue with two ends, a heap, and a graph"
        (structures === Just "0")
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
